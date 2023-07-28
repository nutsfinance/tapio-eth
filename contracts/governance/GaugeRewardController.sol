// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./VotingEscrow.sol";

interface IGaugeRewardController {
  function nGauges() external view returns (uint128);
  function getGauge(uint128 index) external view returns (address);
  function gaugeRelativeWeightWrite(
    address addr
  ) external returns (uint256);
  function gaugeRelativeWeight(
    address addr
  ) external view returns (uint256);
}

contract GaugeRewardController is Initializable, ReentrancyGuardUpgradeable, IGaugeRewardController {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  uint256 public constant WEEK = 604800;
  // Cannot change weight votes more often than once in 10 days
  uint256 public constant WEIGHT_VOTE_DELAY = 10 * 86400;
  uint256 public constant MULTIPLIER = 10 ** 18;
  address public constant ZERO_ADDRESS = address(0);

  struct Point {
    uint256 bias;
    uint256 slope;
  }

  struct VotedSlope {
    uint256 slope;
    uint256 power;
    uint256 end;
  }

  event CommitOwnership(address admin);

  event ApplyOwnership(address admin);

  event AddType(string name, uint128 typeId);

  event NewTypeWeight(
    uint128 typeId,
    uint256 time,
    uint256 weight,
    uint256 totalWeight
  );

  event NewGaugeWeight(
    address gaugeAddress,
    uint256 time,
    uint256 weight,
    uint256 totalWeight
  );

  event VoteForGauge(
    uint256 time,
    address user,
    address gaugeAddr,
    uint256 weight
  );

  event NewGauge(address addr, uint128 gaugeType, uint256 weight);

  address public admin; // Can and will be a smart contract
  address public futureAdmin; // Can and will be a smart contract

  address public token; // CRV token
  address public votingEscrow; // Voting escrow

  // Gauge parameters
  // All numbers are "fixed point" on the basis of 1e18
  uint128 public nGaugeTypes;
  uint128 public nGauges;
  mapping(uint128 => string) public gaugeTypeNames;

  // Needed for enumeration
  address[1000000000] public gauges;

  // we increment values by 1 prior to storing them here so we can rely on a value
  // of zero as meaning the gauge has not been set
  mapping(address => uint128) public gaugeTypes_;

  mapping(address => mapping(address => VotedSlope)) public voteUserSlopes; // user -> gaugeAddr -> VotedSlope
  mapping(address => uint256) public voteUserPower; // Total vote power used by user
  mapping(address => mapping(address => uint256)) public lastUserVote; // Last user vote's timestamp for each gauge address

  // Past and scheduled points for gauge weight, sum of weights per type, total weight
  // Point is for bias+slope
  // changes_* are for changes in slope
  // time_* are for the last change timestamp
  // timestamps are rounded to whole weeks
  mapping(address => mapping(uint256 => Point)) public pointsWeight; // gaugeAddr -> time -> Point
  mapping(address => mapping(uint256 => uint256)) public changesWeight; // gaugeAddr -> time -> slope
  mapping(address => uint256) public timeWeight; // gaugeAddr -> last scheduled time (next week)

  mapping(uint128 => mapping(uint256 => Point)) public pointsSum; // typeId -> time -> Point
  mapping(uint128 => mapping(uint256 => uint256)) public changesSum; // typeId -> time -> slope
  uint256[1000000000] public timeSum; // typeId -> last scheduled time (next week)

  mapping(uint256 => uint256) public pointsTotal; // time -> total weight
  uint256 public timeTotal; // last scheduled time

  mapping(uint128 => mapping(uint256 => uint256)) public pointsTypeWeight; // typeId -> time -> type weight
  uint256[1000000000] public timeTypeWeight; // typeId -> last scheduled time (next week)

  function initialize(
    address _token,
    address _votingEscrow
  ) public initializer {
    require(_token != ZERO_ADDRESS, "token not set");
    require(_votingEscrow != ZERO_ADDRESS, "escrow not set");

    admin = msg.sender;
    token = _token;
    votingEscrow = _votingEscrow;
    timeTotal = (block.timestamp / WEEK) * WEEK;
  }

  function max(uint256 a, uint256 b) internal pure returns (uint256) {
    return a >= b ? a : b;
  }

  function commitTransferOwnership(address addr) external {
    require(msg.sender == admin, "admin only");
    futureAdmin = addr;
    emit CommitOwnership(addr);
  }

  function applyTransferOwnership() external {
    require(msg.sender == admin, "admin only");
    address _admin = futureAdmin;
    require(_admin != ZERO_ADDRESS, "admin not set");
    admin = _admin;
    emit ApplyOwnership(_admin);
  }

  function gaugeTypes(address _addr) external view returns (uint128) {
    uint128 gaugeType = gaugeTypes_[_addr];
    require(gaugeType != 0, "gauge type not set");

    return gaugeType - 1;
  }

  function _getTypeWeight(uint128 gaugeType) internal returns (uint256) {
    uint256 t = timeTypeWeight[gaugeType];
    if (t > 0) {
      uint256 w = pointsTypeWeight[gaugeType][t];
      for (uint256 i = 0; i < 500; i++) {
        if (t > block.timestamp) {
          break;
        }
        t += WEEK;
        pointsTypeWeight[gaugeType][t] = w;
        if (t > block.timestamp) {
          timeTypeWeight[gaugeType] = t;
        }
      }
      return w;
    } else {
      return 0;
    }
  }

  function _getSum(uint128 gaugeType) internal returns (uint256) {
    uint256 t = timeSum[gaugeType];
    if (t > 0) {
      Point memory pt = pointsSum[gaugeType][t];
      for (uint256 i = 0; i < 500; i++) {
        if (t > block.timestamp) {
          break;
        }
        t += WEEK;
        uint256 dBias = pt.slope * WEEK;
        if (pt.bias > dBias) {
          pt.bias -= dBias;
          uint256 dSlope = changesSum[gaugeType][t];
          pt.slope -= dSlope;
        } else {
          pt.bias = 0;
          pt.slope = 0;
        }
        pointsSum[gaugeType][t] = pt;
        if (t > block.timestamp) {
          timeSum[gaugeType] = t;
        }
      }
      return pt.bias;
    } else {
      return 0;
    }
  }

  function _getTotal() internal returns (uint256) {
    uint256 t = timeTotal;
    uint128 _nGaugeTypes = nGaugeTypes;
    if (t > block.timestamp) {
      // If we have already checkpointed - still need to change the value
      t -= WEEK;
    }
    uint256 pt = pointsTotal[t];

    for (uint128 gaugeType = 0; gaugeType < 100; gaugeType++) {
      if (gaugeType == _nGaugeTypes) {
        break;
      }
      _getSum(gaugeType);
      _getTypeWeight(gaugeType);
    }

    for (uint256 i = 0; i < 500; i++) {
      if (t > block.timestamp) {
        break;
      }
      t += WEEK;
      pt = 0;
      // Scales as n_types * n_unchecked_weeks (hopefully 1 at most)
      for (uint128 gaugeType = 0; gaugeType < 100; gaugeType++) {
        if (gaugeType == _nGaugeTypes) {
          break;
        }
        uint256 typeSum = pointsSum[gaugeType][t].bias;
        uint256 typeWeight = pointsTypeWeight[gaugeType][t];
        pt += typeSum * typeWeight;
      }
      pointsTotal[t] = pt;

      if (t > block.timestamp) {
        timeTotal = t;
      }
    }
    return pt;
  }

  function _getWeight(address gaugeAddr) internal returns (uint256) {
    uint256 t = timeWeight[gaugeAddr];
    if (t > 0) {
      Point memory pt = pointsWeight[gaugeAddr][t];
      for (uint256 i = 0; i < 500; i++) {
        if (t > block.timestamp) {
          break;
        }
        t += WEEK;
        uint256 dBias = pt.slope * WEEK;
        if (pt.bias > dBias) {
          pt.bias -= dBias;
          uint256 dSlope = changesWeight[gaugeAddr][t];
          pt.slope -= dSlope;
        } else {
          pt.bias = 0;
          pt.slope = 0;
        }
        pointsWeight[gaugeAddr][t] = pt;
        if (t > block.timestamp) {
          timeWeight[gaugeAddr] = t;
        }
      }
      return pt.bias;
    } else {
      return 0;
    }
  }

  function addGauge(address addr, uint128 gaugeType, uint256 weight) external {
    require(msg.sender == admin, "not admin");
    require(
      (gaugeType >= 0) && (gaugeType < nGaugeTypes),
      "gauge type incorrect"
    );
    require(gaugeTypes_[addr] == 0, "cannot add the same gauge twice");

    uint128 n = nGauges;
    nGauges = n + 1;
    gauges[n] = addr;

    gaugeTypes_[addr] = gaugeType + 1;
    uint256 nextTime = ((block.timestamp + WEEK) / WEEK) * WEEK;

    if (weight > 0) {
      uint256 _typeWeight = _getTypeWeight(gaugeType);
      uint256 _oldSum = _getSum(gaugeType);
      uint256 _oldTotal = _getTotal();

      pointsSum[gaugeType][nextTime].bias = weight + _oldSum;
      timeSum[gaugeType] = nextTime;
      pointsTotal[nextTime] = _oldTotal + _typeWeight * weight;
      timeTotal = nextTime;

      pointsWeight[addr][nextTime].bias = weight;
    }
    if (timeSum[gaugeType] == 0) {
      timeSum[gaugeType] = nextTime;
    }
    timeWeight[addr] = nextTime;

    emit NewGauge(addr, gaugeType, weight);
  }

  function addGauge(address addr, uint128 gaugeType) external {
    this.addGauge(addr, gaugeType, 0);
  }

  function checkpoint() external {
    _getTotal();
  }

  function checkpointGauge(address addr) external {
    _getWeight(addr);
    _getTotal();
  }

  function _gaugeRelativeWeight(
    address addr,
    uint256 time
  ) internal view returns (uint256) {
    uint256 t = (time / WEEK) * WEEK;
    uint256 _totalWeight = pointsTotal[t];

    if (_totalWeight > 0) {
      uint128 gaugeType = gaugeTypes_[addr] - 1;
      uint256 _typeWeight = pointsTypeWeight[gaugeType][t];
      uint256 _gaugeWeight = pointsWeight[addr][t].bias;
      return (MULTIPLIER * _typeWeight * _gaugeWeight) / _totalWeight;
    } else {
      return 0;
    }
  }

  function gaugeRelativeWeight(
    address addr,
    uint256 time
  ) external view returns (uint256) {
    return _gaugeRelativeWeight(addr, time);
  }

  function gaugeRelativeWeight(address addr) external view returns (uint256) {
    return this.gaugeRelativeWeight(addr, block.timestamp);
  }

  function gaugeRelativeWeightWrite(
    address addr,
    uint256 time
  ) external returns (uint256) {
    _getWeight(addr);
    _getTotal(); // Also calculates getSum
    return _gaugeRelativeWeight(addr, time);
  }

  function gaugeRelativeWeightWrite(address addr) external returns (uint256) {
    return this.gaugeRelativeWeightWrite(addr, block.timestamp);
  }

  function _changeTypeWeight(uint128 typeId, uint256 weight) internal {
    uint256 oldWeight = _getTypeWeight(typeId);
    uint256 oldSum = _getSum(typeId);
    uint256 _totalWeight = _getTotal();
    uint256 nextTime = ((block.timestamp + WEEK) / WEEK) * WEEK;

    _totalWeight = _totalWeight + oldSum * weight - oldSum * oldWeight;
    pointsTotal[nextTime] = _totalWeight;
    pointsTypeWeight[typeId][nextTime] = weight;
    timeTotal = nextTime;
    timeTypeWeight[typeId] = nextTime;

    emit NewTypeWeight(typeId, nextTime, weight, _totalWeight);
  }

  function addType(string calldata _name, uint256 weight) external {
    require(msg.sender == admin, "not admin");
    uint128 typeId = nGaugeTypes;
    gaugeTypeNames[typeId] = _name;
    nGaugeTypes = typeId + 1;
    if (weight != 0) {
      _changeTypeWeight(typeId, weight);
      emit AddType(_name, typeId);
    }
  }

  function addType(string calldata _name) external {
    this.addType(_name, 0);
  }

  function changeTypeWeight(uint128 typeId, uint256 weight) external {
    require(msg.sender == admin, "not admin");
    _changeTypeWeight(typeId, weight);
  }

  function _changeGaugeWeight(address addr, uint256 weight) internal {
    // Change gauge weight
    // Only needed when testing in reality
    uint128 gaugeType = gaugeTypes_[addr] - 1;
    uint256 oldGaugeWeight = _getWeight(addr);
    uint256 typeWeight = _getTypeWeight(gaugeType);
    uint256 oldSum = _getSum(gaugeType);
    uint256 _totalWeight = _getTotal();
    uint256 nextTime = ((block.timestamp + WEEK) / WEEK) * WEEK;

    pointsWeight[addr][nextTime].bias = weight;
    timeWeight[addr] = nextTime;

    uint256 newSum = oldSum + weight - oldGaugeWeight;
    pointsSum[gaugeType][nextTime].bias = newSum;
    timeSum[gaugeType] = nextTime;

    _totalWeight = _totalWeight + newSum * typeWeight - oldSum * typeWeight;
    pointsTotal[nextTime] = _totalWeight;
    timeTotal = nextTime;

    emit NewGaugeWeight(addr, block.timestamp, weight, _totalWeight);
  }

  function changeGaugeWeight(address addr, uint256 weight) external {
    require(msg.sender == admin, "not admin");
    _changeGaugeWeight(addr, weight);
  }

  function voteForGaugeWeights(
    address _gaugeAddr,
    uint256 _userWeight
  ) external {
    address escrow = votingEscrow;
    uint256 slope = uint256(VotingEscrow(escrow).getLastUserSlope(msg.sender));
    uint256 lockEnd = VotingEscrow(escrow).lockedEnd(msg.sender);
    uint256 nextTime = ((block.timestamp + WEEK) / WEEK) * WEEK;
    require(lockEnd > nextTime, "Your token lock expires too soon");
    require(
      (_userWeight >= 0) && (_userWeight <= 10000),
      "You used all your voting power"
    );
    require(
      block.timestamp >=
        lastUserVote[msg.sender][_gaugeAddr] + WEIGHT_VOTE_DELAY,
      "Cannot vote so often"
    );

    uint128 gaugeType = gaugeTypes_[_gaugeAddr] - 1;
    require(gaugeType >= 0, "Gauge not added");
    // Prepare slopes and biases in memory
    VotedSlope memory oldSlope = voteUserSlopes[msg.sender][_gaugeAddr];
    uint256 oldDt = 0;
    if (oldSlope.end > nextTime) {
      oldDt = oldSlope.end - nextTime;
    }
    uint256 oldBias = oldSlope.slope * oldDt;
    VotedSlope memory newSlope = VotedSlope({
      slope: (slope * _userWeight) / 10000,
      end: lockEnd,
      power: _userWeight
    });
    uint256 newDt = lockEnd - nextTime; // dev: raises when expired
    uint256 newBias = newSlope.slope * newDt;

    // Check and update powers (weights) used
    uint256 powerUsed = voteUserPower[msg.sender];
    powerUsed = powerUsed + newSlope.power - oldSlope.power;
    voteUserPower[msg.sender] = powerUsed;
    require((powerUsed >= 0) && (powerUsed <= 10000), "Used too much power");

    // Remove old and schedule new slope changes
    // Remove slope changes for old slopes
    // Schedule recording of initial slope for nextTime
    uint256 oldWeightBias = _getWeight(_gaugeAddr);
    uint256 oldWeightSlope = pointsWeight[_gaugeAddr][nextTime].slope;
    uint256 oldSumBias = _getSum(gaugeType);
    uint256 oldSumSlope = pointsSum[gaugeType][nextTime].slope;

    pointsWeight[_gaugeAddr][nextTime].bias =
      max(oldWeightBias + newBias, oldBias) -
      oldBias;
    pointsSum[gaugeType][nextTime].bias =
      max(oldSumBias + newBias, oldBias) -
      oldBias;
    if (oldSlope.end > nextTime) {
      pointsWeight[_gaugeAddr][nextTime].slope =
        max(oldWeightSlope + newSlope.slope, oldSlope.slope) -
        oldSlope.slope;
      pointsSum[gaugeType][nextTime].slope =
        max(oldSumSlope + newSlope.slope, oldSlope.slope) -
        oldSlope.slope;
    } else {
      pointsWeight[_gaugeAddr][nextTime].slope += newSlope.slope;
      pointsSum[gaugeType][nextTime].slope += newSlope.slope;
    }
    if (oldSlope.end > block.timestamp) {
      // Cancel old slope changes if they still didn't happen
      changesWeight[_gaugeAddr][oldSlope.end] -= oldSlope.slope;
      changesSum[gaugeType][oldSlope.end] -= oldSlope.slope;
    }
    // Add slope changes for new slopes
    changesWeight[_gaugeAddr][newSlope.end] += newSlope.slope;
    changesSum[gaugeType][newSlope.end] += newSlope.slope;

    _getTotal();

    voteUserSlopes[msg.sender][_gaugeAddr] = newSlope;

    // Record last action time
    lastUserVote[msg.sender][_gaugeAddr] = block.timestamp;

    emit VoteForGauge(block.timestamp, msg.sender, _gaugeAddr, _userWeight);
  }

  function getGaugeWeight(address addr) external view returns (uint256) {
    return pointsWeight[addr][timeWeight[addr]].bias;
  }

  function getTypeWeight(uint128 typeId) external view returns (uint256) {
    return pointsTypeWeight[typeId][timeTypeWeight[typeId]];
  }

  function getTotalWeight() external view returns (uint256) {
    return pointsTotal[timeTotal];
  }

  function getWeightsSumPerType(
    uint128 typeId
  ) external view returns (uint256) {
    return pointsSum[typeId][timeSum[typeId]].bias;
  }

  function getGauge(uint128 index) external view returns (address) {
    return gauges[index];
  }
}
