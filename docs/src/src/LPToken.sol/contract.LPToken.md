# LPToken

**Inherits:** Initializable, OwnableUpgradeable, [ILPToken](/src/interfaces/ILPToken.sol/interface.ILPToken.md)

**Author:** Nuts Finance Developer

ERC20 token minted by the StableSwap pools.

_LPToken is ERC20 rebase token minted by StableSwap pools for liquidity providers. LPToken balances are dynamic and
represent the holder's share in the total amount of lpToken controlled by the protocol. Account shares aren't
normalized, so the contract also stores the sum of all shares to calculate each account's token balance which equals to:
shares[account] _ \_totalSupply / \_totalShares where the \_totalSupply is the total supply of lpToken controlled by the
protocol.\*

## State Variables

### INFINITE_ALLOWANCE

_Constant value representing an infinite allowance._

```solidity
uint256 internal constant INFINITE_ALLOWANCE = ~uint256(0);
```

### BUFFER_DENOMINATOR

_Constant value representing the denominator for the buffer rate._

```solidity
uint256 public constant BUFFER_DENOMINATOR = 10 ** 10;
```

### totalShares

_The total amount of shares._

```solidity
uint256 public totalShares;
```

### totalSupply

_The total supply of lpToken_

```solidity
uint256 public totalSupply;
```

### totalRewards

_The total amount of rewards_

```solidity
uint256 public totalRewards;
```

### shares

_The mapping of account shares._

```solidity
mapping(address => uint256) public shares;
```

### allowances

_The mapping of account allowances._

```solidity
mapping(address => mapping(address => uint256)) public allowances;
```

### pools

_The mapping of pools._

```solidity
mapping(address => bool) public pools;
```

### bufferPercent

_The buffer rate._

```solidity
uint256 public bufferPercent;
```

### bufferAmount

_The buffer amount._

```solidity
uint256 public bufferAmount;
```

### tokenName

_The token name._

```solidity
string internal tokenName;
```

### tokenSymbol

_The token symbol._

```solidity
string internal tokenSymbol;
```

## Functions

### initialize

```solidity
function initialize(string memory _name, string memory _symbol) public initializer;
```

### transferShares

Moves `_sharesAmount` token shares from the caller's account to the `_recipient` account.

_The `_sharesAmount` argument is the amount of shares, not tokens._

```solidity
function transferShares(address _recipient, uint256 _sharesAmount) external returns (uint256);
```

**Returns**

| Name     | Type      | Description                                                                             |
| -------- | --------- | --------------------------------------------------------------------------------------- |
| `<none>` | `uint256` | amount of transferred tokens. Emits a `TransferShares` event. Emits a `Transfer` event. |

### transferSharesFrom

Moves `_sharesAmount` token shares from the `_sender` account to the `_recipient` account.

_The `_sharesAmount` argument is the amount of shares, not tokens._

```solidity
function transferSharesFrom(address _sender, address _recipient, uint256 _sharesAmount) external returns (uint256);
```

**Returns**

| Name     | Type      | Description                                                                                                                                                                                                        |
| -------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `<none>` | `uint256` | amount of transferred tokens. Emits a `TransferShares` event. Emits a `Transfer` event. Requirements: - the caller must have allowance for `_sender`'s tokens of at least `getPeggedTokenByShares(_sharesAmount)`. |

### mintShares

_Mints shares for the `_account` and transfers them to the `_account`._

```solidity
function mintShares(address _account, uint256 _tokenAmount) external;
```

### burnShares

_Burns shares from the `_account`._

```solidity
function burnShares(uint256 _tokenAmount) external;
```

### burnSharesFrom

_Burns shares from the `_account`._

```solidity
function burnSharesFrom(address _account, uint256 _tokenAmount) external;
```

### transfer

Moves `_amount` tokens from the caller's account to the `_recipient`account.

_The `_amount` argument is the amount of tokens, not shares._

```solidity
function transfer(address _recipient, uint256 _amount) external returns (bool);
```

**Returns**

| Name     | Type   | Description                                                                                                           |
| -------- | ------ | --------------------------------------------------------------------------------------------------------------------- |
| `<none>` | `bool` | a boolean value indicating whether the operation succeeded. Emits a `Transfer` event. Emits a `TransferShares` event. |

### approve

Sets `_amount` as the allowance of `_spender` over the caller's tokens.

_The `_amount` argument is the amount of tokens, not shares._

```solidity
function approve(address _spender, uint256 _amount) external returns (bool);
```

**Returns**

| Name     | Type   | Description                                                                            |
| -------- | ------ | -------------------------------------------------------------------------------------- |
| `<none>` | `bool` | a boolean value indicating whether the operation succeeded. Emits an `Approval` event. |

### transferFrom

Moves `_amount` tokens from `_sender` to `_recipient` using the allowance mechanism. `_amount` is then deducted from the
caller's allowance.

_The `_amount` argument is the amount of tokens, not shares._

```solidity
function transferFrom(address _sender, address _recipient, uint256 _amount) external returns (bool);
```

**Returns**

