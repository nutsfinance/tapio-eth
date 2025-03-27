# ILPToken

**Inherits:** IERC20

**Author:** Nuts Finance Developer

Interface for LP Token

## Functions

### addPool

_Add a pool to the list of pools_

```solidity
function addPool(address _pool) external;
```

### removePool

_Remove a pool from the list of pools_

```solidity
function removePool(address _pool) external;
```

### increaseAllowance

_Increase the allowance of the spender_

```solidity
function increaseAllowance(address _spender, uint256 _addedValue) external returns (bool);
```

### decreaseAllowance

_Decrease the allowance of the spender_

```solidity
function decreaseAllowance(address _spender, uint256 _subtractedValue) external returns (bool);
```

### addTotalSupply

_Add the amount to the total supply_

```solidity
function addTotalSupply(uint256 _amount) external;
```

### removeTotalSupply

_Remove the amount from the total supply_

```solidity
function removeTotalSupply(uint256 _amount) external;
```

### transferShares

_Transfer the shares to the recipient_

```solidity
function transferShares(address _recipient, uint256 _sharesAmount) external returns (uint256);
```

### transferSharesFrom

_Transfer the shares from the sender to the recipient_

```solidity
function transferSharesFrom(address _sender, address _recipient, uint256 _sharesAmount) external returns (uint256);
```

### mintShares

_Mint the shares to the account_

```solidity
function mintShares(address _account, uint256 _sharesAmount) external;
```

### burnShares

_Burn the shares from the account_

```solidity
function burnShares(uint256 _sharesAmount) external;
```

### burnSharesFrom

_Burn the shares from the account_

```solidity
function burnSharesFrom(address _account, uint256 _sharesAmount) external;
```

### addBuffer

```solidity
function addBuffer(uint256 _amount) external;
```

### totalShares

_Get the total amount of shares_

```solidity
function totalShares() external view returns (uint256);
```

### totalRewards

_Get the total amount of rewards_

```solidity
function totalRewards() external view returns (uint256);
```

### sharesOf

_Get the total shares of the account_

```solidity
function sharesOf(address _account) external view returns (uint256);
```

### getSharesByPeggedToken

_Get the shares corresponding to the amount of pooled eth_

```solidity
function getSharesByPeggedToken(uint256 _ethAmount) external view returns (uint256);
```

### getPeggedTokenByShares

_Add the amount of Eth corresponding to the shares_

```solidity
function getPeggedTokenByShares(uint256 _sharesAmount) external view returns (uint256);
```
