# OracleExchangeRate

**Inherits:** [IExchangeRateProvider](/src/interfaces/IExchangeRateProvider.sol/interface.IExchangeRateProvider.md)

Oracle exchange rate.

## State Variables

### oracle

_Oracle address_

```solidity
address public oracle;
```

### func

_Function signature_

```solidity
string public func;
```

## Functions

### constructor

_Initialize the contract_

```solidity
constructor(address _oracle, string memory _func);
```

### exchangeRate

_Get the exchange rate_

```solidity
function exchangeRate() external view returns (uint256);
```

### exchangeRateDecimals

_Get the exchange rate decimals_

```solidity
function exchangeRateDecimals() external pure returns (uint256);
```

## Errors

### InternalCallFailed

_Error thrown when the internal call failed_

```solidity
error InternalCallFailed();
```
