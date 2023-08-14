import { loadFixture, time } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers, upgrades, web3 } from "hardhat";

const PRECISION = '1';
const MINT_FEE = '10000000';
const SWAP_FEE = '20000000';
const REDEEM_FEE = '50000000';

describe("GaugeController", function () {
  async function deployTokensAndController() {
    // Contracts are deployed using the first signer/account by default
    const [owner] = await ethers.getSigners();

    const GaugeController = await ethers.getContractFactory("GaugeController");
    const GaugeRewardController = await ethers.getContractFactory("GaugeRewardController");
    const VotingEscrow = await ethers.getContractFactory("VotingEscrow");
    const MockToken = await ethers.getContractFactory("MockToken");
    const StableAssetToken = await ethers.getContractFactory("StableAssetToken");
    const rewardToken = await MockToken.deploy("Reward", "R", 18);
    const poolToken = await upgrades.deployProxy(StableAssetToken, ["Pool Token", "PT"]);

    const votingEscrow = await upgrades.deployProxy(VotingEscrow, [rewardToken.address, "Voting Reward", "vR", "1"]);
    const rewardController = await upgrades.deployProxy(GaugeRewardController, [rewardToken.address, votingEscrow.address]);
    const controller = await upgrades.deployProxy(GaugeController, [rewardToken.address, poolToken.address, "10000000000", rewardController.address]);
    /// Set minter of pool token to be swap contract
    await poolToken.setMinter(owner.address, true);
    return { controller, rewardToken, poolToken, votingEscrow, rewardController };
  }

  it('should set governance', async () => {
    const { controller, rewardToken, poolToken } = await loadFixture(deployTokensAndController);
    const [owner, other] = await ethers.getSigners();

    await controller.proposeGovernance(other.address);
    await controller.connect(other).acceptGovernance();
    expect(await controller.governance()).to.equals(other.address);
  });

  it('should not set governance', async () => {
    const { controller, rewardToken, poolToken } = await loadFixture(deployTokensAndController);
    const [owner, other] = await ethers.getSigners();

    await expect(controller.connect(other).proposeGovernance(other.address)).to.be.revertedWith("not governance");
  });

  it('should update reward rate', async () => {
    const { controller, rewardToken, poolToken } = await loadFixture(deployTokensAndController);
    const [owner, other] = await ethers.getSigners();

    await controller.updateRewardRate("20000000000000000000000");
    expect(await controller.rewardRatePerWeek()).to.equals("20000000000000000000000");
  });

  it('should not update reward rate not governance', async () => {
    const { controller, rewardToken, poolToken } = await loadFixture(deployTokensAndController);
    const [owner, other] = await ethers.getSigners();

    await expect(controller.connect(other).updateRewardRate("200")).to.be.revertedWith("not governance");
  });

  it('should not update reward rate not set', async () => {
    const { controller, rewardToken, poolToken } = await loadFixture(deployTokensAndController);
    const [owner, other] = await ethers.getSigners();

    await expect(controller.updateRewardRate("0")).to.be.revertedWith("reward rate not set");
  });

  it('should checkpoint', async () => {
    const { controller, rewardToken, poolToken, votingEscrow, rewardController } = await loadFixture(deployTokensAndController);
    const [owner, other, poolOne, poolTwo] = await ethers.getSigners();
 
    await rewardController['addType(string,uint256)']("Pool", "1");
    await rewardController['addGauge(address,uint128,uint256)'](poolOne.address, 0, "1");
    await rewardController['addGauge(address,uint128,uint256)'](poolTwo.address, 0, "1");
    await poolToken.mint(poolOne.address, "10000");
    await poolToken.mint(poolTwo.address, "10000");
    await rewardToken.mint(other.address, "1000000000000000000");
    await rewardToken.connect(other).approve(votingEscrow.address, "1000000000000000000");
    await votingEscrow.connect(other).createLock("1000000000000000000", 1753675829);
    await rewardController.connect(other).voteForGaugeWeights(poolOne.address, "1000");
    await rewardController.connect(other).voteForGaugeWeights(poolTwo.address, "1000");


    await time.increase(7 * 86400);
    await controller.checkpoint();
    const poolOneShare = await controller.claimable(poolOne.address);
    const poolTwoShare = await controller.claimable(poolTwo.address);
    expect(poolOneShare).to.greaterThan(0);
    expect(poolOneShare).to.equals(poolTwoShare);
  });

  it('should claim', async () => {
    const { controller, rewardToken, poolToken, votingEscrow, rewardController } = await loadFixture(deployTokensAndController);
    const [owner, other, poolOne, poolTwo] = await ethers.getSigners();
 
    await rewardController['addType(string,uint256)']("Pool", "1");
    await rewardController['addGauge(address,uint128,uint256)'](poolOne.address, 0, "1");
    await rewardController['addGauge(address,uint128,uint256)'](poolTwo.address, 0, "1");
    await poolToken.mint(poolOne.address, "10000");
    await poolToken.mint(poolTwo.address, "10000");
    await rewardToken.mint(other.address, "1000000000000000000");
    await rewardToken.mint(controller.address, "10000000000000000000000")
    await rewardToken.connect(other).approve(votingEscrow.address, "1000000000000000000");
    await votingEscrow.connect(other).createLock("1000000000000000000", 1753675829);
    await rewardController.connect(other).voteForGaugeWeights(poolOne.address, "1000");
    await rewardController.connect(other).voteForGaugeWeights(poolTwo.address, "1000");


    await time.increase(7 * 86400);
    await controller.connect(poolOne).claim();
    await controller.connect(poolTwo).claim();
    const poolOneShare = await controller.claimable(poolOne.address);
    const poolTwoShare = await controller.claimable(poolTwo.address);
    const poolOneClaimed = await controller.claimed(poolOne.address);
    const poolTwoClaimed = await controller.claimed(poolTwo.address);
    const poolOneBalance = await rewardToken.balanceOf(poolOne.address);
    const poolTwoBalance = await rewardToken.balanceOf(poolTwo.address);
    expect(poolOneShare).to.greaterThan(0);
    expect(poolOneShare).to.equals(poolTwoShare);
    expect(poolOneBalance).to.greaterThan(0);
    expect(poolTwoBalance).to.greaterThan(0);
    expect(poolOneClaimed).to.equals(poolOneBalance);
    expect(poolTwoClaimed).to.equals(poolTwoBalance);
  });
});
