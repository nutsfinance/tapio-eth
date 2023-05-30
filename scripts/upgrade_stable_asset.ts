import { ethers, upgrades } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(deployer.address);
  const StableAsset = await ethers.getContractFactory("StableAsset");

  const swapOne = await upgrades.upgradeProxy('0xd22f46Ba0425066159F828EFA5fFEab4DAeb9fd0', StableAsset);
  const swapTwo = await upgrades.upgradeProxy('0x6f07114487BaC63856060f9f1739d66b16DF579b', StableAsset);
  const swapThree = await upgrades.upgradeProxy('0xa97aB47cE31EDA363305897D64a242976186A0f6', StableAsset);

  console.log("application deployed");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
