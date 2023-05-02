// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../interfaces/ITokensWithExchangeRate.sol";

/**
 * @notice Mock exchange rate.
 */
contract MockExchangeRateProvider is ITokensWithExchangeRate {
  uint256 private rate;

  constructor(uint256 _rate) {
    rate = _rate;
  }

  function exchangeRate() external view returns (uint256) {
    return rate;
  }

  function newRate(uint256 _rate) external {
    rate = _rate;
  }
}