| Name     | Type   | Description                                                                                                                                                                                                                                                                    |
| -------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `<none>` | `bool` | a boolean value indicating whether the operation succeeded. Emits a `Transfer` event. Emits a `TransferShares` event. Emits an `Approval` event indicating the updated allowance. Requirements: - the caller must have allowance for `_sender`'s tokens of at least `_amount`. |

### increaseAllowance

Atomically increases the allowance granted to `_spender` by the caller by `_addedValue`. This is an alternative to
`approve` that can be used as a mitigation for problems described in:
https://github.com/OpenZeppelin/openzeppelin-contracts/blob/b709eae01d1da91902d06ace340df6b324e6f049/contracts/token/ERC20/IERC20.sol#L57
Emits an `Approval` event indicating the updated allowance.

```solidity
function increaseAllowance(address _spender, uint256 _addedValue) external returns (bool);
```

### decreaseAllowance

Atomically decreases the allowance granted to `_spender` by the caller by `_subtractedValue`. This is an alternative to
`approve` that can be used as a mitigation for problems described in:
https://github.com/OpenZeppelin/openzeppelin-contracts/blob/b709eae01d1da91902d06ace340df6b324e6f049/contracts/token/ERC20/IERC20.sol#L57
Emits an `Approval` event indicating the updated allowance.

```solidity
function decreaseAllowance(address _spender, uint256 _subtractedValue) external returns (bool);
```

### setBuffer

This function is called by the owner to set the buffer rate.

```solidity
function setBuffer(uint256 _buffer) external onlyOwner;
```

### setSymbol

This function is called by the owner to set the token symbol.

```solidity
function setSymbol(string memory _symbol) external onlyOwner;
```

### addTotalSupply

This function is called only by a stableSwap pool to increase the total supply of LPToken by the staking rewards and the
swap fee.

```solidity
function addTotalSupply(uint256 _amount) external;
```

### removeTotalSupply

This function is called only by a stableSwap pool to decrease the total supply of LPToken by lost amount.

```solidity
function removeTotalSupply(uint256 _amount) external;
```

### addBuffer

This function is called only by a stableSwap pool to increase the total supply of LPToken

```solidity
function addBuffer(uint256 _amount) external;
```

### addPool

_Adds a pool to the list of pools._

```solidity
function addPool(address _pool) external onlyOwner;
```

**Parameters**

| Name    | Type      | Description                     |
| ------- | --------- | ------------------------------- |
| `_pool` | `address` | The address of the pool to add. |

### removePool

_Removes a pool from the list of pools._

```solidity
function removePool(address _pool) external onlyOwner;
```

**Parameters**

| Name    | Type      | Description                        |
| ------- | --------- | ---------------------------------- |
| `_pool` | `address` | The address of the pool to remove. |

### name

_Returns the name of the token._

```solidity
function name() external view returns (string memory);
```

**Returns**

| Name     | Type     | Description            |
| -------- | -------- | ---------------------- |
| `<none>` | `string` | the name of the token. |

### symbol

_Returns the symbol of the token._

```solidity
function symbol() external view returns (string memory);
```

**Returns**

| Name     | Type     | Description              |
| -------- | -------- | ------------------------ |
| `<none>` | `string` | the symbol of the token. |

### balanceOf

_Balances are dynamic and equal the `_account`'s share in the amount of the total lpToken controlled by the protocol.
See `sharesOf`._

```solidity
function balanceOf(address _account) external view returns (uint256);
```

**Returns**

| Name     | Type      | Description                                   |
| -------- | --------- | --------------------------------------------- |
| `<none>` | `uint256` | the amount of tokens owned by the `_account`. |

### allowance

_This value changes when `approve` or `transferFrom` is called._

```solidity
function allowance(address _owner, address _spender) external view returns (uint256);
```

**Returns**

| Name     | Type      | Description                                                                                                                               |
| -------- | --------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `<none>` | `uint256` | the remaining number of tokens that `_spender` is allowed to spend on behalf of `_owner` through `transferFrom`. This is zero by default. |

### sharesOf

```solidity
function sharesOf(address _account) external view returns (uint256);
```

**Returns**

| Name     | Type      | Description                               |
| -------- | --------- | ----------------------------------------- |
| `<none>` | `uint256` | the amount of shares owned by `_account`. |

### decimals

_Returns the decimals of the token._

```solidity
function decimals() external pure returns (uint8);
```

**Returns**

| Name     | Type    | Description                                                               |
| -------- | ------- | ------------------------------------------------------------------------- |
| `<none>` | `uint8` | the number of decimals for getting user representation of a token amount. |

### getPeggedTokenByShares

```solidity
function getPeggedTokenByShares(uint256 _sharesAmount) public view returns (uint256);
```

**Returns**

| Name     | Type      | Description                                                             |
| -------- | --------- | ----------------------------------------------------------------------- |
| `<none>` | `uint256` | the amount of lpToken that corresponds to `_sharesAmount` token shares. |

### getSharesByPeggedToken

```solidity
function getSharesByPeggedToken(uint256 _lpTokenAmount) public view returns (uint256);
```

**Returns**

