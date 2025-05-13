# ERC4626ExchangeRate

**Inherits:** [IExchangeRateProvider](/src/interfaces/IExchangeRateProvider.sol/interface.IExchangeRateProvider.md)

ERC4626 exchange rate.

## State Variables

### token

_ERC4626 token_

```solidity
IERC4626 public token;
```

## Functions

### constructor

_Initialize the contract_

```solidity
constructor(IERC4626 _token);
```

### exchangeRate

_Get the exchange rate_

```solidity
function exchangeRate() external view returns (uint256);
```

### exchangeRateDecimals

_Get the exchange rate decimals_

```solidity
function exchangeRateDecimals() external view returns (uint256);
```
