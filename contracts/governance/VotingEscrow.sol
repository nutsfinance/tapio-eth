// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/governance/utils/IVotes.sol";

import "../interfaces/ISmartWalletChecker.sol";

// Voting escrow to have time-weighted votes
// Votes have a weight depending on time, so that users are committed
// to the future of (whatever they are voting for).
// The weight in this implementation is linear, and lock cannot be more than maxtime:
// w ^
// 1 +        /
//   |      /
//   |    /
//   |  /
//   |/
// 0 +--------+------> time
//       maxtime (4 years?)

contract VotingEscrow is Initializable, ReentrancyGuardUpgradeable, IVotes {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  struct Point {
    uint256 bias;
    uint256 slope; // - dweight / dt
    uint256 ts;
    uint256 blk; // block
  }
  // We cannot really do block numbers per se b/c slope is per time, not per block
  // and per block could be fairly bad b/c Ethereum changes blocktimes.
  // What we can do is to extrapolate ***At functions

  struct LockedBalance {
    uint256 amount;
    uint256 end;
  }

  uint256 public constant DEPOSIT_FOR_TYPE = 0;
  uint256 public constant CREATE_LOCK_TYPE = 1;
  uint256 public constant INCREASE_LOCK_AMOUNT = 2;
  uint256 public constant INCREASE_unlockTime = 3;
  address public constant ZERO_ADDRESS = address(0);

  event CommitOwnership(address admin);
  event ApplyOwnership(address admin);
  event Deposit(
    address indexed provider,
    uint256 value,
    uint256 indexed locktime,
    uint256 type_,
    uint256 ts
  );
  event Withdraw(address indexed provider, uint256 value, uint256 ts);
  event Supply(uint256 prevSupply, uint256 supply);

  uint256 public constant WEEK = 7 * 86400; // all future times are rounded by week
  uint256 public constant MAXTIME = 4 * 365 * 86400; // 4 years
  uint256 public constant MULTIPLIER = 10 ** 18;

  address public token;
  uint256 public supply;

  mapping(address => LockedBalance) public locked;

  uint256 public epoch;
  Point[100000000000000000000000000000] public pointHistory; // epoch -> unsigned point
  mapping(address => Point[1000000000]) public userPointHistory; // user -> Point[user_epoch]
  mapping(address => uint256) public userPointEpoch;
  mapping(uint256 => uint256) public slopeChanges; // time -> signed slope change

  // Aragon's view methods for compatibility
  address public controller;
  bool public transfersEnabled;

  string public name;
  string public symbol;
  string public version;
  uint256 public decimals;

  // Checker for whitelisted (smart contract) wallets which are allowed to deposit
  // The goal is to prevent tokenizing the escrow
  address public futureSmartWalletChecker;
  address public smartWalletChecker;

  address public admin; // Can and will be a smart contract
  address public futureAdmin;

  function initialize(
    address tokenAddr,
    string calldata _name,
    string calldata _symbol,
    string calldata _version
  ) public initializer {
    admin = msg.sender;
    token = tokenAddr;
    pointHistory[0].blk = block.number;
    pointHistory[0].ts = block.timestamp;
    controller = msg.sender;
    transfersEnabled = true;

    uint256 _decimals = ERC20Upgradeable(tokenAddr).decimals();
    require(_decimals <= 255, "decimals too large");
    decimals = _decimals;

    name = _name;
    symbol = _symbol;
    version = _version;
  }

  function commitTransferOwnership(address addr) external {
    require(msg.sender == admin, "not admin");
    futureAdmin = addr;
    emit CommitOwnership(addr);
  }

  function applyTransferOwnership() external {
    require(msg.sender == admin, "not admin");
    address _admin = futureAdmin;
    require(_admin != ZERO_ADDRESS, "admin not set");
    admin = _admin;
    emit ApplyOwnership(_admin);
  }

  function commitSmartWalletChecker(address addr) external {
    require(msg.sender == admin, "not admin");
    futureSmartWalletChecker = addr;
  }

  function applySmartWalletChecker() external {
    require(msg.sender == admin, "not admin");
    smartWalletChecker = futureSmartWalletChecker;
  }

  function assertNotContract(address addr) internal view {
    if (addr != tx.origin) {
      address checker = smartWalletChecker;
      if (checker != ZERO_ADDRESS) {
        if (ISmartWalletChecker(checker).check(addr)) {
          return;
        }
      }
      revert("Smart contract depositors not allowed");
    }
  }

  function getLastUserSlope(address addr) external view returns (uint256) {
    uint256 uepoch = userPointEpoch[addr];
    return userPointHistory[addr][uepoch].slope;
  }

  function userPointHistoryTs(
    address _addr,
    uint256 _idx
  ) external view returns (uint256) {
    return userPointHistory[_addr][_idx].ts;
  }

  function lockedEnd(address _addr) external view returns (uint256) {
    return locked[_addr].end;
  }

  function _checkpoint(
    address addr,
    LockedBalance memory oldLocked,
    LockedBalance memory newLocked
  ) internal {
    Point memory uOld;
    Point memory uNew;
    uint256 oldDslope = 0;
    uint256 newDslope = 0;
    uint256 _epoch = epoch;

    if (addr != ZERO_ADDRESS) {
      // Calculate slopes and biases
      // Kept at zero when they have to
      if (oldLocked.end > block.timestamp && oldLocked.amount > 0) {
        uOld.slope = oldLocked.amount / MAXTIME;
        uOld.bias = uOld.slope * (oldLocked.end - block.timestamp);
      }
      if (newLocked.end > block.timestamp && newLocked.amount > 0) {
        uNew.slope = newLocked.amount / MAXTIME;
        uNew.bias = uNew.slope * (newLocked.end - block.timestamp);
      }

      // Read values of scheduled changes in the slope
      // oldLocked.end can be in the past and in the future
      // newLocked.end can ONLY by in the FUTURE unless everything expired{ than zeros
      oldDslope = slopeChanges[oldLocked.end];
      if (newLocked.end != 0) {
        if (newLocked.end == oldLocked.end) {
          newDslope = oldDslope;
        } else {
          newDslope = slopeChanges[newLocked.end];
        }
      }
    }

    Point memory lastPoint = Point({
      bias: 0,
      slope: 0,
      ts: block.timestamp,
      blk: block.number
    });
    if (_epoch > 0) {
      lastPoint = pointHistory[_epoch];
    }
    uint256 lastCheckpoint = lastPoint.ts;
    // initialLastPoint is used for extrapolation to calculate block number
    // (approximately, for *At methods) and save them
    // as we cannot figure that out exactly from inside the contract
    Point memory initialLastPoint = lastPoint;
    uint256 blockSlope = 0; // dblock/dt
    if (block.timestamp > lastPoint.ts) {
      blockSlope =
        (MULTIPLIER * (block.number - lastPoint.blk)) /
        (block.timestamp - lastPoint.ts);
    }
    // If last point is already recorded in this block, slope=0
    // But that's ok b/c we know the block in such case

    // Go over weeks to fill history and calculate what the current point is
    uint256 tI = (lastCheckpoint / WEEK) * WEEK;
    for (uint i = 0; i < 255; i++) {
      // Hopefully it won't happen that this won't get used in 5 years!
      // If it does, users will be able to withdraw but vote weight will be broken
      tI += WEEK;
      uint256 dSlope = 0;
      if (tI > block.timestamp) {
        tI = block.timestamp;
      } else {
        dSlope = slopeChanges[tI];
      }
      lastPoint.bias -= lastPoint.slope * (tI - lastCheckpoint);
      lastPoint.slope += dSlope;
      if (lastPoint.bias < 0) {
        // This can happen
        lastPoint.bias = 0;
      }
      if (lastPoint.slope < 0) {
        // This cannot happen - just in case
        lastPoint.slope = 0;
      }
      lastCheckpoint = tI;
      lastPoint.ts = tI;
      lastPoint.blk =
        initialLastPoint.blk +
        (blockSlope * (tI - initialLastPoint.ts)) /
        MULTIPLIER;
      _epoch += 1;
      if (tI == block.timestamp) {
        lastPoint.blk = block.number;
        break;
      } else {
        pointHistory[_epoch] = lastPoint;
      }
    }

    epoch = _epoch;
    // Now pointHistory is filled until t=now

    if (addr != ZERO_ADDRESS) {
      // If last point was in this block, the slope change has been applied already
      // But in such case we have 0 slope(s)
      lastPoint.slope += (uNew.slope - uOld.slope);
      lastPoint.bias += (uNew.bias - uOld.bias);
      if (lastPoint.slope < 0) {
        lastPoint.slope = 0;
      }
      if (lastPoint.bias < 0) {
        lastPoint.bias = 0;
      }
    }

    // Record the changed point into history
    pointHistory[_epoch] = lastPoint;

    if (addr != ZERO_ADDRESS) {
      // Schedule the slope changes (slope is going down)
      // We subtract newUserSlope from [newLocked.end]
      // and add oldUserSlope to [oldLocked.end]
      if (oldLocked.end > block.timestamp) {
        // oldDslope was <something> - uOld.slope, so we cancel that
        oldDslope += uOld.slope;
        if (newLocked.end == oldLocked.end) {
          oldDslope -= uNew.slope; // It was a new deposit, not extension
        }
        slopeChanges[oldLocked.end] = oldDslope;
      }

      if (newLocked.end > block.timestamp) {
        if (newLocked.end > oldLocked.end) {
          newDslope -= uNew.slope; // old slope disappeared at this point
          slopeChanges[newLocked.end] = newDslope;
        }
        // else{ we recorded it already in oldDslope
      }

      // Now handle user history
      uint256 userEpoch = userPointEpoch[addr] + 1;

      userPointEpoch[addr] = userEpoch;
      uNew.ts = block.timestamp;
      uNew.blk = block.number;
      userPointHistory[addr][userEpoch] = uNew;
    }
  }

  function _depositFor(
    address _addr,
    uint256 _value,
    uint256 unlockTime,
    LockedBalance memory lockedBalance,
    uint256 _type
  ) internal {
    LockedBalance memory _locked = lockedBalance;
    uint256 supplyBefore = supply;

    supply = supplyBefore + _value;
    LockedBalance memory oldLocked = _locked;
    // Adding to existing lock, or if a lock is expired - creating a new one
    _locked.amount += _value;
    if (unlockTime != 0) {
      _locked.end = unlockTime;
    }
    locked[_addr] = _locked;

    // Possibilities{
    // Both oldLocked.end could be current or expired (>/< block.timestamp)
    // value == 0 (extend lock) or value > 0 (add to lock or extend lock)
    // _locked.end > block.timestamp (always)
    _checkpoint(_addr, oldLocked, _locked);

    if (_value != 0) {
      IERC20Upgradeable(token).safeTransferFrom(_addr, address(this), _value);
    }

    emit Deposit(_addr, _value, _locked.end, _type, block.timestamp);
    emit Supply(supplyBefore, supplyBefore + _value);
  }

  function checkpoint() external {
    LockedBalance memory empty;
    _checkpoint(ZERO_ADDRESS, empty, empty);
  }

  function depositFor(address _addr, uint256 _value) external nonReentrant {
    LockedBalance memory _locked = locked[_addr];

    require(_value > 0, "need non-zero value");
    require(_locked.amount > 0, "No existing lock found");
    require(
      _locked.end > block.timestamp,
      "Cannot add to expired lock. Withdraw"
    );

    _depositFor(_addr, _value, 0, locked[_addr], DEPOSIT_FOR_TYPE);
  }

  function createLock(
    uint256 _value,
    uint256 _unlockTime
  ) external nonReentrant {
    assertNotContract(msg.sender);
    uint256 unlockTime = (_unlockTime / WEEK) * WEEK; // Locktime is rounded down to weeks
    LockedBalance memory _locked = locked[msg.sender];

    require(_value > 0, "need non-zero value");
    require(_locked.amount == 0, "Withdraw old tokens first");
    require(
      unlockTime > block.timestamp,
      "Can only lock until time in the future"
    );
    require(
      unlockTime <= block.timestamp + MAXTIME,
      "Voting lock can be 4 years max"
    );

    _depositFor(msg.sender, _value, unlockTime, _locked, CREATE_LOCK_TYPE);
  }

  function increaseAmount(uint256 _value) external nonReentrant {
    assertNotContract(msg.sender);
    LockedBalance memory _locked = locked[msg.sender];

    require(_value > 0, "need non-zero value");
    require(_locked.amount > 0, "No existing lock found");
    require(
      _locked.end > block.timestamp,
      "Cannot add to expired lock. Withdraw"
    );

    _depositFor(msg.sender, _value, 0, _locked, INCREASE_LOCK_AMOUNT);
  }

  function increaseUnlockTime(uint256 _unlockTime) external nonReentrant {
    assertNotContract(msg.sender);
    LockedBalance memory _locked = locked[msg.sender];
    uint256 unlockTime = (_unlockTime / WEEK) * WEEK; // Locktime is rounded down to weeks

    require(_locked.end > block.timestamp, "Lock expired");
    require(_locked.amount > 0, "Nothing is locked");
    require(unlockTime > _locked.end, "Can only increase lock duration");
    require(
      unlockTime <= block.timestamp + MAXTIME,
      "Voting lock can be 4 years max"
    );

    _depositFor(msg.sender, 0, unlockTime, _locked, INCREASE_unlockTime);
  }

  function withdraw() external nonReentrant {
    LockedBalance memory _locked = locked[msg.sender];
    require(block.timestamp >= _locked.end, "The lock didn't expire");
    uint256 value = _locked.amount;

    LockedBalance memory oldLocked = _locked;
    _locked.end = 0;
    _locked.amount = 0;
    locked[msg.sender] = _locked;
    uint256 supplyBefore = supply;
    supply = supplyBefore - value;

    // oldLocked can have either expired <= timestamp or zero end
    // _locked has only 0 end
    // Both can have >= 0 amount
    _checkpoint(msg.sender, oldLocked, _locked);

    IERC20Upgradeable(token).safeTransfer(msg.sender, value);

    emit Withdraw(msg.sender, value, block.timestamp);
    emit Supply(supplyBefore, supplyBefore - value);
  }

  function findBlockEpoch(
    uint256 _block,
    uint256 maxEpoch
  ) internal view returns (uint256) {
    // Binary search
    uint256 _min = 0;
    uint256 _max = maxEpoch;
    for (uint256 i = 0; i < 128; i++) {
      // Will be always enough for 128-bit numbers
      if (_min >= _max) {
        break;
      }
      uint256 _mid = (_min + _max + 1) / 2;
      if (pointHistory[_mid].blk <= _block) {
        _min = _mid;
      } else {
        _max = _mid - 1;
      }
    }
    return _min;
  }

  function balanceOf(address addr, uint256 _t) external view returns (uint256) {
    uint256 _epoch = userPointEpoch[addr];
    if (_epoch == 0) {
      return 0;
    } else {
      Point memory lastPoint = userPointHistory[addr][_epoch];
      lastPoint.bias -= lastPoint.slope * (_t - lastPoint.ts);
      if (lastPoint.bias < 0) {
        lastPoint.bias = 0;
      }
      return lastPoint.bias;
    }
  }

  function balanceOf(address addr) external view returns (uint256) {
    return this.balanceOf(addr, block.timestamp);
  }

  function balanceOfAt(
    address addr,
    uint256 _block
  ) external view returns (uint256) {
    // Copying and pasting totalSupply code because Vyper cannot pass by
    // reference yet
    require(_block <= block.number, "can't be future block");

    // Binary search
    uint256 _min = 0;
    uint256 _max = userPointEpoch[addr];
    for (uint256 i = 0; i < 128; i++) {
      // Will be always enough for 128-bit numbers
      if (_min >= _max) {
        break;
      }
      uint256 _mid = (_min + _max + 1) / 2;
      if (userPointHistory[addr][_mid].blk <= _block) {
        _min = _mid;
      } else {
        _max = _mid - 1;
      }
    }

    Point memory upoint = userPointHistory[addr][_min];

    uint256 maxEpoch = epoch;
    uint256 _epoch = findBlockEpoch(_block, maxEpoch);
    Point memory pointZero = pointHistory[_epoch];
    uint256 dBlock = 0;
    uint256 dT = 0;
    if (_epoch < maxEpoch) {
      Point memory pointOne = pointHistory[_epoch + 1];
      dBlock = pointOne.blk - pointZero.blk;
      dT = pointOne.ts - pointZero.ts;
    } else {
      dBlock = block.number - pointZero.blk;
      dT = block.timestamp - pointZero.ts;
    }
    uint256 blockTime = pointZero.ts;
    if (dBlock != 0) {
      blockTime += (dT * (_block - pointZero.blk)) / dBlock;
    }

    upoint.bias -= upoint.slope * (blockTime - upoint.ts);
    if (upoint.bias >= 0) {
      return upoint.bias;
    } else {
      return 0;
    }
  }

  function supplyAt(
    Point memory point,
    uint256 t
  ) internal view returns (uint256) {
    Point memory lastPoint = point;
    uint256 tI = (lastPoint.ts / WEEK) * WEEK;
    for (uint256 i = 0; i < 255; i++) {
      tI += WEEK;
      uint256 dSlope = 0;
      if (tI > t) {
        tI = t;
      } else {
        dSlope = slopeChanges[tI];
      }
      lastPoint.bias -= lastPoint.slope * (tI - lastPoint.ts);
      if (tI == t) {
        break;
      }
      lastPoint.slope += dSlope;
      lastPoint.ts = tI;
    }

    if (lastPoint.bias < 0) {
      lastPoint.bias = 0;
    }
    return lastPoint.bias;
  }

  function totalSupply(uint256 t) external view returns (uint256) {
    uint256 _epoch = epoch;
    Point memory lastPoint = pointHistory[_epoch];
    return supplyAt(lastPoint, t);
  }

  function totalSupply() external view returns (uint256) {
    return this.totalSupply(block.timestamp);
  }

  function totalSupplyAt(uint256 _block) external view returns (uint256) {
    require(_block <= block.number, "can't be future block");

    uint256 _epoch = epoch;
    uint256 targetEpoch = findBlockEpoch(_block, _epoch);

    Point memory point = pointHistory[targetEpoch];
    uint256 dt = 0;
    if (targetEpoch < _epoch) {
      Point memory pointNext = pointHistory[targetEpoch + 1];
      if (point.blk != pointNext.blk) {
        dt =
          ((_block - point.blk) * (pointNext.ts - point.ts)) /
          (pointNext.blk - point.blk);
      }
    } else {
      if (point.blk != block.number) {
        dt =
          ((_block - point.blk) * (block.timestamp - point.ts)) /
          (block.number - point.blk);
      }
    }
    // Now dt contains info on how far are we beyond point

    return supplyAt(point, point.ts + dt);
  }

  function changeController(address _newController) external {
    require(msg.sender == controller, "not controller");
    controller = _newController;
  }

  function getVotes(address account) external view override returns (uint256) {
    return this.balanceOf(account);
  }

  function getPastVotes(
    address account,
    uint256 blockNumber
  ) external view override returns (uint256) {
    return this.balanceOfAt(account, blockNumber);
  }

  function getPastTotalSupply(
    uint256 blockNumber
  ) external view override returns (uint256) {
    return this.totalSupplyAt(blockNumber);
  }

  function delegates(
    address account
  ) external view override returns (address) {
    revert("unimplemented");
  }

  function delegate(address delegatee) external override {
    revert("unimplemented");
  }

  function delegateBySig(
    address delegatee,
    uint256 nonce,
    uint256 expiry,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external override {
    revert("unimplemented");
  }
}
