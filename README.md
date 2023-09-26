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
constant: 0x07e70721C1737a9D410bcd038BA7e82e8BC19e2a
rETHRate: 0xf2dD62922B5f0cb2a72dAeda711018d6F56EEb17

poolToken: 0xA33a79c5Efadac7c07693c3ce32Acf9a1Fc5A387

stETHSwap: 0x52543FE4597230ef59fC8C38D3a682Fa2F0fc026
rETHSwap: 0x8589F6Dedae785634f47132193680149d43cfaF3

application: 0x019270711FF6774a14732F850f9A15008F15c05f

wETHAddress: '0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6'
stETHAddress: '0x1643E812aE58766192Cf7D2Cf9567dF2C37e9B7F'
rETHAddress: '0x178e141a0e3b34152f73ff610437a7bf9b83267a'
feeAddress: '0x3a4ABb0eE1dE2aCcDFE14b80B4DEe78F983b3dcF'
yieldAddress: '0xDeEc86988C66618e574ed1eFF2C5CA5745d2916d'

votingToken: 0x8d68692bddED1F7e70cC1B4D4C58be3F9902e86A
votingEscrow: 0x2b4Db8eb1f6792f253633892862D0799f335c129
gaugeRewardController: 0xDbE58df9E141c0407D164899713c76EC541c7229
gaugeController: 0xd56163FFd1C73D94812C995499C79fd0f865C3b5
```

rETH staking website: https://testnet.rocketpool.net/


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
