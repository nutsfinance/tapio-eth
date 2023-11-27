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
  const application = await StableAssetApplication.attach('0x44A54f1cc211cfCFfE8b83C22f44728F3Fa5004C');
  await application.mint('0x9719443a2BBb5AB61744C1B3C71C2E3527101a91', ['1000000000000000', '1000000000000000'], '0', {value: '1000000000000000'});
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
