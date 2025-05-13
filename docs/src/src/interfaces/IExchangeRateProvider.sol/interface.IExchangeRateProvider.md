# IExchangeRateProvider

**Author:** Nuts Finance Developer

Interface for tokens with exchange rate functionality

## Functions

### exchangeRate

_Returns the exchange rate of the token._

```solidity
function exchangeRate() external view returns (uint256);
```

**Returns**

| Name     | Type      | Description                     |
| -------- | --------- | ------------------------------- |
| `<none>` | `uint256` | The exchange rate of the token. |

### exchangeRateDecimals

_Returns the exchange rate decimals._

```solidity
function exchangeRateDecimals() external view returns (uint256);
```

**Returns**

| Name     | Type      | Description                              |
| -------- | --------- | ---------------------------------------- |
| `<none>` | `uint256` | The exchange rate decimals of the token. |
