// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/**
 * @title ITokensWithExchangeRate interface
 * @author Nuts Finance Developer
 * @notice Interface for tokens with exchange rate functionality
 */
interface ITokensWithExchangeRate {
  /**
   * @dev Returns the exchange rate of the token.
   * @return The exchange rate of the token.
   */
  function exchangeRate() external view returns (uint256);
}
