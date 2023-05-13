# StableAsset

## Contracts docs

When the contract is compiled, the contract document will be automatically generated in the `./docs` directory, and the typechain-types directory will be generated (not added to github for now)

# StableAsset Test

This document contains the test cases for the `StableAsset` contract. 
This section outlines how the test suite should be used most effectively for the tapio-eth repository. The tests were run using the Hardhat framework, version 2.14.0.

## Test Environment

The tests were run using the following environment:

- Node.js version: v18.15.0
- Hardhat version: v2.14.0

### Test Cases

Running the tests

```bash
npm test
```
### Test Doc

**Description:** Generate test documentation based on test code.

```bash
npm run doc
```

## Coverage

**Description:** The goal of code test coverage is 100%. Currently at 95%, still working hard. This is still the most efficient way to test.

```bash
npm run coverage
```
-------------------------------|----------|----------|----------|----------|----------------|
File                           |  % Stmts | % Branch |  % Funcs |  % Lines |Uncovered Lines |
-------------------------------|----------|----------|----------|----------|----------------|
 contracts/                    |    98.38 |    63.84 |     97.3 |    98.24 |                |
  StableSwap.sol               |    98.86 |    64.58 |      100 |    98.85 |288,335,402,403 |
  StableSwapApplication.sol    |    97.44 |    66.67 |      100 |    97.56 |            165 |
  StableSwapToken.sol          |    83.33 |     37.5 |       75 |    77.78 |          49,50 |
 contracts/interfaces/         |      100 |      100 |      100 |      100 |                |
  ITokensWithExchangeRate.sol  |      100 |      100 |      100 |      100 |                |
  IWETH.sol                    |      100 |      100 |      100 |      100 |                |
 contracts/misc/               |      100 |      100 |      100 |      100 |                |
  IERC20MintableBurnable.sol   |      100 |      100 |      100 |      100 |                |
 contracts/mock/               |    76.47 |     62.5 |    69.23 |    84.62 |                |
  MockExchangeRateProvider.sol |      100 |      100 |      100 |      100 |                |
  MockToken.sol                |    33.33 |      100 |       50 |       50 |          25,29 |
  WETH.sol                     |    84.62 |     62.5 |    66.67 |    89.47 |          29,39 |
 contracts/tokens/             |       50 |       50 |    42.86 |       60 |                |
  TokensWithExchangeRate.sol   |       50 |       50 |    42.86 |       60 |... 110,120,121 |
-------------------------------|----------|----------|----------|----------|----------------|
All files                      |    95.56 |    63.33 |    84.21 |    96.13 |                |
-------------------------------|----------|----------|----------|----------|----------------|