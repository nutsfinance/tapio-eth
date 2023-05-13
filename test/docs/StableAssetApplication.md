
## deploySwapAndTokens
- Deploy WETH contract
- Deploy token2 with name "test 2", symbol "T2", decimals 18
- Deploy swap contract with [wETH, token2], [precision, precision], [mint fee, swap fee, redeem fee], fee recipient feeRecipient, yield recipient yieldRecipient, pool token poolToken, A = 100 and ConstantExchangeRate
- Deploy application contract with WETH
- Set minter of pool token to be swap contract

## deploySwapAndTokensExchangeRate
- Set minter of pool token to be swap contract

## deploySwapAndTokensForLst
- Deploy token1 with name "test 1", symbol "T1", decimals 18
- Deploy token2 with name "test 2", symbol "T2", decimals 18
- Deploy pool token with name "Pool Token", symbol "PT", decimals 18
- Deploy swap contract with [wETH, token1], [precision, precision], [mint fee, swap fee, redeem fee], fee recipient feeRecipient, yield recipient yieldRecipient, pool token poolToken, A = 100 and ConstantExchangeRate
- Deploy swap contract with [wETH, token2], [precision, precision], [mint fee, swap fee, redeem fee], fee recipient feeRecipient, yield recipient yieldRecipient, pool token poolToken, A = 100 and ConstantExchangeRate
- Deploy application contract with WETH
- Set minter of pool token to be swapOne contract
- Set minter of pool token to be swapTwo contract

## should mint
- Deploy swap and tokens
- Unpause swap contract
- Mint 100 token2 to user
- Approve application contract to spend 100 token2
- Mint 100 ETH and 100 token2 to swap contract
- Check balance of pool token of user is greater than 0

## should swap with ETH
- Deploy swap and tokens
- Unpause swap contract
- Mint 100 token2 to user
- Approve application contract to spend 100 token2
- Mint 100 ETH and 100 token2 to swap contract
- Swap 1 ETH to token2
- Check balance of token2 of user is greater than 0

## should swap with token
- Deploy swap and tokens
- Unpause swap contract
- Mint 100 token2 to user
- Approve application contract to spend 100 token2
- Mint 100 ETH and 100 token2 to swap contract
- Mint 1 token2 to user
- Approve application contract to spend 1 token2
- Get balance of user before swap
- Swap 1 token2 to ETH
- Get balance of user after swap and check it is greater than before

## should swap with token with exchange rate

## should swap with eth with exchange rate

## should redeem proportion
- Deploy swap and tokens
- Unpause swap contract
- Mint 100 token2 to user
- Approve application contract to spend 100 token2
- Mint 100 ETH and 100 token2 to swap contract
- Mint 1 token2 to user
- Get balance of user before redeem
- Get token2 balance of user before redeem
- Approve application contract to spend 10 pool token
- Redeem 10 pool token
- Get balance of user after redeem and check it is greater than before
- Get token2 balance of user after redeem and check it is greater than before
- Check token2 balance of user is greater than before

## should redeem single eth
- Deploy swap and tokens
- Unpause swap contract
- Mint 100 token2 to user
- Approve application contract to spend 100 token2
- Mint 100 ETH and 100 token2 to swap contract
- Mint 1 token2 to user
- Get balance of user before redeem
- Approve application contract to spend 10 pool token
- Redeem 10 pool token to ETH
- Get balance of user after redeem and check it is greater than before

## should redeem single token
- Deploy swap and tokens
- Unpause swap contract
- Mint 100 token2 to user
- Approve application contract to spend 100 token2
- Mint 100 ETH and 100 token2 to swap contract
- Mint 1 token2 to user
- Approve application contract to spend 10 pool token
- Get balance of user before redeem
- Redeem 10 pool token to token2
- Get balance of user after redeem and check it is greater than before

## should return swap amount cross pool
- Deploy swap and tokens
- Unpause swapTwo contract
- Mint 100 token2 to user
- Approve application contract to spend 100 token2
- Mint 100 ETH and 100 token2 to swap contract
- Unpause swapOne contract
- Mint 100 token1 to user
- Approve application contract to spend 100 token1
- Mint 100 ETH and 100 token1 to swap contract
- Get swap amount cross pool with token1 to token2
- Check amount is greater than 0

## should swap cross pool
- Deploy swap and tokens
- Unpause swapTwo contract
- Mint 100 token2 to user
- Approve application contract to spend 100 token2
- Mint 100 ETH and 100 token2 to swap contract
- Unpause swapOne contract
- Mint 100 token1 to user
- Approve application contract to spend 100 token1
- Mint 100 ETH and 100 token1 to swap contract
- Mint 1 token1 to user
- Approve application contract to spend 1 token1
- Get balance of user before swap
- Swap 1 token1 to token2
- Get balance of user after swap and check it is greater than before
