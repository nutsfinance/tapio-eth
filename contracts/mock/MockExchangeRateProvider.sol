// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../interfaces/IExchangeRateProvider.sol";

/**
 * @notice Mock exchange rate.
 */
contract MockExchangeRateProvider is IExchangeRateProvider {
  uint256 private rate;
  uint256 private decimals;

  constructor(uint256 _rate, uint256 _decimals) {
    rate = _rate;
    decimals = _decimals;
  }

  function exchangeRate() external view returns (uint256) {
    return rate;
  }

  function newRate(uint256 _rate) external {
    rate = _rate;
  }

  function exchangeRateDecimals() external view returns (uint256) {
    return decimals;
  }
}
