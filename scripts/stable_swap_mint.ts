import { ethers, upgrades } from "hardhat";

const PRECISION = '1';
const MINT_FEE = '10000000';
const SWAP_FEE = '20000000';
const REDEEM_FEE = '50000000';
const FEE_DENOMITOR = '10000000000';

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(deployer.address);
  const StableSwap = await ethers.getContractFactory("StableSwap");
  const MockToken = await ethers.getContractFactory("MockToken");
  const cbETHSwap = await StableSwap.attach('0x6a589DA7D666A903fBf2c78CBd7D38D378edE593');
  const cbETH = await MockToken.attach('0xd994DD0FA5D62306BC2E46B96104E7Fda80Afa62');
  const wETH = await MockToken.attach('0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6');
  await wETH.approve(cbETHSwap.address, '1000000000000000000000000');
  await cbETH.approve('0x3Ea5a52a985091F37555F842A164BE66eCDF1AD1', '1000000000000000000000000');
  let txn1 = await cbETHSwap.unpause();
  console.log(txn1.hash);
  let txn2 = await cbETHSwap.mint(['1000000000000000', '1000000000000000'], 0);
  console.log(txn2.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
