import { ethers, upgrades } from "hardhat";

const PRECISION = '1';
const MINT_FEE = '10000000';
const SWAP_FEE = '20000000';
const REDEEM_FEE = '50000000';
const FEE_DENOMITOR = '10000000000';

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(deployer.address);
  const StableAssetApplication = await ethers.getContractFactory("StableAssetApplication");
  const application = await StableAssetApplication.attach('0x9aabd039fD0bF767Db26293a039998e85Bd31255');
  await application.mint('0xd22f46Ba0425066159F828EFA5fFEab4DAeb9fd0', ['1000000000000000', '1000000000000000'], '0', {value: '1000000000000000'});
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
