# ITapETH









## Methods

### acceptGovernance

```solidity
function acceptGovernance() external nonpayable
```






### addPool

```solidity
function addPool(address _pool) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _pool | address | undefined |

### allowance

```solidity
function allowance(address owner, address spender) external view returns (uint256)
```



*Returns the remaining number of tokens that `spender` will be allowed to spend on behalf of `owner` through {transferFrom}. This is zero by default. This value changes when {approve} or {transferFrom} are called.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| owner | address | undefined |
| spender | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### approve

```solidity
function approve(address spender, uint256 amount) external nonpayable returns (bool)
```



*Sets `amount` as the allowance of `spender` over the caller&#39;s tokens. Returns a boolean value indicating whether the operation succeeded. IMPORTANT: Beware that changing an allowance with this method brings the risk that someone may use both the old and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this race condition is to first reduce the spender&#39;s allowance to 0 and set the desired value afterwards: https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729 Emits an {Approval} event.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| spender | address | undefined |
| amount | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### balanceOf

```solidity
function balanceOf(address account) external view returns (uint256)
```



*Returns the amount of tokens owned by `account`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| account | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### burnShares

```solidity
function burnShares(uint256 _sharesAmount) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _sharesAmount | uint256 | undefined |

### burnSharesFrom

```solidity
function burnSharesFrom(address _account, uint256 _sharesAmount) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _account | address | undefined |
| _sharesAmount | uint256 | undefined |

### decreaseAllowance

```solidity
function decreaseAllowance(address _spender, uint256 _subtractedValue) external nonpayable returns (bool)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _spender | address | undefined |
| _subtractedValue | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### getPooledEthByShares

```solidity
function getPooledEthByShares(uint256 _sharesAmount) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _sharesAmount | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getSharesByPooledEth

```solidity
function getSharesByPooledEth(uint256 _ethAmount) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _ethAmount | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getTotalPooledEther

```solidity
function getTotalPooledEther() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getTotalShares

```solidity
function getTotalShares() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### increaseAllowance

```solidity
function increaseAllowance(address _spender, uint256 _addedValue) external nonpayable returns (bool)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _spender | address | undefined |
| _addedValue | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### mintShares

```solidity
function mintShares(address _account, uint256 _sharesAmount) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _account | address | undefined |
| _sharesAmount | uint256 | undefined |

### proposeGovernance

```solidity
function proposeGovernance(address _governance) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _governance | address | undefined |

### removePool

```solidity
function removePool(address _pool) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _pool | address | undefined |

### setBuffer

```solidity
function setBuffer(uint256 _amount) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _amount | uint256 | undefined |

### setTotalSupply

```solidity
function setTotalSupply(uint256 _amount) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _amount | uint256 | undefined |

### sharesOf

```solidity
function sharesOf(address _account) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _account | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### totalSupply

```solidity
function totalSupply() external view returns (uint256)
```



*Returns the amount of tokens in existence.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### transfer

```solidity
function transfer(address to, uint256 amount) external nonpayable returns (bool)
```



*Moves `amount` tokens from the caller&#39;s account to `to`. Returns a boolean value indicating whether the operation succeeded. Emits a {Transfer} event.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | undefined |
| amount | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### transferFrom

```solidity
function transferFrom(address from, address to, uint256 amount) external nonpayable returns (bool)
```



*Moves `amount` tokens from `from` to `to` using the allowance mechanism. `amount` is then deducted from the caller&#39;s allowance. Returns a boolean value indicating whether the operation succeeded. Emits a {Transfer} event.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| from | address | undefined |
| to | address | undefined |
| amount | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### transferShares

```solidity
function transferShares(address _recipient, uint256 _sharesAmount) external nonpayable returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _recipient | address | undefined |
| _sharesAmount | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### transferSharesFrom

```solidity
function transferSharesFrom(address _sender, address _recipient, uint256 _sharesAmount) external nonpayable returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _sender | address | undefined |
| _recipient | address | undefined |
| _sharesAmount | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |



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



