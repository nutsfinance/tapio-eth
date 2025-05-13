# SelfPeggingAsset

**Inherits:** Initializable, ReentrancyGuardUpgradeable, OwnableUpgradeable

**Author:** Nuts Finance Developer

The SelfPeggingAsset pool provides a way to swap between different tokens

_The SelfPeggingAsset contract allows users to trade between different tokens, with prices determined algorithmically
based on the current supply and demand of each token_

## State Variables

### FEE_DENOMINATOR

_This is the denominator used for calculating transaction fees in the SelfPeggingAsset contract._

```solidity
uint256 private constant FEE_DENOMINATOR = 10 ** 10;
```

### DEFAULT_FEE_ERROR_MARGIN

_This is the maximum error margin for calculating transaction fees in the SelfPeggingAsset contract._

```solidity
uint256 private constant DEFAULT_FEE_ERROR_MARGIN = 100_000;
```

### DEFAULT_YIELD_ERROR_MARGIN

_This is the maximum error margin for calculating transaction yield in the SelfPeggingAsset contract._

```solidity
uint256 private constant DEFAULT_YIELD_ERROR_MARGIN = 10_000;
```

### DEFAULT_MAX_DELTA_D

_This is the maximum error margin for updating A in the SelfPeggingAsset contract._

```solidity
uint256 private constant DEFAULT_MAX_DELTA_D = 100_000;
```

### MAX_A

_This is the maximum value of the amplification coefficient A._

```solidity
uint256 private constant MAX_A = 10 ** 6;
```

### INITIAL_MINT_MIN

_This is minimum initial mint_

```solidity
uint256 private constant INITIAL_MINT_MIN = 100_000;
```

### tokens

_This is an array of addresses representing the tokens currently supported by the SelfPeggingAsset contract._

```solidity
address[] public tokens;
```

### precisions

_This is an array of uint256 values representing the precisions of each token in the SelfPeggingAsset contract. The
precision of each token is calculated as 10 \*\* (18 - token decimals)._

```solidity
uint256[] public precisions;
```

### balances

_This is an array of uint256 values representing the current balances of each token in the SelfPeggingAsset contract.
The balances are converted to the standard token unit (10 \*\* 18)._

```solidity
uint256[] public balances;
```

### mintFee

_This is the fee charged for adding liquidity to the SelfPeggingAsset contract._

```solidity
uint256 public mintFee;
```

### swapFee

_This is the fee charged for trading assets in the SelfPeggingAsset contract. swapFee = swapFee _ FEE_DENOMINATOR\*

```solidity
uint256 public swapFee;
```

### redeemFee

_This is the fee charged for removing liquidity from the SelfPeggingAsset contract. redeemFee = redeemFee _
FEE_DENOMINATOR\*

```solidity
uint256 public redeemFee;
```

### poolToken

_This is the address of the ERC20 token contract that represents the SelfPeggingAsset pool token._

```solidity
ILPToken public poolToken;
```

### totalSupply

_The total supply of pool token minted by the swap. It might be different from the pool token supply as the pool token
can have multiple minters._

```solidity
uint256 public totalSupply;
```

### admins

_This is a mapping of accounts that have administrative privileges over the SelfPeggingAsset contract._

```solidity
mapping(address => bool) public admins;
```

### paused

_This is a state variable that represents whether or not the SelfPeggingAsset contract is currently paused._

```solidity
bool public paused;
```

### A

_These is a state variables that represents the amplification coefficient A._

```solidity
uint256 public A;
```

### exchangeRateProviders

_Exchange rate provider for the tokens_

```solidity
IExchangeRateProvider[] public exchangeRateProviders;
```

### feeErrorMargin

_Fee error margin._

```solidity
uint256 public feeErrorMargin;
```

### yieldErrorMargin

_Yield error margin._

```solidity
uint256 public yieldErrorMargin;
```

### maxDeltaD

_Max delta D._

```solidity
uint256 public maxDeltaD;
```

## Functions

### initialize

_Initializes the SelfPeggingAsset contract with the given parameters._

```solidity
function initialize(
    address[] memory _tokens,
    uint256[] memory _precisions,
    uint256[] memory _fees,
    ILPToken _poolToken,
    uint256 _A,
    IExchangeRateProvider[] memory _exchangeRateProviders
)
    public
    initializer;
```

**Parameters**

