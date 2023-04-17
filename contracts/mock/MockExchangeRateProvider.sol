// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../interfaces/ITokensWithExchangeRate.sol";

/**
 * @notice Mock ERC20 token.
 */
contract MockExchangeRateProvider is ITokensWithExchangeRate {
  uint256 private rate;

  constructor(uint256 _rate) {
    rate = _rate;
  }

  function exchangeRate() external view returns (uint256 _exchangeRate) {
    return rate;
  }

  function newRate(uint256 _rate) external {
    rate = _rate;
  }
}
