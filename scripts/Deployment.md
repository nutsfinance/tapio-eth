# Deployment process 

The deployment process of Tapio core contracts consists of:
- 1)  Deployment of the contract `TapETH`.
- 2)  Deployment of the contract `WtapETH`.
- 3)  Deployment of the contract `StableAsset`.
- 4)  Deployment of the contract `WETH`.
- 5)  Deployment of the contract `StableAssetApplication`.

## Deployment of TapETH

The deployment of TapETH requires:
  - governance address 

## Deployment of WtapETH

The deployment of WtapETH requires:
  - TapETH address

## Deployment of StableAsset

The deployment of StableAsset requires:
  - tokens : array of token pool addresses 
  - precisions: array of token pool precisions 
  -  fees :[MINT_FEE, SWAP_FEE, REDEEM_FEE]
  - TapETH address
  - A
  - exchangeRateProvider address 
  - exchangeRateTokenIndex

## Deployment of WETH

The deployment of WETH doesn't require inputs.
 

## Deployment of StableAssetApplication

The deployment of StableAssetApplication requires:
  - WETH address 


## Setup of Smart Contracts

- Add each stableSwap pool deployed by the contract StableAsset to the contract TapETH:

  TapETH.addPool(stableSwap1.address)
  TapETH.addPool(stableSwap2.address)

- Add each stableSwap pool deployed by the contract StableAsset to the contract StableAssetApplication:

  StableAssetApplication.updatePool(stableSwap1.address, true)
  StableAssetApplication.updatePool(stableSwap2.address, true)
  
  
  