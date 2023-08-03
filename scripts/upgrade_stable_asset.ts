import { ethers, upgrades } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(deployer.address);
  const StableAsset = await ethers.getContractFactory("StableAsset");

  const swapOne = await upgrades.upgradeProxy('0x52543FE4597230ef59fC8C38D3a682Fa2F0fc026', StableAsset);
  const swapTwo = await upgrades.upgradeProxy('0x8589F6Dedae785634f47132193680149d43cfaF3', StableAsset);

  console.log("application deployed");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
