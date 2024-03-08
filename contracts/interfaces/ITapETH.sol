// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITapETH is IERC20 {
  function proposeGovernance(address _governance) external;

  function acceptGovernance() external;

  function addPool(address _pool) external;

  function removePool(address _pool) external;

  function increaseAllowance(
    address _spender,
    uint256 _addedValue
  ) external returns (bool);

  function decreaseAllowance(
    address _spender,
    uint256 _subtractedValue
  ) external returns (bool);

  function totalShares() external view returns (uint256);

  function totalRewards() external view returns (uint256);

  function sharesOf(address _account) external view returns (uint256);

  function getSharesByPooledEth(
    uint256 _ethAmount
  ) external view returns (uint256);

  function addTotalSupply(uint256 _amount) external;

  function getPooledEthByShares(
    uint256 _sharesAmount
  ) external view returns (uint256);

  function transferShares(
    address _recipient,
    uint256 _sharesAmount
  ) external returns (uint256);

  function transferSharesFrom(
    address _sender,
    address _recipient,
    uint256 _sharesAmount
  ) external returns (uint256);

  function mintShares(address _account, uint256 _sharesAmount) external;

  function burnShares(uint256 _sharesAmount) external;

  function burnSharesFrom(address _account, uint256 _sharesAmount) external;
}
