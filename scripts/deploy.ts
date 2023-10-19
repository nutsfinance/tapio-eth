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

  const TapETH = await ethers.getContractFactory("TapETH");
  const WTapETH = await ethers.getContractFactory("WTapETH");
  const StableAsset = await ethers.getContractFactory("StableAsset");
  const constantAddress = '0x07e70721C1737a9D410bcd038BA7e82e8BC19e2a';
  const rocketRateAddress = '0xf2dD62922B5f0cb2a72dAeda711018d6F56EEb17';

  const poolToken = await upgrades.deployProxy(TapETH, [], {timeout: 600000});
  console.log("poolToken deployed");
  console.log(`poolToken: ${poolToken.address}`);

  const wrappedPoolToken = await upgrades.deployProxy(WTapETH, [poolToken.address], {timeout: 600000});
  console.log("wrapped poolToken deployed");
  console.log(`wrappedPoolToken: ${wrappedPoolToken.address}`);

  const stETHSwap = await upgrades.deployProxy(StableAsset, [[wETHAddress, stETHAddress], [PRECISION, PRECISION], [MINT_FEE, SWAP_FEE, REDEEM_FEE], poolToken.address, INITIAL_A, constantAddress, 1], {timeout: 600000});
  const rETHSwap = await upgrades.deployProxy(StableAsset, [[wETHAddress, rETHAddress], [PRECISION, PRECISION], [MINT_FEE, SWAP_FEE, REDEEM_FEE], poolToken.address, INITIAL_A, rocketRateAddress, 1], {timeout: 600000});
  console.log(`stETHSwap: ${stETHSwap.address}`);
  console.log(`rETHSwap: ${rETHSwap.address}`);
  
  await poolToken.addPool(stETHSwap.address);
  await poolToken.addPool(rETHSwap.address);
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
