# Stable Swap Project

[![codecov](https://codecov.io/gh/nutsfinance/tapio-eth/branch/main/graph/badge.svg?token=ERf7EDgafw)](https://codecov.io/gh/nutsfinance/tapio-eth)

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
cbETH: 0xd994DD0FA5D62306BC2E46B96104E7Fda80Afa62
exchangeRate: 0xAE69ED7C5E7469413CF8BCbA760985d15e433f8f
exchangeRateToken: 0x3Ea5a52a985091F37555F842A164BE66eCDF1AD1
poolToken: 0x415165782010CA80690C522DdCff5fEC39d540Ee
stETHSwap: 0xB1138D397802dcD92f1A8F179716ad16Edb88DA1
cbETHSwap: 0x6a589DA7D666A903fBf2c78CBd7D38D378edE593

wETHAddress: '0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6'
stETHAddress: '0x1643E812aE58766192Cf7D2Cf9567dF2C37e9B7F'
feeAddress: '0x3a4ABb0eE1dE2aCcDFE14b80B4DEe78F983b3dcF'
yieldAddress: '0xDeEc86988C66618e574ed1eFF2C5CA5745d2916d'
```

Public Api for StableSwapApplication: 
```
  /**
   * @dev Mints new pool token and wrap ETH.
   * @param _swap Underlying stable swap address.
   * @param _amounts Unconverted token balances used to mint pool token.
   * @param _minMintAmount Minimum amount of pool token to mint.
   */
  function mint(
      StableSwap _swap,
      uint256[] calldata _amounts,
      uint256 _minMintAmount
    ) external payable nonReentrant

  /**
   * @dev Exchange between two underlying tokens with wrap/unwrap ETH.
   * @param _swap Underlying stable swap address.
   * @param _i Token index to swap in.
   * @param _j Token index to swap out.
   * @param _dx Unconverted amount of token _i to swap in.
   * @param _minDy Minimum token _j to swap out in converted balance.
   */
  function swap(
      StableSwap _swap,
      uint256 _i,
      uint256 _j,
      uint256 _dx,
      uint256 _minDy
    ) external payable nonReentrant

  /**
   * @dev Redeems pool token to underlying tokens proportionally with unwrap ETH.
   * @param _swap Underlying stable swap address. 
   * @param _amount Amount of pool token to redeem.
   * @param _minRedeemAmounts Minimum amount of underlying tokens to get.
   */
  function redeemProportion(
      StableSwap _swap,
      uint256 _amount,
      uint256[] calldata _minRedeemAmounts
    ) external nonReentrant
```

Public Api for StableSwap:
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