| Name     | Type      | Description                                                                            |
| -------- | --------- | -------------------------------------------------------------------------------------- |
| `<none>` | `uint256` | the amount of shares that corresponds to `_lpTokenAmount` protocol-controlled lpToken. |

### \_transfer

Moves `_amount` tokens from `_sender` to `_recipient`. Emits a `Transfer` event. Emits a `TransferShares` event.

```solidity
function _transfer(address _sender, address _recipient, uint256 _amount) internal;
```

### \_approve

Sets `_amount` as the allowance of `_spender` over the `_owner` s tokens. Emits an `Approval` event.

```solidity
function _approve(address _owner, address _spender, uint256 _amount) internal;
```

### \_spendAllowance

_Updates `owner` s allowance for `spender` based on spent `amount`. Does not update the allowance amount in case of
infinite allowance. Revert if not enough allowance is available. Might emit an {Approval} event._

```solidity
function _spendAllowance(address _owner, address _spender, uint256 _amount) internal;
```

### \_transferShares

Moves `_sharesAmount` shares from `_sender` to `_recipient`.

```solidity
function _transferShares(address _sender, address _recipient, uint256 _sharesAmount) internal;
```

### \_mintShares

Creates `_sharesAmount` shares and assigns them to `_recipient`, increasing the total amount of shares.

```solidity
function _mintShares(address _recipient, uint256 _tokenAmount) internal returns (uint256 newTotalShares);
```

### \_burnShares

Destroys `_sharesAmount` shares from `_account`'s holdings, decreasing the total amount of shares.

```solidity
function _burnShares(address _account, uint256 _tokenAmount) internal returns (uint256 newTotalShares);
```

### \_emitTransferEvents

Emits Transfer and TransferShares events.

```solidity
function _emitTransferEvents(address _from, address _to, uint256 _tokenAmount, uint256 _sharesAmount) internal;
```

### \_emitTransferAfterMintingShares

Emits Transfer and TransferShares events after minting shares.

```solidity
function _emitTransferAfterMintingShares(address _to, uint256 _sharesAmount) internal;
```

### \_sharesOf

```solidity
function _sharesOf(address _account) internal view returns (uint256);
```

**Returns**

| Name     | Type      | Description                               |
| -------- | --------- | ----------------------------------------- |
| `<none>` | `uint256` | the amount of shares owned by `_account`. |

## Events

### TransferShares

Emitted when shares are transferred.

```solidity
event TransferShares(address indexed from, address indexed to, uint256 sharesValue);
```

### SharesMinted

Emitted when shares are minted.

```solidity
event SharesMinted(address indexed account, uint256 tokenAmount, uint256 sharesAmount);
```

### SharesBurnt

Emitted when shares are burnt.

```solidity
event SharesBurnt(address indexed account, uint256 tokenAmount, uint256 sharesAmount);
```

### RewardsMinted

Emitted when rewards are minted.

```solidity
event RewardsMinted(uint256 amount, uint256 actualAmount);
```

### PoolAdded

Emitted when a pool is added.

```solidity
event PoolAdded(address indexed pool);
```

### PoolRemoved

Emitted when a pool is removed.

```solidity
event PoolRemoved(address indexed pool);
```

### SetBufferPercent

Emitted when the buffer rate is set.

```solidity
event SetBufferPercent(uint256);
```

### BufferIncreased

Emitted when the buffer is increased.

```solidity
event BufferIncreased(uint256, uint256);
```

### BufferDecreased

Emitted when the buffer is decreased.

```solidity
event BufferDecreased(uint256, uint256);
```

### SymbolModified

Emitted when the symbol is modified.

```solidity
event SymbolModified(string);
```

## Errors

### AllowanceBelowZero

Error thrown when the allowance is below zero.

```solidity
error AllowanceBelowZero();
```

### OutOfRange

Error thrown when array index is out of range.

```solidity
error OutOfRange();
```

### NoPool

Error thrown when the pool is not added.

```solidity
error NoPool();
```

### InvalidAmount

Error thrown when the amount is invalid.

```solidity
error InvalidAmount();
```

### InsufficientBuffer

Error thrown when the buffer is insufficient.

```solidity
error InsufficientBuffer();
```

### ApproveFromZeroAddr

Error thrown when the sender's address is zero.

```solidity
error ApproveFromZeroAddr();
```

### ApproveToZeroAddr

Error thrown when the recipient's address is zero.

```solidity
error ApproveToZeroAddr();
```

### ZeroAddress

Error thrown when the address is zero.

```solidity
error ZeroAddress();
```

### TransferToLPTokenContract

Error thrown when transferring to the lpToken contract.

```solidity
error TransferToLPTokenContract();
```

### MintToZeroAddr

Error thrown when minting to the zero address.

```solidity
error MintToZeroAddr();
```

### BurnFromZeroAddr

Error thrown when burning from the zero address.

```solidity
error BurnFromZeroAddr();
```

### PoolAlreadyAdded

Error thrown when the pool is already added.

```solidity
error PoolAlreadyAdded();
```

### PoolNotFound

Error thrown when the pool is not found.

```solidity
error PoolNotFound();
```
