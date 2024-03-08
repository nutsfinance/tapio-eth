import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";

describe("wtapETH", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployeFixture() {
    // Contracts are deployed using the first signer/account by default
    const accounts = await ethers.getSigners();
    const owner = accounts[0];
    const governance = accounts[1];
    const pool1 = accounts[2];
    const pool2 = accounts[3];

    const TapETH = await ethers.getContractFactory("TapETH");
    const tapETH = await upgrades.deployProxy(TapETH, [governance.address]);
    const WtapETH = await ethers.getContractFactory("WtapETH");
    const wtapETH = await upgrades.deployProxy(WtapETH, [tapETH.address]);

    return { tapETH, wtapETH, accounts, governance, owner, pool1, pool2 };
  }

  describe("wrap", function () {
    it("it Should wrap tapETH tokens ", async function () {
      const { tapETH, wtapETH, accounts, governance, pool1, pool2 } =
        await deployeFixture();
      let user = accounts[4];
      await tapETH.connect(governance).addPool(pool1.address);
      let amount1 = 1_000_000_000_000_000_000_000n;
      let amount2 = 500_000_000_000_000_000_000n;
      let targetTotalSupply = amount1 + amount2;
      let amountToWrap = 300_000_000_000_000_000_000n;
      let wtapETHTargetAmount = (amountToWrap * amount1) / targetTotalSupply;
      let totalAmount = amount1 + amount2;
      await tapETH.connect(pool1).mintShares(user.address, amount1);
      await tapETH.connect(pool1).addTotalSupply(amount2);
      await tapETH.connect(user).approve(wtapETH.address, amountToWrap);
      await wtapETH.connect(user).wrap(amountToWrap);
      expect(await tapETH.totalSupply()).to.equal(targetTotalSupply);
      expect(await tapETH.totalShares()).to.equal(amount1);
      expect(await tapETH.sharesOf(user.address)).to.equal(
        amount1 - wtapETHTargetAmount
      );
      expect(await tapETH.sharesOf(wtapETH.address)).to.equal(
        wtapETHTargetAmount
      );
      expect(await tapETH.balanceOf(wtapETH.address)).to.equal(amountToWrap);
      expect(await wtapETH.balanceOf(user.address)).to.equal(
        wtapETHTargetAmount
      );
    });
  });

  describe("unwrap", function () {
    it("it Should unwrap wtapETH tokens ", async function () {
      const { tapETH, wtapETH, accounts, governance, pool1, pool2 } =
        await deployeFixture();
      let user = accounts[4];
      await tapETH.connect(governance).addPool(pool1.address);
      let amount1 = 1_000_000_000_000_000_000_000n;
      let amount2 = 500_000_000_000_000_000_000n;
      let targetTotalSupply = amount1 + amount2;
      let amountToWrap = 300_000_000_000_000_000_000n;
      let wtapETHTargetAmount = (amountToWrap * amount1) / targetTotalSupply;
      let totalAmount = amount1 + amount2;
      await tapETH.connect(pool1).mintShares(user.address, amount1);
      await tapETH.connect(pool1).addTotalSupply(amount2);
      await tapETH.connect(user).approve(wtapETH.address, amountToWrap);
      await wtapETH.connect(user).wrap(amountToWrap);
      await wtapETH.connect(user).unwrap(wtapETHTargetAmount);
      expect(await tapETH.totalSupply()).to.equal(targetTotalSupply);
      expect(await tapETH.totalShares()).to.equal(amount1);
      expect(await tapETH.sharesOf(user.address)).to.equal(amount1);
      expect(await tapETH.sharesOf(wtapETH.address)).to.equal(0);
      expect(await tapETH.balanceOf(wtapETH.address)).to.equal(0);
      expect(await wtapETH.balanceOf(user.address)).to.equal(0);
    });
  });
});
