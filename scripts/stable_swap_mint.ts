import { ethers, upgrades } from "hardhat";

const PRECISION = '1';
const MINT_FEE = '10000000';
const SWAP_FEE = '20000000';
const REDEEM_FEE = '50000000';
const FEE_DENOMITOR = '10000000000';

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(deployer.address);
  const StableAsset = await ethers.getContractFactory("StableAsset");
  const MockToken = await ethers.getContractFactory("MockToken");
  const cbETHSwap = await StableAsset.attach('0xd22f46Ba0425066159F828EFA5fFEab4DAeb9fd0');
  const cbETH = await MockToken.attach('0x1643E812aE58766192Cf7D2Cf9567dF2C37e9B7F');
  const wETH = await MockToken.attach('0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6');
  await wETH.approve(cbETHSwap.address, '1000000000000000000000000');
  await cbETH.approve('0xd22f46Ba0425066159F828EFA5fFEab4DAeb9fd0', '1000000000000000000000000');
  let txn2 = await cbETHSwap.mint(['1000000000000000', '1000000000000000'], 0);
  console.log(txn2.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
