# TapETH

*Nuts Finance Developer*

> Interest-bearing ERC20-like token for Tapio protocol

ERC20 token minted by the StableSwap pools.

*TapETH is ERC20 rebase token minted by StableSwap pools for liquidity providers. TapETH balances are dynamic and represent the holder&#39;s share in the total amount of tapETH controlled by the protocol. Account shares aren&#39;t normalized, so the contract also stores the sum of all shares to calculate each account&#39;s token balance which equals to:   shares[account] * _totalSupply / _totalShares where the _totalSupply is the total supply of tapETH controlled by the protocol.*

## Methods

### BUFFER_DENOMINATOR

```solidity
function BUFFER_DENOMINATOR() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

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

### addTotalSupply

```solidity
function addTotalSupply(uint256 _amount) external nonpayable
```

This function is called only by a stableSwap pool to increase the total supply of TapETH by the staking rewards and the swap fee.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _amount | uint256 | undefined |

### allowance

```solidity
function allowance(address _owner, address _spender) external view returns (uint256)
```



*This value changes when `approve` or `transferFrom` is called.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _owner | address | undefined |
| _spender | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | the remaining number of tokens that `_spender` is allowed to spend on behalf of `_owner` through `transferFrom`. This is zero by default. |

### allowances

```solidity
function allowances(address, address) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |
| _1 | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### approve

```solidity
function approve(address _spender, uint256 _amount) external nonpayable returns (bool)
```

Sets `_amount` as the allowance of `_spender` over the caller&#39;s tokens.

*The `_amount` argument is the amount of tokens, not shares.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _spender | address | undefined |
| _amount | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | a boolean value indicating whether the operation succeeded. Emits an `Approval` event. |

### balanceOf

```solidity
function balanceOf(address _account) external view returns (uint256)
```



*Balances are dynamic and equal the `_account`&#39;s share in the amount of the total tapETH controlled by the protocol. See `sharesOf`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _account | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | the amount of tokens owned by the `_account`. |

### bufferAmount

```solidity
function bufferAmount() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### bufferPercent

```solidity
function bufferPercent() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### burnShares

```solidity
function burnShares(uint256 _tokenAmount) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _tokenAmount | uint256 | undefined |

### burnSharesFrom

```solidity
function burnSharesFrom(address _account, uint256 _tokenAmount) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _account | address | undefined |
| _tokenAmount | uint256 | undefined |

### decimals

```solidity
function decimals() external pure returns (uint8)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint8 | the number of decimals for getting user representation of a token amount. |

### decreaseAllowance

```solidity
function decreaseAllowance(address _spender, uint256 _subtractedValue) external nonpayable returns (bool)
```

Atomically decreases the allowance granted to `_spender` by the caller by `_subtractedValue`. This is an alternative to `approve` that can be used as a mitigation for problems described in: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/b709eae01d1da91902d06ace340df6b324e6f049/contracts/token/ERC20/IERC20.sol#L57 Emits an `Approval` event indicating the updated allowance.



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
| _0 | uint256 | the amount of tapETH that corresponds to `_sharesAmount` token shares. |

### getSharesByPooledEth

```solidity
function getSharesByPooledEth(uint256 _tapETHAmount) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _tapETHAmount | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | the amount of shares that corresponds to `_tapETHAmount` protocol-controlled tapETH. |

### governance

```solidity
function governance() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### increaseAllowance

```solidity
function increaseAllowance(address _spender, uint256 _addedValue) external nonpayable returns (bool)
```

Atomically increases the allowance granted to `_spender` by the caller by `_addedValue`. This is an alternative to `approve` that can be used as a mitigation for problems described in: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/b709eae01d1da91902d06ace340df6b324e6f049/contracts/token/ERC20/IERC20.sol#L57 Emits an `Approval` event indicating the updated allowance.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _spender | address | undefined |
| _addedValue | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### initialize

```solidity
function initialize(address _governance) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _governance | address | undefined |

### mintShares

```solidity
function mintShares(address _account, uint256 _tokenAmount) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _account | address | undefined |
| _tokenAmount | uint256 | undefined |

### name

```solidity
function name() external pure returns (string)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | the name of the token. |

### pendingGovernance

```solidity
function pendingGovernance() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### pools

```solidity
function pools(address) external view returns (bool)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

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

### removeTotalSupply

```solidity
function removeTotalSupply(uint256 _amount) external nonpayable
```

This function is called only by a stableSwap pool to decrease the total supply of TapETH by lost amount.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _amount | uint256 | undefined |

### setBuffer

```solidity
function setBuffer(uint256 _buffer) external nonpayable
```

This function is called by the governance to set the buffer rate.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _buffer | uint256 | undefined |

### shares