| Name                     | Type                      | Description                                                        |
| ------------------------ | ------------------------- | ------------------------------------------------------------------ |
| `_tokens`                | `address[]`               | The tokens in the pool.                                            |
| `_precisions`            | `uint256[]`               | The precisions of each token (10 \*\* (18 - token decimals)).      |
| `_fees`                  | `uint256[]`               | The fees for minting, swapping, and redeeming.                     |
| `_poolToken`             | `ILPToken`                | The address of the pool token.                                     |
| `_A`                     | `uint256`                 | The initial value of the amplification coefficient A for the pool. |
| `_exchangeRateProviders` | `IExchangeRateProvider[]` |                                                                    |

### mint

_Mints new pool token._

```solidity
function mint(uint256[] calldata _amounts, uint256 _minMintAmount) external nonReentrant returns (uint256);
```

**Parameters**

| Name             | Type        | Description                                         |
| ---------------- | ----------- | --------------------------------------------------- |
| `_amounts`       | `uint256[]` | Unconverted token balances used to mint pool token. |
| `_minMintAmount` | `uint256`   | Minimum amount of pool token to mint.               |

**Returns**

| Name     | Type      | Description                       |
| -------- | --------- | --------------------------------- |
| `<none>` | `uint256` | The amount of pool tokens minted. |

### swap

_Exchange between two underlying tokens._

```solidity
function swap(uint256 _i, uint256 _j, uint256 _dx, uint256 _minDy) external nonReentrant returns (uint256);
```

**Parameters**

| Name     | Type      | Description                                         |
| -------- | --------- | --------------------------------------------------- |
| `_i`     | `uint256` | Token index to swap in.                             |
| `_j`     | `uint256` | Token index to swap out.                            |
| `_dx`    | `uint256` | Unconverted amount of token \_i to swap in.         |
| `_minDy` | `uint256` | Minimum token \_j to swap out in converted balance. |

**Returns**

| Name     | Type      | Description         |
| -------- | --------- | ------------------- |
| `<none>` | `uint256` | Amount of swap out. |

### redeemProportion

_Redeems pool token to underlying tokens proportionally._

```solidity
function redeemProportion(
    uint256 _amount,
    uint256[] calldata _minRedeemAmounts
)
    external
    nonReentrant
    returns (uint256[] memory);
```

**Parameters**

| Name                | Type        | Description                                 |
| ------------------- | ----------- | ------------------------------------------- |
| `_amount`           | `uint256`   | Amount of pool token to redeem.             |
| `_minRedeemAmounts` | `uint256[]` | Minimum amount of underlying tokens to get. |

**Returns**

| Name     | Type        | Description                                      |
| -------- | ----------- | ------------------------------------------------ |
| `<none>` | `uint256[]` | An array of the amounts of each token to redeem. |

### redeemSingle

_Redeem pool token to one specific underlying token._

```solidity
function redeemSingle(uint256 _amount, uint256 _i, uint256 _minRedeemAmount) external nonReentrant returns (uint256);
```

**Parameters**

| Name               | Type      | Description                                          |
| ------------------ | --------- | ---------------------------------------------------- |
| `_amount`          | `uint256` | Amount of pool token to redeem.                      |
| `_i`               | `uint256` | Index of the token to redeem to.                     |
| `_minRedeemAmount` | `uint256` | Minimum amount of the underlying token to redeem to. |

**Returns**

| Name     | Type      | Description      |
| -------- | --------- | ---------------- |
| `<none>` | `uint256` | Amount received. |

### redeemMulti

_Redeems underlying tokens._

```solidity
function redeemMulti(
    uint256[] calldata _amounts,
    uint256 _maxRedeemAmount
)
    external
    nonReentrant
    returns (uint256[] memory);
```

**Parameters**

| Name               | Type        | Description                                |
| ------------------ | ----------- | ------------------------------------------ |
| `_amounts`         | `uint256[]` | Amounts of underlying tokens to redeem to. |
| `_maxRedeemAmount` | `uint256`   | Maximum of pool token to redeem.           |

**Returns**

| Name     | Type        | Description       |
| -------- | ----------- | ----------------- |
| `<none>` | `uint256[]` | Amounts received. |

### setMintFee

_Updates the mint fee._

```solidity
function setMintFee(uint256 _mintFee) external onlyOwner;
```

**Parameters**

| Name       | Type      | Description       |
| ---------- | --------- | ----------------- |
| `_mintFee` | `uint256` | The new mint fee. |

