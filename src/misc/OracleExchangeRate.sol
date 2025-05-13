// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../interfaces/IExchangeRateProvider.sol";

/**
 * @notice Oracle exchange rate.
 */
contract OracleExchangeRate is IExchangeRateProvider {
    /// @dev Oracle address
    address public oracle;

    /// @dev Rate function signature
    bytes public rateFunc;

    /// @dev Decimals function signature
    bytes public decimalsFunc;

    /// @dev Error thrown when the internal call failed
    error InternalCallFailed();

    /// @dev Initialize the contract
    constructor(address _oracle, bytes memory _rateFunc, bytes memory _decimalsFunc) {
        oracle = _oracle;
        rateFunc = _rateFunc;
        decimalsFunc = _decimalsFunc;
    }

    /// @dev Get the exchange rate
    function exchangeRate() external view returns (uint256) {
        (bool success, bytes memory result) = oracle.staticcall(rateFunc);
        require(success, InternalCallFailed());

        uint256 decodedResult = abi.decode(result, (uint256));

        return decodedResult;
    }

    /// @dev Get the exchange rate decimals
    function exchangeRateDecimals() external view returns (uint256) {
        (bool success, bytes memory result) = oracle.staticcall(decimalsFunc);
        require(success, InternalCallFailed());

        uint256 decodedResult = abi.decode(result, (uint256));

        return decodedResult;
    }
}
