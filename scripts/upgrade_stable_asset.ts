import { ethers, upgrades } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(deployer.address);
  const StableAsset = await ethers.getContractFactory("StableAsset");

  const swapOne = await upgrades.upgradeProxy('0xB1138D397802dcD92f1A8F179716ad16Edb88DA1', StableAsset);
  const swapTwo = await upgrades.upgradeProxy('0x6a589DA7D666A903fBf2c78CBd7D38D378edE593', StableAsset);

  console.log("application deployed");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
