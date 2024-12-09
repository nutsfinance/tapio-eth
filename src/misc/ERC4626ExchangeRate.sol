// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "../interfaces/IExchangeRateProvider.sol";

/**
 * @notice Mock exchange rate.
 */
contract ERC4626ExchangeRate is IExchangeRateProvider {
    IERC4626 token;

    constructor(IERC4626 _token) {
        token = _token;
    }

    function exchangeRate() external view returns (uint256) {
        uint256 totalAsset = token.totalAssets();
        uint256 totalSupply = token.totalSupply();
        return (totalAsset * (10 ** 18)) / totalSupply;
    }

    function exchangeRateDecimals() external pure returns (uint256) {
        return 18;
    }
}
