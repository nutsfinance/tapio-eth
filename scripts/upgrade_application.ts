import { ethers, upgrades } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(deployer.address);
  const StableAssetApplication = await ethers.getContractFactory("StableAssetApplication");

  const application = await upgrades.upgradeProxy('0x019270711FF6774a14732F850f9A15008F15c05f', StableAssetApplication);

  console.log("application deployed");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
