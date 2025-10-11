// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../interfaces/IExchangeRateProvider.sol";

/**
 * @notice Oracle exchange rate provider supporting static or dynamic decimals.
 */
contract OracleExchangeRate is IExchangeRateProvider {
    /// @dev Oracle address
    address public immutable oracle;

    /// @dev If static decimals are used, this stores them
    uint8 public immutable staticDecimals;

    /// @dev Whether decimals are static
    bool public immutable isStaticDecimals;

    /// @dev Rate function signature (always dynamic)
    bytes public rateFunc;

    /// @dev Decimals function signature or encoded static decimals
    bytes public decimalsFunc;

    /// @dev Error thrown when the internal call failed
    error InternalCallFailed();

    constructor(address _oracle, bytes memory _rateFunc, bytes memory _decimalsFunc) {
        oracle = _oracle;
        rateFunc = _rateFunc;
        decimalsFunc = _decimalsFunc;

        if (_decimalsFunc.length == 1) {
            staticDecimals = uint8(bytes1(_decimalsFunc));
            isStaticDecimals = true;
        } else {
            staticDecimals = 0;
            isStaticDecimals = false;
        }
    }

    /// @dev Get the exchange rate
    function exchangeRate() external view returns (uint256) {
        (bool success, bytes memory result) = oracle.staticcall(rateFunc);
        require(success, InternalCallFailed());

        return abi.decode(result, (uint256));
    }

    /// @dev Get the exchange rate decimals (supports static or dynamic mode)
    function exchangeRateDecimals() external view returns (uint256) {
        if (isStaticDecimals) {
            return staticDecimals;
        } else {
            (bool success, bytes memory result) = oracle.staticcall(decimalsFunc);
            require(success, InternalCallFailed());

            return abi.decode(result, (uint256));
        }
    }
}
