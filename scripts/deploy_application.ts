import { ethers, upgrades } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(deployer.address);
  const StableAssetApplication = await ethers.getContractFactory("StableAssetApplication");

  const wETHAddress = '0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6';
  const application = await upgrades.deployProxy(StableAssetApplication, [wETHAddress]);

  console.log("application deployed");
  console.log(`cbETH: ${application.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