### setSwapFee

_Updates the swap fee._

```solidity
function setSwapFee(uint256 _swapFee) external onlyOwner;
```

**Parameters**

| Name       | Type      | Description       |
| ---------- | --------- | ----------------- |
| `_swapFee` | `uint256` | The new swap fee. |

### setRedeemFee

_Updates the redeem fee._

```solidity
function setRedeemFee(uint256 _redeemFee) external onlyOwner;
```

**Parameters**

| Name         | Type      | Description         |
| ------------ | --------- | ------------------- |
| `_redeemFee` | `uint256` | The new redeem fee. |

### pause

_Pause mint/swap/redeem actions. Can unpause later._

```solidity
function pause() external;
```

### unpause

_Unpause mint/swap/redeem actions._

```solidity
function unpause() external;
```

### setAdmin

_Updates the admin role for the address._

```solidity
function setAdmin(address _account, bool _allowed) external onlyOwner;
```

**Parameters**

| Name       | Type      | Description                                    |
| ---------- | --------- | ---------------------------------------------- |
| `_account` | `address` | Address to update admin role.                  |
| `_allowed` | `bool`    | Whether the address is granted the admin role. |

### updateA

_Update the A value._

```solidity
function updateA(uint256 _A) external onlyOwner;
```

**Parameters**

| Name | Type      | Description      |
| ---- | --------- | ---------------- |
| `_A` | `uint256` | The new A value. |

### donateD

_Update the exchange rate provider for the token._

```solidity
function donateD(uint256[] calldata _amounts, uint256 _minDonationAmount) external nonReentrant returns (uint256);
```

### updateFeeErrorMargin

_update fee error margin._

```solidity
function updateFeeErrorMargin(uint256 newValue) external onlyOwner;
```

### updateYieldErrorMargin

_update yield error margin._

```solidity
function updateYieldErrorMargin(uint256 newValue) external onlyOwner;
```

### updateMaxDeltaDMargin

_update yield error margin._

```solidity
function updateMaxDeltaDMargin(uint256 newValue) external onlyOwner;
```

### distributeLoss

_Distribute losses_

```solidity
function distributeLoss() external onlyOwner;
```

### rebase

This function allows to rebase LPToken by increasing his total supply from the current stableSwap pool by the staking
rewards and the swap fee.

```solidity
function rebase() external returns (uint256);
```

### getRedeemSingleAmount

_Computes the amount when redeeming pool token to one specific underlying token._

```solidity
function getRedeemSingleAmount(uint256 _amount, uint256 _i) external view returns (uint256, uint256);
```

**Parameters**

| Name      | Type      | Description                                 |
| --------- | --------- | ------------------------------------------- |
| `_amount` | `uint256` | Amount of pool token to redeem.             |
| `_i`      | `uint256` | Index of the underlying token to redeem to. |

**Returns**

| Name     | Type      | Description                                          |
| -------- | --------- | ---------------------------------------------------- |
| `<none>` | `uint256` | The amount of single token that will be redeemed.    |
| `<none>` | `uint256` | The amount of pool token charged for redemption fee. |

### getRedeemMultiAmount

_Compute the amount of pool token that needs to be redeemed._

```solidity
function getRedeemMultiAmount(uint256[] calldata _amounts) external view returns (uint256, uint256);
```

**Parameters**

| Name       | Type        | Description                 |
| ---------- | ----------- | --------------------------- |
| `_amounts` | `uint256[]` | Unconverted token balances. |

**Returns**

| Name     | Type      | Description                                          |
| -------- | --------- | ---------------------------------------------------- |
| `<none>` | `uint256` | The amount of pool token that needs to be redeemed.  |
| `<none>` | `uint256` | The amount of pool token charged for redemption fee. |

### getMintAmount

_Compute the amount of pool token that can be minted._

```solidity
function getMintAmount(uint256[] calldata _amounts) external view returns (uint256, uint256);
```

**Parameters**

| Name       | Type        | Description                 |
| ---------- | ----------- | --------------------------- |
| `_amounts` | `uint256[]` | Unconverted token balances. |

**Returns**

| Name     | Type      | Description                             |
| -------- | --------- | --------------------------------------- |
| `<none>` | `uint256` | The amount of pool tokens to be minted. |
| `<none>` | `uint256` | The amount of fees charged.             |

