import { ethers, upgrades } from "hardhat";

const PRECISION = '1';
const MINT_FEE = '0';
const SWAP_FEE = '3000000';
const REDEEM_FEE = '10000000';
const FEE_DENOMITOR = '10000000000';
const INITIAL_A = '100';

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(deployer.address);

  const wETHAddress = '0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6';
  const stETHAddress = '0x1643E812aE58766192Cf7D2Cf9567dF2C37e9B7F';
  const rETHAddress = '0x178e141a0e3b34152f73ff610437a7bf9b83267a';
  const feeAddress = '0x3a4ABb0eE1dE2aCcDFE14b80B4DEe78F983b3dcF';
  const yieldAddress = '0xDeEc86988C66618e574ed1eFF2C5CA5745d2916d';

  const ConstantExchangeRateProvider = await ethers.getContractFactory("ConstantExchangeRateProvider");
  const StableAssetToken = await ethers.getContractFactory("StableAssetToken");
  const StableAsset = await ethers.getContractFactory("StableAsset");
  const constant = await ConstantExchangeRateProvider.deploy();
  const RocketTokenExchangeRateProvider = await ethers.getContractFactory("RocketTokenExchangeRateProvider");
  const rate = await upgrades.deployProxy(RocketTokenExchangeRateProvider, [rETHAddress]);
  console.log(`constant: ${constant.address}`);
  console.log(`rETH Rate: ${rate.address}`);

  const poolToken = await upgrades.deployProxy(StableAssetToken, ["Tapio Ether", "tapETH"]);
  console.log("poolToken deployed");
  console.log(`poolToken: ${poolToken.address}`);

  const stETHSwap = await upgrades.deployProxy(StableAsset, [[wETHAddress, stETHAddress], [PRECISION, PRECISION], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeAddress, yieldAddress, poolToken.address, INITIAL_A, constant.address, 1]);
  const rETHSwap = await upgrades.deployProxy(StableAsset, [[wETHAddress, rETHAddress], [PRECISION, PRECISION], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeAddress, yieldAddress, poolToken.address, INITIAL_A, rate.address, 1]);
  console.log(`stETHSwap: ${stETHSwap.address}`);
  console.log(`rETHSwap: ${rETHSwap.address}`);
  
  await poolToken.setMinter(stETHSwap.address, true);
  await poolToken.setMinter(rETHSwap.address, true);
  // await stETHSwap.unpause();
  // await cbETHSwap.unpause();
  console.log("Approval compelted");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
