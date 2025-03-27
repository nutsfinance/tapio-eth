// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../../interfaces/IExchangeRateProvider.sol";
import "./RocketTokenRETHInterface.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/**
 * @notice Rocket Token exchange rate.
 */
contract RocketTokenExchangeRateProvider is IExchangeRateProvider, Initializable, ReentrancyGuardUpgradeable {
    /// @dev Rocket Token contract
    RocketTokenRETHInterface private rocketToken;

    /// @dev Error thrown when the Rocket Token is not set
    error RocketTokenNotSet();

    /// @dev Initialize the contract
    function initialize(RocketTokenRETHInterface _rocketToken) public initializer {
        require(address(_rocketToken) != address(0x0), RocketTokenNotSet());
        rocketToken = _rocketToken;
    }

    /// @dev Get the exchange rate
    function exchangeRate() external view returns (uint256) {
        return rocketToken.getExchangeRate();
    }

    /// @dev Get the exchange rate decimals
    function exchangeRateDecimals() external pure returns (uint256) {
        return 18;
    }
}
