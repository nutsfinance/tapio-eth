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
  const application = await StableAssetApplication.attach('0x1aefabbe56db3c47f0824f4af3d74845e4bcd117');
  await application.mint('0x774a36e77876eC9e887a07b2E53f81479d178532', ['1000000000000000', '1000000000000000'], '0', {value: '1000000000000000'});
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
