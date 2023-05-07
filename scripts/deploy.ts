import { ethers, upgrades } from "hardhat";

const PRECISION = '1';
const MINT_FEE = '10000000';
const SWAP_FEE = '20000000';
const REDEEM_FEE = '50000000';
const FEE_DENOMITOR = '10000000000';

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(deployer.address);
  const MockToken = await ethers.getContractFactory("MockToken");
  const MockTokenWithExchangeRate = await ethers.getContractFactory("MockExchangeRateProvider");
  const TokensWithExchangeRate = await ethers.getContractFactory("TokensWithExchangeRate");

  const cbETH = await MockToken.deploy("Coinbase ETH", "cbETH", 18);
  console.log("cbETH deployed 1");
  const exchangeRate = await MockTokenWithExchangeRate.deploy("1000000000000000000");
  console.log("cbETH deployed 2");
  const exchangeRateToken = await upgrades.deployProxy(TokensWithExchangeRate, [cbETH.address, exchangeRate.address, '18']);
  console.log("cbETH deployed 3");
  const StableAssetToken = await ethers.getContractFactory("StableAssetToken");
  console.log("cbETH deployed 4");
  const StableAsset = await ethers.getContractFactory("StableAsset");
  console.log("cbETH deployed 5");

  console.log("cbETH deployed");
  console.log(`cbETH: ${cbETH.address}`);
  console.log(`exchangeRate: ${exchangeRate.address}`);
  console.log(`exchangeRateToken: ${exchangeRateToken.address}`);

  const wETHAddress = '0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6';
  const stETHAddress = '0x1643E812aE58766192Cf7D2Cf9567dF2C37e9B7F';
  const feeAddress = '0x3a4ABb0eE1dE2aCcDFE14b80B4DEe78F983b3dcF';
  const yieldAddress = '0xDeEc86988C66618e574ed1eFF2C5CA5745d2916d';

  const poolToken = await upgrades.deployProxy(StableAssetToken, ["tapio ETH", "tapioETH"]);
  console.log("poolToken deployed");
  console.log(`poolToken: ${poolToken.address}`);

  const stETHSwap = await upgrades.deployProxy(StableAsset, [[wETHAddress, stETHAddress], [PRECISION, PRECISION], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeAddress, yieldAddress, poolToken.address, 100]);
  const cbETHSwap = await upgrades.deployProxy(StableAsset, [[wETHAddress, exchangeRateToken.address], [PRECISION, PRECISION], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeAddress, yieldAddress, poolToken.address, 100]);
  console.log(`stETHSwap: ${stETHSwap.address}`);
  console.log(`cbETHSwap: ${cbETHSwap.address}`);
  
  await poolToken.setMinter(stETHSwap.address, true);
  await stETHSwap.approve(wETHAddress, stETHSwap.address);
  await stETHSwap.approve(stETHAddress, stETHSwap.address);

  await poolToken.setMinter(cbETHSwap.address, true);
  await cbETHSwap.approve(wETHAddress, cbETHSwap.address);
  await cbETHSwap.approve(cbETH.address, cbETHSwap.address);
  await cbETHSwap.approve(wETHAddress, exchangeRateToken.address);
  await cbETHSwap.approve(cbETH.address, exchangeRateToken.address);

  console.log("Approval compelted");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
