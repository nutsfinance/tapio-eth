# WtapETH



> TapETH token wrapper with static balances.



*It&#39;s an ERC20 token that represents the account&#39;s share of the total supply of tapETH tokens. WtapETH token&#39;s balance only changes on transfers, unlike tapETH that is also changed when staking rewards and swap fee are generated. It&#39;s a &quot;power user&quot; token for DeFi protocols which don&#39;t support rebasable tokens. The contract is also a trustless wrapper that accepts tapETH tokens and mints wtapETH in return. Then the user unwraps, the contract burns user&#39;s wtapETH and sends user locked tapETH in return. The contract provides the staking shortcut: user can send ETH with regular transfer and get wtapETH in return. The contract will send ETH to Tapio staking it and wrapping the received tapETH.*

## Methods

### DOMAIN_SEPARATOR

```solidity
function DOMAIN_SEPARATOR() external view returns (bytes32)
```



*See {IERC20Permit-DOMAIN_SEPARATOR}.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### allowance

```solidity
function allowance(address owner, address spender) external view returns (uint256)
```



*See {IERC20-allowance}.*

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



*See {IERC20-approve}. NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on `transferFrom`. This is semantically equivalent to an infinite approval. Requirements: - `spender` cannot be the zero address.*

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



*See {IERC20-balanceOf}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| account | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### decimals

```solidity
function decimals() external view returns (uint8)
```



*Returns the number of decimals used to get its user representation. For example, if `decimals` equals `2`, a balance of `505` tokens should be displayed to a user as `5.05` (`505 / 10 ** 2`). Tokens usually opt for a value of 18, imitating the relationship between Ether and Wei. This is the default value returned by this function, unless it&#39;s overridden. NOTE: This information is only used for _display_ purposes: it in no way affects any of the arithmetic of the contract, including {IERC20-balanceOf} and {IERC20-transfer}.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint8 | undefined |

### decreaseAllowance

```solidity
function decreaseAllowance(address spender, uint256 subtractedValue) external nonpayable returns (bool)
```



*Atomically decreases the allowance granted to `spender` by the caller. This is an alternative to {approve} that can be used as a mitigation for problems described in {IERC20-approve}. Emits an {Approval} event indicating the updated allowance. Requirements: - `spender` cannot be the zero address. - `spender` must have allowance for the caller of at least `subtractedValue`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| spender | address | undefined |
| subtractedValue | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### eip712Domain

```solidity
function eip712Domain() external view returns (bytes1 fields, string name, string version, uint256 chainId, address verifyingContract, bytes32 salt, uint256[] extensions)
```



*See {EIP-5267}. _Available since v4.9._*


#### Returns

| Name | Type | Description |
|---|---|---|
| fields | bytes1 | undefined |
| name | string | undefined |
| version | string | undefined |
| chainId | uint256 | undefined |
| verifyingContract | address | undefined |
| salt | bytes32 | undefined |
| extensions | uint256[] | undefined |

### getTapETHByWtapETH

```solidity
function getTapETHByWtapETH(uint256 _wtapETHAmount) external view returns (uint256)
```

Get amount of tapETH for a given amount of wtapETH



#### Parameters

| Name | Type | Description |
|---|---|---|
| _wtapETHAmount | uint256 | amount of wtapETH |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Amount of tapETH for a given wtapETH amount |

### getWtapETHByTapETH

```solidity
function getWtapETHByTapETH(uint256 _tapETHAmount) external view returns (uint256)
```

Get amount of wtapETH for a given amount of tapETH



#### Parameters

| Name | Type | Description |
|---|---|---|
| _tapETHAmount | uint256 | amount of tapETH |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Amount of wtapETH for a given tapETH amount |

### increaseAllowance

```solidity
function increaseAllowance(address spender, uint256 addedValue) external nonpayable returns (bool)
```



*Atomically increases the allowance granted to `spender` by the caller. This is an alternative to {approve} that can be used as a mitigation for problems described in {IERC20-approve}. Emits an {Approval} event indicating the updated allowance. Requirements: - `spender` cannot be the zero address.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| spender | address | undefined |
| addedValue | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### initialize

```solidity
function initialize(contract ITapETH _tapETH) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _tapETH | contract ITapETH | undefined |

### name

```solidity
function name() external view returns (string)
```



*Returns the name of the token.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### nonces

```solidity
function nonces(address owner) external view returns (uint256)
```



*See {IERC20Permit-nonces}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| owner | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### permit

```solidity
function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external nonpayable
```



*See {IERC20Permit-permit}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| owner | address | undefined |
| spender | address | undefined |
| value | uint256 | undefined |
| deadline | uint256 | undefined |
| v | uint8 | undefined |
| r | bytes32 | undefined |
| s | bytes32 | undefined |

### symbol

```solidity
function symbol() external view returns (string)
```



*Returns the symbol of the token, usually a shorter version of the name.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### tapETH

```solidity
function tapETH() external view returns (contract ITapETH)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract ITapETH | undefined |

### tapETHPerToken

```solidity
function tapETHPerToken() external view returns (uint256)
```

Get amount of tapETH for a one wtapETH




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Amount of tapETH for 1 wstETH |

### tokensPerTapETH

```solidity
function tokensPerTapETH() external view returns (uint256)
```

Get amount of wtapETH for a one tapETH




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Amount of wtapETH for a 1 tapETH |

### totalSupply

```solidity
function totalSupply() external view returns (uint256)
```



*See {IERC20-totalSupply}.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### transfer

```solidity
function transfer(address to, uint256 amount) external nonpayable returns (bool)
```



*See {IERC20-transfer}. Requirements: - `to` cannot be the zero address. - the caller must have a balance of at least `amount`.*

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



*See {IERC20-transferFrom}. Emits an {Approval} event indicating the updated allowance. This is not required by the EIP. See the note at the beginning of {ERC20}. NOTE: Does not update the allowance if the current allowance is the maximum `uint256`. Requirements: - `from` and `to` cannot be the zero address. - `from` must have a balance of at least `amount`. - the caller must have allowance for ``from``&#39;s tokens of at least `amount`.*

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

### unwrap

```solidity
function unwrap(uint256 _wtapETHAmount) external nonpayable returns (uint256)
```

Exchanges wtapETH to tapETH



#### Parameters

| Name | Type | Description |
|---|---|---|
| _wtapETHAmount | uint256 | amount of wtapETH to uwrap in exchange for tapETH |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Amount of tapETH user receives after unwrap |

### wrap

```solidity
function wrap(uint256 _tapETHAmount) external nonpayable returns (uint256)
```

Exchanges tapETH to wtapETH

*Requirements:  - msg.sender must approve at least `_tapETHAmount` tapETH to this    contract.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _tapETHAmount | uint256 | amount of tapETH to wrap in exchange for wtapETH |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Amount of wtapETH user receives after wrap |



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

### EIP712DomainChanged

```solidity
event EIP712DomainChanged()
```



*MAY be emitted to signal that the domain could have changed.*


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



