import { ethers, upgrades } from "hardhat";

const PRECISION = '1';
const MINT_FEE = '10000000';
const SWAP_FEE = '20000000';
const REDEEM_FEE = '50000000';
const FEE_DENOMITOR = '10000000000';

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(deployer.address);

  const wETHAddress = '0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6';
  const rETHAddress = '0x178e141a0e3b34152f73ff610437a7bf9b83267a';
  const feeAddress = '0x3a4ABb0eE1dE2aCcDFE14b80B4DEe78F983b3dcF';
  const yieldAddress = '0xDeEc86988C66618e574ed1eFF2C5CA5745d2916d';
  const poolTokenAddress = '0xDFfB1823e24A76e5682e988DF9C4bF53bf3299De';
  const exchangeRateProviderAddress = '0x9C3aF1d0b2590d4143AEafF23eF23E6B533fC7c5';

  const StableAssetToken = await ethers.getContractFactory("StableAssetToken");
  const poolToken = StableAssetToken.attach(poolTokenAddress);

  console.log("poolToken deployed");

  const StableAsset = await ethers.getContractFactory("StableAsset");

  const rETHSwap = await upgrades.deployProxy(StableAsset, [[wETHAddress, rETHAddress], [PRECISION, PRECISION], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeAddress, yieldAddress, poolToken.address, 100, exchangeRateProviderAddress, 1]);
  console.log(`stETHSwap: ${rETHSwap.address}`);
  
  await poolToken.setMinter(rETHSwap.address, true);
  await rETHSwap.unpause();
  console.log("Approval compelted");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
