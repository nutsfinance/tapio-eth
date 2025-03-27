# MockExchangeRateProvider

**Inherits:** [IExchangeRateProvider](/src/interfaces/IExchangeRateProvider.sol/interface.IExchangeRateProvider.md)

Mock exchange rate.

## State Variables

### rate

```solidity
uint256 private rate;
```

### decimals

```solidity
uint256 private decimals;
```

## Functions

### constructor

```solidity
constructor(uint256 _rate, uint256 _decimals);
```

### newRate

```solidity
function newRate(uint256 _rate) external;
```

### exchangeRate

```solidity
function exchangeRate() external view returns (uint256);
```

### exchangeRateDecimals

```solidity
function exchangeRateDecimals() external view returns (uint256);
```
