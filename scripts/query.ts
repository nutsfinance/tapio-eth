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
  const application = StableAssetApplication.attach('0x9aabd039fD0bF767Db26293a039998e85Bd31255');
  console.log(`balance: ${await application.getSwapAmountCrossPool('0xd22f46Ba0425066159F828EFA5fFEab4DAeb9fd0', '0x6f07114487BaC63856060f9f1739d66b16DF579b', '0x1643E812aE58766192Cf7D2Cf9567dF2C37e9B7F', '0xc91960dAaf78B817E3a5064A80D7085CD85DfD04', '200000000000000')}`);
  
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
