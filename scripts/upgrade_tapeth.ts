import { ethers, upgrades } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(deployer.address);
  const TapETH = await ethers.getContractFactory("TapETH");

  const tapETH = await upgrades.upgradeProxy('0x0C68f684324551b4B6Ff6DFc6314655f8e7d761a', TapETH);

  console.log("application deployed");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
