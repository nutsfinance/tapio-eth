// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

/**
 * @title GaugeController
 * @author Nuts Finance Developer
 * @notice The GaugeController provides a way to distribute reward
 * @dev The GaugeController contract allows reward distribution
 */
contract GaugeController is Initializable, ReentrancyGuardUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;
  uint256 public constant WEEK = 604800;

  /**
   * @dev This is the account that has governance control over the GaugeController contract.
   */
  address public governance;

  /**
   * @dev Address for the reward token.
   */
  address public rewardToken;

  /**
   * @dev Address for stable asset token.
   */
  address public poolToken;

  /**
   * @dev This is a mapping of index and pool address.
   */
  mapping(uint256 => address) public poolIndexToAddress;

  /**
   * @dev This is a mapping of index and pool address.
   */
  mapping(address => uint256) public poolAddressToIndex;

  /**
   * @dev This is a mapping of index and total reward claimable.
   */
  mapping(uint256 => uint256) public claimable;

  /**
   * @dev This is a mapping of index and reward claimed.
   */
  mapping(uint256 => uint256) public claimed;

  /**
   * @dev This is a mapping of index and pool activated.
   */
  mapping(uint256 => bool) public poolActivated;

  /**
   * @dev This is a mapping of index and pool weight.
   */
  mapping(uint256 => uint256) public poolWeight;

  /**
   * @dev This is the total count of pool.
   */
  uint256 public poolSize;

  /**
   * @dev This is reward rate per week.
   */
  uint256 public rewardRatePerWeek;

  /**
   * @dev This is last checkpoint timestamp.
   */
  uint256 public lastCheckpoint;

  /**
   * @dev This event is emitted when the governance is modified.
   * @param governance is the new value of the governance.
   */
  event GovernanceModified(address governance);

  /**
   * @dev This event is emitted when the rewardRatePerWeek is modified.
   * @param rewardRatePerWeek is the new value of the rewardRatePerWeek.
   */
  event RewardRateModified(uint256 rewardRatePerWeek);

  /**
   * @dev This event is emitted when a new pool is added.
   * @param poolIndex is the new pool index.
   * @param poolAddress is the new pool address.
   */
  event PoolAdded(uint256 indexed poolIndex, address indexed poolAddress);

  /**
   * @dev This event is emitted when a pool is enabled.
   * @param poolIndex is the pool index.
   * @param poolAddress is the pool address.
   */
  event PoolEnabled(uint256 indexed poolIndex, address indexed poolAddress);

  /**
   * @dev This event is emitted when a pool is disabled.
   * @param poolIndex is the pool index.
   * @param poolAddress is the pool address.
   */
  event PoolDisabled(uint256 indexed poolIndex, address indexed poolAddress);

  /**
   * @dev This event is emitted when a pool weight is updated.
   * @param poolIndex is the pool index.
   * @param poolAddress is the pool address.
   * @param weight is the pool weight.
   */
  event PoolWeightUpdated(
    uint256 indexed poolIndex,
    address indexed poolAddress,
    uint256 weight
  );

  /**
   * @dev This event is emitted when a reward is claimed.
   * @param poolIndex is the pool index.
   * @param poolAddress is the pool address.
   * @param amount is the amount claimed.
   */
  event Claimed(
    uint256 indexed poolIndex,
    address indexed poolAddress,
    uint256 amount
  );

  /**
   * @dev This event is emitted when a reward is checkpointed.
   * @param poolIndex is the pool index.
   * @param poolAddress is the pool address.
   * @param totalAmount is the amount claimed.
   * @param timestamp is timestamp of checkpoint.
   */
  event Checkpointed(
    uint256 indexed poolIndex,
    address indexed poolAddress,
    uint256 totalAmount,
    uint256 timestamp
  );

  /**
   * @dev Initializes the GaugeController contract with the given parameters.
   * @param _rewardToken The address for the reward token.
   * @param _poolToken The address that receives yield farming rewards.
   */
  function initialize(
    address _rewardToken,
    address _poolToken,
    uint256 _rewardRatePerWeek
  ) public initializer {
    require(_rewardToken != address(0x0), "reward token not set");
    require(_poolToken != address(0x0), "pool token not set");
    require(_rewardRatePerWeek != 0, "reward rate not set");
    __ReentrancyGuard_init();

    governance = msg.sender;
    rewardToken = _rewardToken;
    poolToken = _poolToken;
    rewardRatePerWeek = _rewardRatePerWeek;
    lastCheckpoint = block.timestamp;
  }

  /**
   * @dev Updates the govenance address.
   * @param _governance The new governance address.
   */
  function setGovernance(address _governance) external {
    require(msg.sender == governance, "not governance");
    require(_governance != address(0x0), "governance not set");
    governance = _governance;
    emit GovernanceModified(_governance);
  }

  /**
   * @dev Updates the reward rate.
   * @param _rewardRatePerWeek The new reward rate.
   */
  function updateRewardRate(uint256 _rewardRatePerWeek) external {
    require(msg.sender == governance, "not governance");
    require(_rewardRatePerWeek != 0, "reward rate not set");
    rewardRatePerWeek = _rewardRatePerWeek;
    emit RewardRateModified(_rewardRatePerWeek);
  }

  /**
   * @dev Add a new pool.
   * @param _poolAddress The pool address to add.
   */
  function addPool(address _poolAddress) external {
    require(msg.sender == governance, "not governance");
    require(_poolAddress != address(0x0), "pool address not set");

    uint256 newPoolIndex = poolSize++;
    poolIndexToAddress[newPoolIndex] = _poolAddress;
    poolAddressToIndex[_poolAddress] = newPoolIndex;
    poolActivated[newPoolIndex] = true;
    poolWeight[newPoolIndex] = 0;
    emit PoolAdded(newPoolIndex, _poolAddress);
    emit PoolEnabled(newPoolIndex, _poolAddress);
  }

  /**
   * @dev Enable a pool.
   * @param _poolIndex The pool index to enable.
   */
  function enablePool(uint256 _poolIndex) external {
    require(msg.sender == governance, "not governance");
    address _poolAddress = poolIndexToAddress[_poolIndex];
    require(_poolAddress != address(0x0), "pool address not set");
    poolActivated[_poolIndex] = true;
    emit PoolEnabled(_poolIndex, _poolAddress);
  }

  /**
   * @dev Disable a pool.
   * @param _poolIndex The pool index to disable.
   */
  function disablePool(uint256 _poolIndex) external {
    require(msg.sender == governance, "not governance");
    address _poolAddress = poolIndexToAddress[_poolIndex];
    require(_poolAddress != address(0x0), "pool address not set");
    poolActivated[_poolIndex] = false;
    emit PoolDisabled(_poolIndex, _poolAddress);
  }

  /**
   * @dev Disable a pool.
   * @param _poolIndex The pool index to modify weight.
   * @param weight The pool weight.
   */
  function updatePoolWeight(uint256 _poolIndex, uint256 weight) external {
    require(msg.sender == governance, "not governance");
    address _poolAddress = poolIndexToAddress[_poolIndex];
    require(_poolAddress != address(0x0), "pool address not set");
    poolWeight[_poolIndex] = weight;
    emit PoolWeightUpdated(_poolIndex, _poolAddress, weight);
  }

  /**
   * @dev Calculate new reward.
   */
  function _checkpoint() internal {
    uint256 currentTimestamp = block.timestamp;
    uint256 rewardAvailable = (rewardRatePerWeek *
      (currentTimestamp - lastCheckpoint)) / WEEK;
    uint256 total = 0;
    for (uint256 i = 0; i < poolSize; i++) {
      total += getRewardForPool(i);
    }
    for (uint256 i = 0; i < poolSize; i++) {
      uint256 share = 0;
      if (total > 0) {
        share = (getRewardForPool(i) * rewardAvailable) / total;
      }
      claimable[i] += share;
      emit Checkpointed(
        i,
        poolIndexToAddress[i],
        claimable[i],
        currentTimestamp
      );
    }

    lastCheckpoint = currentTimestamp;
  }

  /**
   * @dev Calculate new reward.
   */
  function checkpoint() external {
    _checkpoint();
  }

  /**
   * @dev Calculate new reward for a pool.
   */
  function getRewardForPool(uint256 poolIndex) internal view returns (uint256) {
    if (!poolActivated[poolIndex]) {
      return 0;
    }
    return
      IERC20Upgradeable(poolToken).balanceOf(poolIndexToAddress[poolIndex]) *
      poolWeight[poolIndex];
  }

  /**
   * @dev Claim reward.
   */
  function claim() external {
    uint256 poolIndex = poolAddressToIndex[msg.sender];
    require(msg.sender == poolIndexToAddress[poolIndex], "not registered");
    _checkpoint();
    uint256 amount = claimable[poolIndex] - claimed[poolIndex];
    IERC20Upgradeable(rewardToken).safeTransfer(msg.sender, amount);
    claimed[poolIndex] += amount;
    emit Claimed(poolIndex, msg.sender, amount);
  }
}
