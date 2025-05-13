// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../interfaces/IExchangeRateProvider.sol";

/**
 * @notice Constant exchange rate provider.
 */
contract ConstantExchangeRateProvider is IExchangeRateProvider {
    /// @dev Get the exchange rate
    function exchangeRate() external pure returns (uint256) {
        return 10 ** 18;
    }

    /// @dev Get the exchange rate decimals
    function exchangeRateDecimals() external pure returns (uint256) {
        return 18;
    }
}
