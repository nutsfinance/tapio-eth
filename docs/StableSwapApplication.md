# StableSwapApplication

*Nuts Finance Developer*

> StableSwap Application

The StableSwap Application provides an interface for users to interact with StableSwap pool contracts

*The StableSwap Application contract allows users to mint pool tokens, swap between different tokens, and redeem pool tokens to underlying tokens*

## Methods

### initialize

```solidity
function initialize(contract IWETH _wETH) external nonpayable
```



*Initializes the StableSwap Application contract.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _wETH | contract IWETH | Wrapped ETH address. |

### mint

```solidity
function mint(contract StableSwap _swap, uint256[] _amounts, uint256 _minMintAmount) external payable
```



*Mints new pool token and wrap ETH.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _swap | contract StableSwap | Underlying stable swap address. |
| _amounts | uint256[] | Unconverted token balances used to mint pool token. |
| _minMintAmount | uint256 | Minimum amount of pool token to mint. |

### redeemProportion

```solidity
function redeemProportion(contract StableSwap _swap, uint256 _amount, uint256[] _minRedeemAmounts) external nonpayable
```



*Redeems pool token to underlying tokens proportionally with unwrap ETH.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _swap | contract StableSwap | Underlying stable swap address. |
| _amount | uint256 | Amount of pool token to redeem. |
| _minRedeemAmounts | uint256[] | Minimum amount of underlying tokens to get. |

### swap

```solidity
function swap(contract StableSwap _swap, uint256 _i, uint256 _j, uint256 _dx, uint256 _minDy) external payable
```



*Exchange between two underlying tokens with wrap/unwrap ETH.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _swap | contract StableSwap | Underlying stable swap address. |
| _i | uint256 | Token index to swap in. |
| _j | uint256 | Token index to swap out. |
| _dx | uint256 | Unconverted amount of token _i to swap in. |
| _minDy | uint256 | Minimum token _j to swap out in converted balance. |

### wETH

```solidity
function wETH() external view returns (contract IWETH)
```



*Wrapped ETH address.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IWETH | undefined |



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



