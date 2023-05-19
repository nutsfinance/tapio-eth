import { ethers, upgrades } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(deployer.address);
  const RocketTokenExchangeRateProvider = await ethers.getContractFactory("RocketTokenExchangeRateProvider");

  const rETHAddress = '0x178e141a0e3b34152f73ff610437a7bf9b83267a';
  const rate = await upgrades.deployProxy(RocketTokenExchangeRateProvider, [rETHAddress]);

  console.log("application deployed");
  console.log(`cbETH: ${rate.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