### getSwapAmount

_Computes the output amount after the swap._

```solidity
function getSwapAmount(uint256 _i, uint256 _j, uint256 _dx) external view returns (uint256, uint256);
```

**Parameters**

| Name  | Type      | Description                                 |
| ----- | --------- | ------------------------------------------- |
| `_i`  | `uint256` | Token index to swap in.                     |
| `_j`  | `uint256` | Token index to swap out.                    |
| `_dx` | `uint256` | Unconverted amount of token \_i to swap in. |

**Returns**

| Name     | Type      | Description                                  |
| -------- | --------- | -------------------------------------------- |
| `<none>` | `uint256` | Unconverted amount of token \_j to swap out. |
| `<none>` | `uint256` | The amount of fees charged.                  |

### getRedeemProportionAmount

_Computes the amounts of underlying tokens when redeeming pool token._

```solidity
function getRedeemProportionAmount(uint256 _amount) external view returns (uint256[] memory, uint256);
```

**Parameters**

| Name      | Type      | Description                      |
| --------- | --------- | -------------------------------- |
| `_amount` | `uint256` | Amount of pool tokens to redeem. |

**Returns**

| Name     | Type        | Description                                      |
| -------- | ----------- | ------------------------------------------------ |
| `<none>` | `uint256[]` | An array of the amounts of each token to redeem. |
| `<none>` | `uint256`   | The amount of fee charged                        |

### getTokens

_Returns the array of token addresses in the pool._

```solidity
function getTokens() external view returns (address[] memory);
```

### collectFeeOrYield

_Collect fee or yield based on the token balance difference._

```solidity
function collectFeeOrYield(bool isFee) internal returns (uint256);
```

**Parameters**

| Name    | Type   | Description                      |
| ------- | ------ | -------------------------------- |
| `isFee` | `bool` | Whether to collect fee or yield. |

**Returns**

| Name     | Type      | Description                           |
| -------- | --------- | ------------------------------------- |
| `<none>` | `uint256` | The amount of fee or yield collected. |

### getPendingYieldAmount

_Return the amount of fee that's not collected._

```solidity
function getPendingYieldAmount() internal view returns (uint256[] memory, uint256);
```

**Returns**

| Name     | Type        | Description                        |
| -------- | ----------- | ---------------------------------- |
| `<none>` | `uint256[]` | The balances of underlying tokens. |
| `<none>` | `uint256`   | The total supply of pool tokens.   |

### \_getD

_Computes D given token balances._

```solidity
function _getD(uint256[] memory _balances) internal view returns (uint256);
```

**Parameters**

| Name        | Type        | Description                       |
| ----------- | ----------- | --------------------------------- |
| `_balances` | `uint256[]` | Normalized balance of each token. |

**Returns**

| Name     | Type      | Description                       |
| -------- | --------- | --------------------------------- |
| `<none>` | `uint256` | D The SelfPeggingAsset invariant. |

### \_getY

_Computes token balance given D._

```solidity
function _getY(uint256[] memory _balances, uint256 _j, uint256 _D) internal view returns (uint256);
```

**Parameters**

| Name        | Type        | Description                                                  |
| ----------- | ----------- | ------------------------------------------------------------ |
| `_balances` | `uint256[]` | Converted balance of each token except token with index \_j. |
| `_j`        | `uint256`   | Index of the token to calculate balance.                     |
| `_D`        | `uint256`   | The target D value.                                          |

**Returns**

| Name     | Type      | Description                                    |
| -------- | --------- | ---------------------------------------------- |
| `<none>` | `uint256` | Converted balance of the token with index \_j. |

## Events

### TokenSwapped

This event is emitted when a token swap occurs.

```solidity
event TokenSwapped(address indexed buyer, uint256 swapAmount, uint256[] amounts, uint256 feeAmount);
```

**Parameters**

| Name         | Type        | Description                                                             |
| ------------ | ----------- | ----------------------------------------------------------------------- |
| `buyer`      | `address`   | is the address of the account that made the swap.                       |
| `swapAmount` | `uint256`   | is the amount of the token swapped by the buyer.                        |
| `amounts`    | `uint256[]` | is an array containing the amounts of each token received by the buyer. |
| `feeAmount`  | `uint256`   | is the amount of transaction fee charged for the swap.                  |

### Minted

This event is emitted when liquidity is added to the SelfPeggingAsset contract.

