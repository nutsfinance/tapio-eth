# WLPToken

**Inherits:** ERC4626Upgradeable

_It's an ERC4626 standard token that represents the account's share of the total supply of lpToken tokens. WLPToken
token's balance only changes on transfers, unlike lpToken that is also changed when staking rewards and swap fee are
generated. It's a "power user" token for DeFi protocols which don't support rebasable tokens. The contract is also a
trustless wrapper that accepts lpToken tokens and mints wlpToken in return. Then the user unwraps, the contract burns
user's wlpToken and sends user locked lpToken in return._

## State Variables

### lpToken

```solidity
ILPToken public lpToken;
```

## Functions

### initialize

```solidity
function initialize(ILPToken _lpToken) public initializer;
```

### deposit

_Deposits lpToken into the vault in exchange for shares._

```solidity
function deposit(uint256 assets, address receiver) public override returns (uint256 shares);
```

**Parameters**

| Name       | Type      | Description                           |
| ---------- | --------- | ------------------------------------- |
| `assets`   | `uint256` | Amount of lpToken to deposit.         |
| `receiver` | `address` | Address to receive the minted shares. |

**Returns**

| Name     | Type      | Description              |
| -------- | --------- | ------------------------ |
| `shares` | `uint256` | Amount of shares minted. |

### mint

_Mints shares for a given amount of assets deposited._

```solidity
function mint(uint256 shares, address receiver) public override returns (uint256 assets);
```

**Parameters**

| Name       | Type      | Description                           |
| ---------- | --------- | ------------------------------------- |
| `shares`   | `uint256` | Amount of shares to mint.             |
| `receiver` | `address` | Address to receive the minted shares. |

**Returns**

| Name     | Type      | Description                      |
| -------- | --------- | -------------------------------- |
| `assets` | `uint256` | The amount of lpToken deposited. |

### withdraw

_Withdraws lpToken from the vault in exchange for burning shares._

```solidity
function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256 shares);
```

**Parameters**

| Name       | Type      | Description                          |
| ---------- | --------- | ------------------------------------ |
| `assets`   | `uint256` | Amount of lpToken to withdraw.       |
| `receiver` | `address` | Address to receive the lpToken.      |
| `owner`    | `address` | Address whose shares will be burned. |

**Returns**

| Name     | Type      | Description                                          |
| -------- | --------- | ---------------------------------------------------- |
| `shares` | `uint256` | Burned shares corresponding to the assets withdrawn. |

### redeem

_Redeems shares for lpToken._

```solidity
function redeem(uint256 shares, address receiver, address owner) public override returns (uint256 assets);
```

**Parameters**

| Name       | Type      | Description                          |
| ---------- | --------- | ------------------------------------ |
| `shares`   | `uint256` | Amount of shares to redeem.          |
| `receiver` | `address` | Address to receive the lpToken.      |
| `owner`    | `address` | Address whose shares will be burned. |

**Returns**

| Name     | Type      | Description                  |
| -------- | --------- | ---------------------------- |
| `assets` | `uint256` | Amount of lpToken withdrawn. |

### convertToShares

_Converts an amount of lpToken to the equivalent amount of shares._

```solidity
function convertToShares(uint256 assets) public view override returns (uint256);
```

**Parameters**

| Name     | Type      | Description        |
| -------- | --------- | ------------------ |
| `assets` | `uint256` | Amount of lpToken. |

**Returns**

| Name     | Type      | Description            |
| -------- | --------- | ---------------------- |
| `<none>` | `uint256` | The equivalent shares. |

### convertToAssets

_Converts an amount of shares to the equivalent amount of lpToken._

```solidity
function convertToAssets(uint256 shares) public view override returns (uint256);
```

**Parameters**

| Name     | Type      | Description       |
| -------- | --------- | ----------------- |
| `shares` | `uint256` | Amount of shares. |

**Returns**

| Name     | Type      | Description             |
| -------- | --------- | ----------------------- |
| `<none>` | `uint256` | The equivalent lpToken. |

### maxWithdraw

_Returns the maximum amount of assets that can be withdrawn by `owner`._

```solidity
function maxWithdraw(address owner) public view override returns (uint256);
```

**Parameters**

| Name    | Type      | Description             |
| ------- | --------- | ----------------------- |
| `owner` | `address` | Address of the account. |

**Returns**

| Name     | Type      | Description                                          |
| -------- | --------- | ---------------------------------------------------- |
| `<none>` | `uint256` | The maximum amount of lpToken that can be withdrawn. |

### previewDeposit

_Simulates the amount of shares that would be minted for a given amount of assets._

```solidity
function previewDeposit(uint256 assets) public view override returns (uint256);
```

**Parameters**

| Name     | Type      | Description                   |
| -------- | --------- | ----------------------------- |
| `assets` | `uint256` | Amount of lpToken to deposit. |

**Returns**

| Name     | Type      | Description                                |
| -------- | --------- | ------------------------------------------ |
| `<none>` | `uint256` | The number of shares that would be minted. |

### previewMint

_Simulates the amount of assets that would be needed to mint a given amount of shares._

```solidity
function previewMint(uint256 shares) public view override returns (uint256);
```

**Parameters**

| Name     | Type      | Description               |
| -------- | --------- | ------------------------- |
| `shares` | `uint256` | Amount of shares to mint. |

**Returns**

| Name     | Type      | Description                    |
| -------- | --------- | ------------------------------ |
| `<none>` | `uint256` | The number of assets required. |

### previewRedeem

_Simulates the amount of assets that would be withdrawn for a given amount of shares._

```solidity
function previewRedeem(uint256 shares) public view override returns (uint256);
```

**Parameters**

| Name     | Type      | Description                 |
| -------- | --------- | --------------------------- |
| `shares` | `uint256` | Amount of shares to redeem. |

**Returns**

| Name     | Type      | Description                                   |
| -------- | --------- | --------------------------------------------- |
| `<none>` | `uint256` | The number of assets that would be withdrawn. |

## Errors

### ZeroAmount

```solidity
error ZeroAmount();
```

### InsufficientAllowance

```solidity
error InsufficientAllowance();
```
