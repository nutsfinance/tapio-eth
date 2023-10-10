import { ethers, upgrades } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(deployer.address);

  const poolToken = '0xA33a79c5Efadac7c07693c3ce32Acf9a1Fc5A387';
  const votingTokenAddress = '0x8d68692bddED1F7e70cC1B4D4C58be3F9902e86A';
  const votingEscrowAddress = '0x2b4Db8eb1f6792f253633892862D0799f335c129';
  const VotingToken = await ethers.getContractFactory("VotingToken");
  const VotingEscrow = await ethers.getContractFactory("VotingEscrow");
  const GaugeRewardController = await ethers.getContractFactory("GaugeRewardController");
  const GaugeController = await ethers.getContractFactory("GaugeController");


  const votingToken = await upgrades.deployProxy(VotingToken, ["Tapio", "TAP"]);
  console.log("votingToken deployed");
  console.log(`votingToken: ${votingToken.address}`);

  const votingEscrow = await upgrades.deployProxy(VotingEscrow, [votingTokenAddress, "vTapio", "vTAP", "v0"]);
  console.log("votingEscrow deployed");
  console.log(`votingEscrow: ${votingEscrow.address}`);

  const gaugeRewardController = await upgrades.deployProxy(GaugeRewardController, [votingTokenAddress, votingEscrowAddress]);
  console.log("gaugeRewardController deployed");
  console.log(`gaugeRewardController: ${gaugeRewardController.address}`);

  const gaugeController = await upgrades.deployProxy(GaugeController, [votingTokenAddress, poolToken, "1000000000000000000000", gaugeRewardController.address]);
  console.log("gaugeController deployed");
  console.log(`gaugeController: ${gaugeController.address}`);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