```solidity
event Minted(address indexed provider, uint256 mintAmount, uint256[] amounts, uint256 feeAmount);
```

**Parameters**

| Name         | Type        | Description                                                                                  |
| ------------ | ----------- | -------------------------------------------------------------------------------------------- |
| `provider`   | `address`   | is the address of the liquidity provider.                                                    |
| `mintAmount` | `uint256`   | is the amount of liquidity tokens minted to the provider in exchange for their contribution. |
| `amounts`    | `uint256[]` | is an array containing the amounts of each token contributed by the provider.                |
| `feeAmount`  | `uint256`   | is the amount of transaction fee charged for the liquidity provision.                        |

### Donated

This event is emitted when liquidity is added to the SelfPeggingAsset contract.

```solidity
event Donated(address indexed provider, uint256 mintAmount, uint256[] amounts);
```

**Parameters**

| Name         | Type        | Description                                                                                  |
| ------------ | ----------- | -------------------------------------------------------------------------------------------- |
| `provider`   | `address`   | is the address of the liquidity provider.                                                    |
| `mintAmount` | `uint256`   | is the amount of liquidity tokens minted to the provider in exchange for their contribution. |
| `amounts`    | `uint256[]` | is an array containing the amounts of each token contributed by the provider.                |

### Redeemed

_This event is emitted when liquidity is removed from the SelfPeggingAsset contract._

```solidity
event Redeemed(address indexed provider, uint256 redeemAmount, uint256[] amounts, uint256 feeAmount);
```

**Parameters**

| Name           | Type        | Description                                                                |
| -------------- | ----------- | -------------------------------------------------------------------------- |
| `provider`     | `address`   | is the address of the liquidity provider.                                  |
| `redeemAmount` | `uint256`   | is the amount of liquidity tokens redeemed by the provider.                |
| `amounts`      | `uint256[]` | is an array containing the amounts of each token received by the provider. |
| `feeAmount`    | `uint256`   | is the amount of transaction fee charged for the liquidity provision.      |

### FeeCollected

_This event is emitted when transaction fees are collected by the SelfPeggingAsset contract._

```solidity
event FeeCollected(uint256 feeAmount, uint256 totalSupply);
```

**Parameters**

| Name          | Type      | Description                      |
| ------------- | --------- | -------------------------------- |
| `feeAmount`   | `uint256` | is the amount of fee collected.  |
| `totalSupply` | `uint256` | is the total supply of LP token. |

### YieldCollected

_This event is emitted when yield is collected by the SelfPeggingAsset contract._

```solidity
event YieldCollected(uint256[] amounts, uint256 feeAmount, uint256 totalSupply);
```

**Parameters**

| Name          | Type        | Description                                                          |
| ------------- | ----------- | -------------------------------------------------------------------- |
| `amounts`     | `uint256[]` | is an array containing the amounts of each token the yield receives. |
| `feeAmount`   | `uint256`   | is the amount of yield collected.                                    |
| `totalSupply` | `uint256`   | is the total supply of LP token.                                     |

### AModified

_This event is emitted when the A parameter is modified._

```solidity
event AModified(uint256 A);
```

**Parameters**

| Name | Type      | Description                          |
| ---- | --------- | ------------------------------------ |
| `A`  | `uint256` | is the new value of the A parameter. |

### MintFeeModified

_This event is emitted when the mint fee is modified._

```solidity
event MintFeeModified(uint256 mintFee);
```

**Parameters**

| Name      | Type      | Description                       |
| --------- | --------- | --------------------------------- |
| `mintFee` | `uint256` | is the new value of the mint fee. |

### SwapFeeModified

_This event is emitted when the swap fee is modified._

```solidity
event SwapFeeModified(uint256 swapFee);
```

**Parameters**

| Name      | Type      | Description                       |
| --------- | --------- | --------------------------------- |
| `swapFee` | `uint256` | is the new value of the swap fee. |

### RedeemFeeModified

_This event is emitted when the redeem fee is modified._

```solidity
event RedeemFeeModified(uint256 redeemFee);
```

**Parameters**

| Name        | Type      | Description                         |
| ----------- | --------- | ----------------------------------- |
| `redeemFee` | `uint256` | is the new value of the redeem fee. |

### FeeMarginModified

_This event is emitted when the fee margin is modified._

```solidity
event FeeMarginModified(uint256 margin);
```

