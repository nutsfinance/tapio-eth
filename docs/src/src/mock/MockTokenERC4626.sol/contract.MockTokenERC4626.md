# MockTokenERC4626

**Inherits:** ERC20

Mock ERC20 token.

## State Variables

### \_dec

```solidity
uint8 private _dec;
```

## Functions

### constructor

```solidity
constructor(string memory _name, string memory _symbol, uint8 _decimals) ERC20(_name, _symbol);
```

### mint

```solidity
function mint(address account, uint256 amount) public;
```

### burn

```solidity
function burn(address account, uint256 amount) public;
```

### decimals

```solidity
function decimals() public view override returns (uint8);
```

### totalAssets

```solidity
function totalAssets() public view returns (uint256);
```
