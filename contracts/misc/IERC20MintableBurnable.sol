// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/**
 * @notice Interface for ERC20 token which supports mint and burn.
 */
interface IERC20MintableBurnable {
  function mint(address _user, uint256 _amount) external;

  function burn(uint256 _amount) external;

  function burnFrom(address _user, uint256 _amount) external;
}
