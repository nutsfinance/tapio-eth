// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./GaugeRewardController.sol";

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
   * @dev Controller for reward weight calculation.
   */
  IGaugeRewardController public rewardController;

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
   * @dev This is a mapping of index and total reward claimable.
   */
  mapping(address => uint256) public claimable;

  /**
   * @dev This is a mapping of index and reward claimed.
   */
  mapping(address => uint256) public claimed;

  /**
   * @dev This is reward rate per week.
   */
  uint256 public rewardRatePerWeek;

  /**
   * @dev This is last checkpoint timestamp.
   */
  uint256 public lastCheckpoint;

  /**
   * @dev Pending governance address,
   */
  address public pendingGovernance;

  /**
   * @dev This event is emitted when the governance is modified.
   * @param governance is the new value of the governance.
   */
  event GovernanceModified(address governance);

  /**
   * @dev This event is emitted when the governance is modified.
   * @param governance is the new value of the governance.
   */
  event GovernanceProposed(address governance);

  /**
   * @dev This event is emitted when the rewardRatePerWeek is modified.
   * @param rewardRatePerWeek is the new value of the rewardRatePerWeek.
   */
  event RewardRateModified(uint256 rewardRatePerWeek);

  /**
   * @dev This event is emitted when a reward is claimed.
   * @param poolAddress is the pool address.
   * @param amount is the amount claimed.
   */
  event Claimed(
    address indexed poolAddress,
    uint256 amount
  );

  /**
   * @dev This event is emitted when a reward is checkpointed.
   * @param poolAddress is the pool address.
   * @param totalAmount is the amount claimed.
   * @param timestamp is timestamp of checkpoint.
   */
  event Checkpointed(
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
    uint256 _rewardRatePerWeek,
    IGaugeRewardController _rewardController
  ) public initializer {
    require(_rewardToken != address(0x0), "reward token not set");
    require(_poolToken != address(0x0), "pool token not set");
    require(_rewardRatePerWeek != 0, "reward rate not set");
    __ReentrancyGuard_init();

    governance = msg.sender;
    rewardToken = _rewardToken;
    poolToken = _poolToken;
    rewardRatePerWeek = _rewardRatePerWeek;
    rewardController = _rewardController;
    lastCheckpoint = block.timestamp;
  }

  /**
   * @dev Propose the govenance address.
   * @param _governance Address of the new governance.
   */
  function proposeGovernance(address _governance) public {
    require(msg.sender == governance, "not governance");
    pendingGovernance = _governance;
    emit GovernanceProposed(_governance);
  }

  /**
   * @dev Accept the govenance address.
   */
  function acceptGovernance() public {
    require(msg.sender == pendingGovernance, "not pending governance");
    governance = pendingGovernance;
    pendingGovernance = address(0);
    emit GovernanceModified(governance);
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
   * @dev Calculate new reward.
   */
  function _checkpoint() internal {
    uint256 currentTimestamp = block.timestamp;
    uint256 rewardAvailable = (rewardRatePerWeek *
      (currentTimestamp - lastCheckpoint)) / WEEK;
    uint256 total = 0;
    uint128 poolSize = rewardController.nGauges();
    uint256[] memory rewardPoolsCalc = new uint256[](poolSize);
    for (uint128 i = 0; i < poolSize; i++) {
      uint256 result = getRewardForPoolWrite(i);
      total += result;
      rewardPoolsCalc[i] = result;
    }
    for (uint128 i = 0; i < poolSize; i++) {
      address poolAddress = rewardController.getGauge(i);
      uint256 share = 0;
      if (total > 0) {
        share = (rewardPoolsCalc[i] * rewardAvailable) / total;
      }
      claimable[poolAddress] += share;
      emit Checkpointed(
        poolAddress,
        claimable[poolAddress],
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
  function getRewardForPoolWrite(uint128 poolIndex) internal returns (uint256) {
    address poolAddress = rewardController.getGauge(poolIndex);
    return
      IERC20Upgradeable(poolToken).balanceOf(poolAddress) * rewardController.gaugeRelativeWeightWrite(poolAddress);
  }

  /**
   * @dev Calculate new reward for a pool.
   */
  function getRewardForPool(uint128 poolIndex) internal view returns (uint256) {
    address poolAddress = rewardController.getGauge(poolIndex);
    return
      IERC20Upgradeable(poolToken).balanceOf(poolAddress) * rewardController.gaugeRelativeWeight(poolAddress);
  }

  /**
   * @dev Claim reward.
   */
  function claim() external {
    address poolAddress = msg.sender;
    _checkpoint();
    uint256 amount = claimable[poolAddress] - claimed[poolAddress];
    IERC20Upgradeable(rewardToken).safeTransfer(msg.sender, amount);
    claimed[poolAddress] += amount;
    emit Claimed(poolAddress, amount);
  }

  /**
   * @dev Get claimable reward.
   */
  function getClaimable() external view returns (uint256) {
    address poolAddress = msg.sender;
    uint256 currentTimestamp = block.timestamp;
    uint256 rewardAvailable = (rewardRatePerWeek *
      (currentTimestamp - lastCheckpoint)) / WEEK;
    uint256 total = 0;
    uint128 poolSize = rewardController.nGauges();
    uint256[] memory rewardPoolsCalc = new uint256[](poolSize);
    for (uint128 i = 0; i < poolSize; i++) {
      uint256 result = getRewardForPool(i);
      total += result;
      rewardPoolsCalc[i] = result;
    }
    for (uint128 i = 0; i < poolSize; i++) {
      address poolAddress = rewardController.getGauge(i);
      uint256 share = 0;
      if (total > 0) {
        share = (rewardPoolsCalc[i] * rewardAvailable) / total;
      }
      if (poolAddress == msg.sender) {
        return share;
      }
    }
    return 0;
  }
}