```solidity
function shares(address) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

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
| _0 | uint256 | the amount of shares owned by `_account`. |

### symbol

```solidity
function symbol() external pure returns (string)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | the symbol of the token, usually a shorter version of the name. |

### totalRewards

```solidity
function totalRewards() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### totalShares

```solidity
function totalShares() external view returns (uint256)
```






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
function transfer(address _recipient, uint256 _amount) external nonpayable returns (bool)
```

Moves `_amount` tokens from the caller&#39;s account to the `_recipient`account.

*The `_amount` argument is the amount of tokens, not shares.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _recipient | address | undefined |
| _amount | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | a boolean value indicating whether the operation succeeded. Emits a `Transfer` event. Emits a `TransferShares` event. |

### transferFrom

```solidity
function transferFrom(address _sender, address _recipient, uint256 _amount) external nonpayable returns (bool)
```

Moves `_amount` tokens from `_sender` to `_recipient` using the allowance mechanism. `_amount` is then deducted from the caller&#39;s allowance.

*The `_amount` argument is the amount of tokens, not shares.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _sender | address | undefined |
| _recipient | address | undefined |
| _amount | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | a boolean value indicating whether the operation succeeded. Emits a `Transfer` event. Emits a `TransferShares` event. Emits an `Approval` event indicating the updated allowance. Requirements: - the caller must have allowance for `_sender`&#39;s tokens of at least `_amount`. |

### transferShares

```solidity
function transferShares(address _recipient, uint256 _sharesAmount) external nonpayable returns (uint256)
```

Moves `_sharesAmount` token shares from the caller&#39;s account to the `_recipient` account.

*The `_sharesAmount` argument is the amount of shares, not tokens.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _recipient | address | undefined |
| _sharesAmount | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | amount of transferred tokens. Emits a `TransferShares` event. Emits a `Transfer` event. |

### transferSharesFrom

```solidity
function transferSharesFrom(address _sender, address _recipient, uint256 _sharesAmount) external nonpayable returns (uint256)
```

Moves `_sharesAmount` token shares from the `_sender` account to the `_recipient` account.

*The `_sharesAmount` argument is the amount of shares, not tokens.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _sender | address | undefined |
| _recipient | address | undefined |
| _sharesAmount | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | amount of transferred tokens. Emits a `TransferShares` event. Emits a `Transfer` event. Requirements: - the caller must have allowance for `_sender`&#39;s tokens of at least `getPooledEthByShares(_sharesAmount)`. |



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

### BufferDecreased

```solidity
event BufferDecreased(uint256, uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0  | uint256 | undefined |
| _1  | uint256 | undefined |

### BufferIncreased

```solidity
event BufferIncreased(uint256, uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0  | uint256 | undefined |
| _1  | uint256 | undefined |

### GovernanceModified

```solidity
event GovernanceModified(address indexed governance)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| governance `indexed` | address | undefined |

### GovernanceProposed

```solidity
event GovernanceProposed(address indexed governance)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| governance `indexed` | address | undefined |

### Initialized

```solidity
event Initialized(uint8 version)
```



*Triggered when the contract has been initialized or reinitialized.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| version  | uint8 | undefined |

### PoolAdded

```solidity
event PoolAdded(address indexed pool)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| pool `indexed` | address | undefined |

### PoolRemoved

```solidity
event PoolRemoved(address indexed pool)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| pool `indexed` | address | undefined |

### RewardsMinted

```solidity
event RewardsMinted(uint256 amount, uint256 actualAmount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| amount  | uint256 | undefined |
| actualAmount  | uint256 | undefined |

### SetBufferPercent

```solidity
event SetBufferPercent(uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0  | uint256 | undefined |

### SharesBurnt

```solidity
event SharesBurnt(address indexed account, uint256 tokenAmount, uint256 sharesAmount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| account `indexed` | address | undefined |
| tokenAmount  | uint256 | undefined |
| sharesAmount  | uint256 | undefined |

### SharesMinted

```solidity
event SharesMinted(address indexed account, uint256 tokenAmount, uint256 sharesAmount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| account `indexed` | address | undefined |
| tokenAmount  | uint256 | undefined |
| sharesAmount  | uint256 | undefined |

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

### TransferShares

```solidity
event TransferShares(address indexed from, address indexed to, uint256 sharesValue)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| from `indexed` | address | undefined |
| to `indexed` | address | undefined |
| sharesValue  | uint256 | undefined |



## Errors

### InsufficientAllowance

```solidity
error InsufficientAllowance(uint256 currentAllowance, uint256 amount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| currentAllowance | uint256 | undefined |
| amount | uint256 | undefined |

### InsufficientBalance

```solidity
error InsufficientBalance(uint256 currentBalance, uint256 amount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| currentBalance | uint256 | undefined |
| amount | uint256 | undefined |


