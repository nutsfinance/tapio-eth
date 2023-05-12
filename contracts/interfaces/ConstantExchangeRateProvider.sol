// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../interfaces/IExchangeRateProvider.sol";

/**
 * @notice Mock exchange rate.
 */
contract ConstantExchangeRateProvider is IExchangeRateProvider {

  function exchangeRate() external view returns (uint256) {
    return 10**18;
  }

  function exchangeRateDecimals() external view returns (uint256) {
    return 18;
  }
}