**Parameters**

| Name     | Type      | Description                     |
| -------- | --------- | ------------------------------- |
| `margin` | `uint256` | is the new value of the margin. |

### YieldMarginModified

_This event is emitted when the fee margin is modified._

```solidity
event YieldMarginModified(uint256 margin);
```

**Parameters**

| Name     | Type      | Description                     |
| -------- | --------- | ------------------------------- |
| `margin` | `uint256` | is the new value of the margin. |

### MaxDeltaDModified

_This event is emitted when the max delta D is modified._

```solidity
event MaxDeltaDModified(uint256 delta);
```

**Parameters**

| Name    | Type      | Description                    |
| ------- | --------- | ------------------------------ |
| `delta` | `uint256` | is the new value of the delta. |

## Errors

### InputMismatch

Error thrown when the input parameters do not match the expected values.

```solidity
error InputMismatch();
```

### NoFees

Error thrown when fees are not set

```solidity
error NoFees();
```

### FeePercentageTooLarge

Error thrown when the fee percentage is too large.

```solidity
error FeePercentageTooLarge();
```

### TokenNotSet

Error thrown when the token address is not set.

```solidity
error TokenNotSet();
```

### ExchangeRateProviderNotSet

Error thrown when the exchange rate provider is not set.

```solidity
error ExchangeRateProviderNotSet();
```

### PrecisionNotSet

Error thrown when the precision is not set.

```solidity
error PrecisionNotSet();
```

### DuplicateToken

Error thrown when the tokens are duplicates.

```solidity
error DuplicateToken();
```

### PoolTokenNotSet

Error thrown when the pool token is not set.

```solidity
error PoolTokenNotSet();
```

### ANotSet

Error thrown when the A value is not set.

```solidity
error ANotSet();
```

### InvalidAmount

Error thrown when the amount is invalid.

```solidity
error InvalidAmount();
```

### Paused

Error thrown when the pool is paused.

```solidity
error Paused();
```

### ZeroAmount

Error thrown when the amount is zero.

```solidity
error ZeroAmount();
```

### SameToken

Error thrown when the token is the same.

```solidity
error SameToken();
```

### InvalidIn

Error thrown when the input token is invalid.

```solidity
error InvalidIn();
```

### InvalidOut

Error thrown when the output token is invalid.

```solidity
error InvalidOut();
```

### InvalidMins

Error thrown when the amount is invalid.

```solidity
error InvalidMins();
```

### InvalidToken

Error thrown when the token is invalid.

```solidity
error InvalidToken();
```

### LimitExceeded

Error thrown when the limit is exceeded.

```solidity
error LimitExceeded();
```

### NotPaused

Error thrown when the pool is not paused.

```solidity
error NotPaused();
```

### AccountIsZero

Error thrown when the account address is zero

```solidity
error AccountIsZero();
```

### PastBlock

Error thrown when the block number is an past block

```solidity
error PastBlock();
```

### PoolImbalanced

Error thrown when the pool is imbalanced

```solidity
error PoolImbalanced();
```

### NoLosses

Error thrown when there is no loss

```solidity
error NoLosses();
```

### NotAdmin

Error thrown when the account is not an admin

```solidity
error NotAdmin();
```

### InsufficientDonationAmount

Error thrown donation amount is insufficient

```solidity
error InsufficientDonationAmount();
```

### InsufficientMintAmount

Error thrown insufficient mint amount

```solidity
error InsufficientMintAmount(uint256 mintAmount, uint256 minMintAmount);
```

### InsufficientSwapOutAmount

Error thrown insufficient swap out amount

```solidity
error InsufficientSwapOutAmount(uint256 outAmount, uint256 minOutAmount);
```

### InsufficientRedeemAmount

Error thrown insufficient redeem amount

```solidity
error InsufficientRedeemAmount(uint256 redeemAmount, uint256 minRedeemAmount);
```

### MaxRedeemAmount

Error thrown when redeem amount is max

```solidity
error MaxRedeemAmount(uint256 redeemAmount, uint256 maxRedeemAmount);
```

### SameTokenInTokenOut

Error thrown in and out token are the same

```solidity
error SameTokenInTokenOut(uint256 tokenInIndex, uint256 tokenOutIndex);
```

### ImbalancedPool

Error thrown when the pool is imbalanced

```solidity
error ImbalancedPool(uint256 oldD, uint256 newD);
```
