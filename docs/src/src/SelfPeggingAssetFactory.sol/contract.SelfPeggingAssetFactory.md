# SelfPeggingAssetFactory

**Inherits:** UUPSUpgradeable, OwnableUpgradeable

**Author:** Nuts Finance Developer

The StableSwap Application provides an interface for users to interact with StableSwap pool contracts

_The StableSwap Application contract allows users to mint pool tokens, swap between different tokens, and redeem pool
tokens to underlying tokens. This contract should never store assets._

## State Variables

### governor

_This is the account that has governor control over the protocol._

```solidity
address public governor;
```

### mintFee

_Default mint fee for the pool._

```solidity
uint256 public mintFee;
```

### swapFee

_Default swap fee for the pool._

```solidity
uint256 public swapFee;
```

### redeemFee

_Default redeem fee for the pool._

```solidity
uint256 public redeemFee;
```

### A

_Default A parameter for the pool._

```solidity
uint256 public A;
```

### selfPeggingAssetBeacon

_Beacon for the SelfPeggingAsset implementation._

```solidity
address public selfPeggingAssetBeacon;
```

### lpTokenBeacon

_Beacon for the LPToken implementation._

```solidity
address public lpTokenBeacon;
```

### wlpTokenBeacon

_Beacon for the WLPToken implementation._

```solidity
address public wlpTokenBeacon;
```

### constantExchangeRateProvider

_Constant exchange rate provider._

```solidity
ConstantExchangeRateProvider public constantExchangeRateProvider;
```

## Functions

### initialize

_Initializes the StableSwap Application contract._

```solidity
function initialize(
    address _governor,
    uint256 _mintFee,
    uint256 _swapFee,
    uint256 _redeemFee,
    uint256 _A,
    address _selfPeggingAssetBeacon,
    address _lpTokenBeacon,
    address _wlpTokenBeacon,
    ConstantExchangeRateProvider _constantExchangeRateProvider
)
    public
    initializer;
```

### setGovernor

_Set the govenance address._

```solidity
function setGovernor(address _governor) external onlyOwner;
```

### setMintFee

_Set the mint fee._

```solidity
function setMintFee(uint256 _mintFee) external onlyOwner;
```

### setSwapFee

_Set the swap fee._

```solidity
function setSwapFee(uint256 _swapFee) external onlyOwner;
```

### setRedeemFee

_Set the redeem fee._

```solidity
function setRedeemFee(uint256 _redeemFee) external onlyOwner;
```

### setA

_Set the A parameter._

```solidity
function setA(uint256 _A) external onlyOwner;
```

### createPool

_Create a new pool._

```solidity
function createPool(CreatePoolArgument memory argument) external;
```

### \_authorizeUpgrade

_Authorisation to upgrade the implementation of the contract._

```solidity
function _authorizeUpgrade(address) internal override onlyOwner;
```

## Events

### GovernorModified

_This event is emitted when the governor is modified._

```solidity
event GovernorModified(address governor);
```

**Parameters**

| Name       | Type      | Description                       |
| ---------- | --------- | --------------------------------- |
| `governor` | `address` | is the new value of the governor. |

### PoolCreated

_This event is emitted when a new pool is created._

```solidity
event PoolCreated(address poolToken, address selfPeggingAsset, address wrappedPoolToken);
```

**Parameters**

| Name               | Type      | Description                |
| ------------------ | --------- | -------------------------- |
| `poolToken`        | `address` | is the pool token created. |
| `selfPeggingAsset` | `address` |                            |
| `wrappedPoolToken` | `address` |                            |

### MintFeeModified

_This event is emitted when the mint fee is updated._

```solidity
event MintFeeModified(uint256 mintFee);
```

**Parameters**

| Name      | Type      | Description                       |
| --------- | --------- | --------------------------------- |
| `mintFee` | `uint256` | is the new value of the mint fee. |

### SwapFeeModified

_This event is emitted when the swap fee is updated._

```solidity
event SwapFeeModified(uint256 swapFee);
```

**Parameters**

| Name      | Type      | Description                       |
| --------- | --------- | --------------------------------- |
| `swapFee` | `uint256` | is the new value of the swap fee. |

### RedeemFeeModified

_This event is emitted when the redeem fee is updated._

```solidity
event RedeemFeeModified(uint256 redeemFee);
```

**Parameters**

| Name        | Type      | Description                         |
| ----------- | --------- | ----------------------------------- |
| `redeemFee` | `uint256` | is the new value of the redeem fee. |

### AModified

_This event is emitted when the A parameter is updated._

```solidity
event AModified(uint256 A);
```

**Parameters**

| Name | Type      | Description                          |
| ---- | --------- | ------------------------------------ |
| `A`  | `uint256` | is the new value of the A parameter. |

## Errors

### InvalidAddress

_Error thrown when the address is invalid_

```solidity
error InvalidAddress();
```

### InvalidValue

_Error thrown when the value is invalid_

```solidity
error InvalidValue();
```

### InvalidOracle

_Error thrown when the oracle is invalid_

```solidity
error InvalidOracle();
```

### InvalidFunctionSig

_Error thrown when the function signature is invalid_

```solidity
error InvalidFunctionSig();
```

## Structs

### CreatePoolArgument

Parameters for creating a new pool

```solidity
struct CreatePoolArgument {
    address tokenA;
    address tokenB;
    TokenType tokenAType;
    address tokenAOracle;
    string tokenAFunctionSig;
    TokenType tokenBType;
    address tokenBOracle;
    string tokenBFunctionSig;
}
```

## Enums

### TokenType

Token type enum

```solidity
enum TokenType {
    Standard,
    Oracle,
    Rebasing,
    ERC4626
}
```
