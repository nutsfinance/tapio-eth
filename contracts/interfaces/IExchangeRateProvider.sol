// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title ITokensWithExchangeRate interface
 * @author Nuts Finance Developer
 * @notice Interface for tokens with exchange rate functionality
 */
interface IExchangeRateProvider {
  /**
   * @dev Returns the exchange rate of the token.
   * @return The exchange rate of the token.
   */
  function exchangeRate() external view returns (uint256);

  /**
   * @dev Returns the exchange rate decimals.
   * @return The exchange rate decimals of the token.
   */
  function exchangeRateDecimals() external view returns (uint256);
}
