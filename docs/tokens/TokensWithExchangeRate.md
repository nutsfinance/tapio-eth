# TokensWithExchangeRate

*Nuts Finance Developer*

> Tokens With Exchange Rate Contract



*This contract implements the IERC20 interface and extends from the Initializable and ReentrancyGuardUpgradeable contracts. It provides a basic structure for tokens with exchange rate functionality.*

## Methods

### allowance

```solidity
function allowance(address owner, address spender) external view returns (uint256)
```



*Get the allowance of a spender for an owner&#39;s account.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| owner | address | The address of the owner. |
| spender | address | The address of the spender. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The allowance of the spender for the owner&#39;s account. |

### approve

```solidity
function approve(address spender, uint256 amount) external nonpayable returns (bool)
```



*Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| spender | address | The address which will spend the funds. |
| amount | uint256 | The amount of tokens to be spent. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | A boolean that indicates if the operation was successful. |

### balanceOf

```solidity
function balanceOf(address account) external view returns (uint256)
```



*Get the balance of an account.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| account | address | The address of the account. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The balance of the account. |

### exchangeRateDecimal

```solidity
function exchangeRateDecimal() external view returns (uint8)
```



*The decimals of the exchange rate.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint8 | undefined |

### exchangeRateProvider

```solidity
function exchangeRateProvider() external view returns (contract ITokensWithExchangeRate)
```



*The address of the exchange rate provider.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract ITokensWithExchangeRate | undefined |

### initialize

```solidity
function initialize(address _token, address _exchangeRateProvider, uint8 _decimals) external nonpayable
```



*Initializes the contract setting the deployer as the initial owner.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _token | address | The address of the token. |
| _exchangeRateProvider | address | The address of the exchange rate provider. |
| _decimals | uint8 | The decimals of the exchange rate. |

### token

```solidity
function token() external view returns (address)
```



*The address of the token.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### totalSupply

```solidity
function totalSupply() external view returns (uint256)
```



*Get the total supply of the token.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The total supply of the token. |

### transfer

```solidity
function transfer(address to, uint256 amount) external nonpayable returns (bool)
```



*Transfer tokens to a specified address.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | The address to transfer to. |
| amount | uint256 | The amount to be transferred. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | A boolean that indicates if the operation was successful. |

### transferFrom

```solidity
function transferFrom(address from, address to, uint256 amount) external nonpayable returns (bool)
```



*Transfer tokens from one address to another.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| from | address | The address which you want to send tokens from. |
| to | address | The address which you want to transfer to. |
| amount | uint256 | The amount of tokens to be transferred. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | A boolean that indicates if the operation was successful. |



## Events

### Approval

```solidity
event Approval(address indexed owner, address indexed spender, uint256 value)
```



*Emitted when the allowance of a `spender` for an `owner` is set by a call to {approve}. `value` is the new allowance.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| owner `indexed` | address | undefined |
| spender `indexed` | address | undefined |
| value  | uint256 | undefined |

### Initialized

```solidity
event Initialized(uint8 version)
```



*Triggered when the contract has been initialized or reinitialized.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| version  | uint8 | undefined |

### Transfer

```solidity
event Transfer(address indexed from, address indexed to, uint256 value)
```



*Emitted when `value` tokens are moved from one account (`from`) to another (`to`). Note that `value` may be zero.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| from `indexed` | address | undefined |
| to `indexed` | address | undefined |
| value  | uint256 | undefined |



