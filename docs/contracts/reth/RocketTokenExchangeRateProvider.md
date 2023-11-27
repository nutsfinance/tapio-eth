# RocketTokenExchangeRateProvider





Rocket Token exchange rate.



## Methods

### exchangeRate

```solidity
function exchangeRate() external view returns (uint256)
```



*Returns the exchange rate of the token.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The exchange rate of the token. |

### exchangeRateDecimals

```solidity
function exchangeRateDecimals() external pure returns (uint256)
```



*Returns the exchange rate decimals.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The exchange rate decimals of the token. |

### initialize

```solidity
function initialize(contract RocketTokenRETHInterface _rocketToken) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _rocketToken | contract RocketTokenRETHInterface | undefined |



## Events

### Initialized

```solidity
event Initialized(uint8 version)
```



*Triggered when the contract has been initialized or reinitialized.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| version  | uint8 | undefined |



