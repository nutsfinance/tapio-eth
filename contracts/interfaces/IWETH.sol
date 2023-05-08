// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

/**
 * @title IWETH interface
 * @author Nuts Finance Developer
 * @notice Interface for WETH
 */
interface IWETH {
  /**
   * @dev Deposit ether to get wrapped ether.
   */
  function deposit() external payable;

  /**
   * @dev Transfer wrapped ether to get ether.
   * @param to The address of the receiver.
   * @param value The amount of wrapped ether to transfer.
   * @return Whether the transfer succeeds.
   */
  function transfer(address to, uint value) external returns (bool);

  /**
   * @dev Withdraw wrapped ether to get ether.
   * @param value The amount of wrapped ether to withdraw.
   */
  function withdraw(uint value) external;
}
