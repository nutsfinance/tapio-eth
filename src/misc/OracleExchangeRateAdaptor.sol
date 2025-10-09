// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @notice Oracle exchange rate adaptor
 */
contract OracleExchangeRateAdaptor {
    /// @dev Oracle address
    address public immutable oracle;

    /// @dev Decimals function signature
    uint8 public immutable decimals;

    /// @dev Rate function signature
    bytes public rateFunc;

    /// @dev Error thrown when the internal call failed
    error InternalCallFailed();

    /// @dev Initialize the contract
    constructor(address _oracle, uint8 _decimals, bytes memory _rateFunc) {
        oracle = _oracle;
        decimals = _decimals;
        rateFunc = _rateFunc;
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
        return decimals;
    }
}
