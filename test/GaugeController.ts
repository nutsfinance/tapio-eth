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
    const MockToken = await ethers.getContractFactory("MockToken");
    const StableAssetToken = await ethers.getContractFactory("StableAssetToken");
    const rewardToken = await MockToken.deploy("Reward", "R", 18);
    const poolToken = await upgrades.deployProxy(StableAssetToken, ["Pool Token", "PT"]);

    const controller = await upgrades.deployProxy(GaugeController, [rewardToken.address, poolToken.address, "10000000000000000000000"]);
    /// Set minter of pool token to be swap contract
    await poolToken.setMinter(owner.address, true);
    return { controller, rewardToken, poolToken };
  }

  it('should set governance', async () => {
    const { controller, rewardToken, poolToken } = await loadFixture(deployTokensAndController);
    const [owner, other] = await ethers.getSigners();

    await controller.setGovernance(other.address);
    expect(await controller.governance()).to.equals(other.address);
  });

  it('should not set governance', async () => {
    const { controller, rewardToken, poolToken } = await loadFixture(deployTokensAndController);
    const [owner, other] = await ethers.getSigners();

    await expect(controller.connect(other).setGovernance(other.address)).to.be.revertedWith("not governance");
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

  it('should add pool', async () => {
    const { controller, rewardToken, poolToken } = await loadFixture(deployTokensAndController);
    const [owner, other, poolOne] = await ethers.getSigners();

    await controller.addPool(poolOne.address);
    expect(await controller.poolIndexToAddress(0)).to.equals(poolOne.address);
  });

  it('should not add pool not governance', async () => {
    const { controller, rewardToken, poolToken } = await loadFixture(deployTokensAndController);
    const [owner, other, poolOne] = await ethers.getSigners();

    await expect(controller.connect(other).addPool(poolOne.address)).to.be.revertedWith("not governance");
  });

  it('should not add pool not set', async () => {
    const { controller, rewardToken, poolToken } = await loadFixture(deployTokensAndController);
    const [owner, other] = await ethers.getSigners();

    await expect(controller.addPool("0x0000000000000000000000000000000000000000")).to.be.revertedWith("pool address not set");
  });

  it('should enable pool', async () => {
    const { controller, rewardToken, poolToken } = await loadFixture(deployTokensAndController);
    const [owner, other, poolOne] = await ethers.getSigners();

    await controller.addPool(poolOne.address);
    await controller.enablePool(0);
    expect(await controller.poolActivated(0)).to.equals(true);
  });

  it('should not enable pool not governance', async () => {
    const { controller, rewardToken, poolToken } = await loadFixture(deployTokensAndController);
    const [owner, other, poolOne] = await ethers.getSigners();

    await expect(controller.connect(other).enablePool(0)).to.be.revertedWith("not governance");
  });

  it('should not enable pool not set', async () => {
    const { controller, rewardToken, poolToken } = await loadFixture(deployTokensAndController);
    const [owner, other] = await ethers.getSigners();

    await expect(controller.enablePool("1")).to.be.revertedWith("pool address not set");
  });

  it('should disable pool', async () => {
    const { controller, rewardToken, poolToken } = await loadFixture(deployTokensAndController);
    const [owner, other, poolOne] = await ethers.getSigners();

    await controller.addPool(poolOne.address);
    await controller.disablePool(0);
    expect(await controller.poolActivated(0)).to.equals(false);
  });

  it('should not disable pool not governance', async () => {
    const { controller, rewardToken, poolToken } = await loadFixture(deployTokensAndController);
    const [owner, other, poolOne] = await ethers.getSigners();

    await expect(controller.connect(other).disablePool(0)).to.be.revertedWith("not governance");
  });

  it('should not disable pool not set', async () => {
    const { controller, rewardToken, poolToken } = await loadFixture(deployTokensAndController);
    const [owner, other] = await ethers.getSigners();

    await expect(controller.disablePool("1")).to.be.revertedWith("pool address not set");
  });

  it('should update pool weight', async () => {
    const { controller, rewardToken, poolToken } = await loadFixture(deployTokensAndController);
    const [owner, other, poolOne] = await ethers.getSigners();

    await controller.addPool(poolOne.address);
    await controller.updatePoolWeight(0, "100");
    expect(await controller.poolWeight(0)).to.equals("100");
  });

  it('should not update pool weight not governance', async () => {
    const { controller, rewardToken, poolToken } = await loadFixture(deployTokensAndController);
    const [owner, other, poolOne] = await ethers.getSigners();

    await expect(controller.connect(other).updatePoolWeight(0, "100")).to.be.revertedWith("not governance");
  });

  it('should not update pool weight not set', async () => {
    const { controller, rewardToken, poolToken } = await loadFixture(deployTokensAndController);
    const [owner, other] = await ethers.getSigners();

    await expect(controller.updatePoolWeight("1", "100")).to.be.revertedWith("pool address not set");
  });

  it('should checkpoint no balance', async () => {
    const { controller, rewardToken, poolToken } = await loadFixture(deployTokensAndController);
    const [owner, other, poolOne, poolTwo] = await ethers.getSigners();

    await controller.addPool(poolOne.address);
    await controller.addPool(poolTwo.address);
    await controller.updatePoolWeight(0, "100");
    await controller.updatePoolWeight(1, "100");

    await time.increase(3600);
    await controller.checkpoint();
    const poolOneShare = await controller.claimable(poolOne.address);
    const poolTwoShare = await controller.claimable(poolTwo.address);
    expect(poolOneShare).to.equals("0");
    expect(poolTwoShare).to.equals("0");
  });

  it('should checkpoint no weight', async () => {
    const { controller, rewardToken, poolToken } = await loadFixture(deployTokensAndController);
    const [owner, other, poolOne, poolTwo] = await ethers.getSigners();

    await controller.addPool(poolOne.address);
    await controller.addPool(poolTwo.address);
    await poolToken.mint(poolOne.address, "10000");
    await poolToken.mint(poolTwo.address, "20000");

    await time.increase(3600);
    await controller.checkpoint();
    const poolOneShare = await controller.claimable(poolOne.address);
    const poolTwoShare = await controller.claimable(poolTwo.address);
    expect(poolOneShare).to.equals("0");
    expect(poolTwoShare).to.equals("0");
  });

  it('should checkpoint', async () => {
    const { controller, rewardToken, poolToken } = await loadFixture(deployTokensAndController);
    const [owner, other, poolOne, poolTwo] = await ethers.getSigners();

    await controller.addPool(poolOne.address);
    await controller.addPool(poolTwo.address);
    await poolToken.mint(poolOne.address, "10000");
    await poolToken.mint(poolTwo.address, "10000");
    await controller.updatePoolWeight(0, "100");
    await controller.updatePoolWeight(1, "100");

    await time.increase(3600);
    await controller.checkpoint();
    const poolOneShare = await controller.claimable(0);
    const poolTwoShare = await controller.claimable(1);
    expect(poolOneShare).to.greaterThan(0);
    expect(poolOneShare).to.equals(poolTwoShare);
  });

  it('should claim', async () => {
    const { controller, rewardToken, poolToken } = await loadFixture(deployTokensAndController);
    const [owner, other, poolOne, poolTwo] = await ethers.getSigners();

    await controller.addPool(poolOne.address);
    await controller.addPool(poolTwo.address);
    await poolToken.mint(poolOne.address, "10000");
    await poolToken.mint(poolTwo.address, "10000");
    await controller.updatePoolWeight(0, "100");
    await controller.updatePoolWeight(1, "100");
    await rewardToken.mint(controller.address, "10000000000000000000000");

    await time.increase(3600);
    await controller.connect(poolOne).claim();
    await controller.connect(poolTwo).claim();
    const poolOneShare = await controller.claimable(0);
    const poolTwoShare = await controller.claimable(1);
    const poolOneClaimed = await controller.claimed(0);
    const poolTwoClaimed = await controller.claimed(1);
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
