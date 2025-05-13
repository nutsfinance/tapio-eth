# RocketTokenExchangeRateProvider

**Inherits:** [IExchangeRateProvider](/src/interfaces/IExchangeRateProvider.sol/interface.IExchangeRateProvider.md),
Initializable, ReentrancyGuardUpgradeable

Rocket Token exchange rate.

## State Variables

### rocketToken

_Rocket Token contract_

```solidity
RocketTokenRETHInterface private rocketToken;
```

## Functions

### initialize

_Initialize the contract_

```solidity
function initialize(RocketTokenRETHInterface _rocketToken) public initializer;
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

### RocketTokenNotSet

_Error thrown when the Rocket Token is not set_

```solidity
error RocketTokenNotSet();
```
