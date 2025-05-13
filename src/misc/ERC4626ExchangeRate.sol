// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "../interfaces/IExchangeRateProvider.sol";

/**
 * @notice ERC4626 exchange rate.
 */
contract ERC4626ExchangeRate is IExchangeRateProvider {
    /// @dev ERC4626 token
    IERC4626 public token;

    /// @dev Initialize the contract
    constructor(IERC4626 _token) {
        token = _token;
    }

    /// @dev Get the exchange rate
    function exchangeRate() external view returns (uint256) {
        return token.convertToAssets(10 ** token.decimals());
    }

    /// @dev Get the exchange rate decimals
    function exchangeRateDecimals() external view returns (uint256) {
        return token.decimals();
    }
}
