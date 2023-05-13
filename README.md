# Stable Asset Project

[![codecov](https://codecov.io/gh/nutsfinance/tapio-eth/branch/main/graph/badge.svg?token=OKBSB0PQTK)](https://codecov.io/gh/nutsfinance/tapio-eth)

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a script that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.ts
```

Goerli Testnet Address:
```
cbETH: 0xc91960dAaf78B817E3a5064A80D7085CD85DfD04
exchangeRate: 0xc4a34caD7c3f6F99f3F1345438b1FE9f05ce3e97
constant: 0x76eff73F0cefA9AD085f60A3b9B5a8D4C07e188c
poolToken: 0xDFfB1823e24A76e5682e988DF9C4bF53bf3299De
stETHSwap: 0xd22f46Ba0425066159F828EFA5fFEab4DAeb9fd0
cbETHSwap: 0x6f07114487BaC63856060f9f1739d66b16DF579b
application: 0x9aabd039fD0bF767Db26293a039998e85Bd31255

wETHAddress: '0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6'
stETHAddress: '0x1643E812aE58766192Cf7D2Cf9567dF2C37e9B7F'
feeAddress: '0x3a4ABb0eE1dE2aCcDFE14b80B4DEe78F983b3dcF'
yieldAddress: '0xDeEc86988C66618e574ed1eFF2C5CA5745d2916d'
```

Public Api for StableAssetApplication: 
```
  /**
   * @dev Mints new pool token and wrap ETH.
   * @param _swap Underlying stable asset address.
   * @param _amounts Unconverted token balances used to mint pool token.
   * @param _minMintAmount Minimum amount of pool token to mint.
   */
  function mint(
      StableAsset _swap,
      uint256[] calldata _amounts,
      uint256 _minMintAmount
    ) external payable nonReentrant

  /**
   * @dev Exchange between two underlying tokens with wrap/unwrap ETH.
   * @param _swap Underlying stable asset address.
   * @param _i Token index to swap in.
   * @param _j Token index to swap out.
   * @param _dx Unconverted amount of token _i to swap in.
   * @param _minDy Minimum token _j to swap out in converted balance.
   */
  function swap(
      StableAsset _swap,
      uint256 _i,
      uint256 _j,
      uint256 _dx,
      uint256 _minDy
    ) external payable nonReentrant

  /**
   * @dev Redeems pool token to underlying tokens proportionally with unwrap ETH.
   * @param _swap Underlying stable asset address. 
   * @param _amount Amount of pool token to redeem.
   * @param _minRedeemAmounts Minimum amount of underlying tokens to get.
   */
  function redeemProportion(
      StableAsset _swap,
      uint256 _amount,
      uint256[] calldata _minRedeemAmounts
    ) external nonReentrant
```

Public Api for StableAsset:
```
  /**
   * @dev Mints new pool token.
   * @param _amounts Unconverted token balances used to mint pool token.
   * @param _minMintAmount Minimum amount of pool token to mint.
   * @return Amount minted
   */
  function mint(
    uint256[] calldata _amounts,
    uint256 _minMintAmount
  ) external nonReentrant returns (uint256)

  /**
   * @dev Exchange between two underlying tokens.
   * @param _i Token index to swap in.
   * @param _j Token index to swap out.
   * @param _dx Unconverted amount of token _i to swap in.
   * @param _minDy Minimum token _j to swap out in converted balance.
   * @return Amount of swap out
   */
  function swap(
    uint256 _i,
    uint256 _j,
    uint256 _dx,
    uint256 _minDy
  ) external nonReentrant returns (uint256)

  /**
   * @dev Redeems pool token to underlying tokens proportionally.
   * @param _amount Amount of pool token to redeem.
   * @param _minRedeemAmounts Minimum amount of underlying tokens to get.
   * @return Amounts received
   */
  function redeemProportion(
    uint256 _amount,
    uint256[] calldata _minRedeemAmounts
  ) external nonReentrant returns (uint256[] memory)

  /**
   * @dev Redeem pool token to one specific underlying token.
   * @param _amount Amount of pool token to redeem.
   * @param _i Index of the token to redeem to.
   * @param _minRedeemAmount Minimum amount of the underlying token to redeem to.
   * @return Amount received
   */
  function redeemSingle(
    uint256 _amount,
    uint256 _i,
    uint256 _minRedeemAmount
  ) external nonReentrant returns (uint256)

  /**
   * @dev Redeems underlying tokens.
   * @param _amounts Amounts of underlying tokens to redeem to.
   * @param _maxRedeemAmount Maximum of pool token to redeem.
   * @return Amounts received
   */
  function redeemMulti(
    uint256[] calldata _amounts,
    uint256 _maxRedeemAmount
  ) external nonReentrant returns (uint256[] memory)
``` 
