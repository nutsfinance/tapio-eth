import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("TapETH", function () {
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
    const tapETH = await TapETH.deploy(governance.address);

    return { tapETH, accounts, governance, owner, pool1, pool2 };
  }

  describe("addPool", function () {
    it("it Should add a pool ", async function () {
      const { tapETH, accounts, governance, pool1, pool2 } =
        await deployeFixture();
      await expect(tapETH.connect(governance).addPool(pool1.address))
        .to.emit(tapETH, "PoolAdded")
        .withArgs(pool1.address);
      expect(await tapETH.isPool(pool1.address)).to.equal(true);
      expect(await tapETH.pools(0)).to.equal(pool1.address);
    });
    it("It Should revert when the caller is not the governance ", async function () {
      const { tapETH, accounts, governance, owner, pool1, pool2 } =
        await deployeFixture();
      await expect(
        tapETH.connect(owner).addPool(pool1.address)
      ).to.be.revertedWith("TapETH: no governance");
    });
    it("It Should revert when the pool is already added ", async function () {
      const { tapETH, accounts, governance, pool1, pool2 } =
        await deployeFixture();
      await tapETH.connect(governance).addPool(pool1.address);
      await expect(
        tapETH.connect(governance).addPool(pool1.address)
      ).to.be.revertedWith("TapETH: pool is already added");
    });
  });

  describe("removePool", function () {
    it("it Should remove a pool ", async function () {
      const { tapETH, accounts, governance, pool1, pool2 } =
        await deployeFixture();
      await tapETH.connect(governance).addPool(pool1.address);
      await expect(tapETH.connect(governance).removePool(pool1.address))
        .to.emit(tapETH, "PoolRemoved")
        .withArgs(pool1.address);
      expect(await tapETH.isPool(pool1.address)).to.equal(false);
    });
    it("It Should revert when the caller is not the governance ", async function () {
      const { tapETH, accounts, governance, owner, pool1, pool2 } =
        await deployeFixture();
      await tapETH.connect(governance).addPool(pool1.address);
      await expect(
        tapETH.connect(owner).removePool(pool1.address)
      ).to.be.revertedWith("TapETH: no governance");
    });
    it("It Should revert when the pool is already removed ", async function () {
      const { tapETH, accounts, governance, pool1, pool2 } =
        await deployeFixture();
      await tapETH.connect(governance).addPool(pool1.address);
      await tapETH.connect(governance).removePool(pool1.address);
      await expect(
        tapETH.connect(governance).removePool(pool1.address)
      ).to.be.revertedWith("TapETH: pool doesn't exist");
    });
  });

  describe("proposeGovernance", function () {
    it("it Should update pendingGovernance ", async function () {
      const { tapETH, accounts, governance, pool1, pool2 } =
        await deployeFixture();
      let newGovernance = accounts[4];
      await expect(
        tapETH.connect(governance).proposeGovernance(newGovernance.address)
      )
        .to.emit(tapETH, "GovernanceProposed")
        .withArgs(newGovernance.address);
      expect(await tapETH.pendingGovernance()).to.equal(newGovernance.address);
    });
    it("It Should revert when the caller is not the governance ", async function () {
      const { tapETH, accounts, governance, owner, pool1, pool2 } =
        await deployeFixture();
      let newGovernance = accounts[4];
      await expect(
        tapETH.connect(owner).proposeGovernance(newGovernance.address)
      ).to.be.revertedWith("TapETH: no governance");
    });
  });

  describe("acceptGovernance", function () {
    it("it Should update governance ", async function () {
      const { tapETH, accounts, governance, pool1, pool2 } =
        await deployeFixture();
      let newGovernance = accounts[4];
      tapETH.connect(governance).proposeGovernance(newGovernance.address);
      await expect(tapETH.connect(newGovernance).acceptGovernance())
        .to.emit(tapETH, "GovernanceModified")
        .withArgs(newGovernance.address);
      expect(await tapETH.governance()).to.equal(newGovernance.address);
      expect(await tapETH.pendingGovernance()).to.equal(
        "0x0000000000000000000000000000000000000000"
      );
    });
    it("It Should revert when the caller is not the pending governance ", async function () {
      const { tapETH, accounts, governance, owner, pool1, pool2 } =
        await deployeFixture();
      let newGovernance = accounts[4];
      tapETH.connect(governance).proposeGovernance(newGovernance.address);
      await expect(
        tapETH.connect(governance).acceptGovernance()
      ).to.be.revertedWith("TapETH: no pending governance");
    });
  });

  describe("approve", function () {
    it("it Should update allowances", async function () {
      const { tapETH, accounts, governance, owner, pool1, pool2 } =
        await deployeFixture();
      let user = accounts[4];
      let spender = accounts[5];
      let amount = 1_000_000_000_000_000_000_000n;
      tapETH.connect(user).approve(spender.address, amount);
      expect(await tapETH.allowance(user.address, spender.address)).to.equal(
        amount
      );
    });
  });

  describe("approve", function () {
    it("it Should update allowance", async function () {
      const { tapETH, accounts, governance, owner, pool1, pool2 } =
        await deployeFixture();
      let user = accounts[4];
      let spender = accounts[5];
      let amount = 1_000_000_000_000_000_000_000n;
      tapETH.connect(user).approve(spender.address, amount);
      expect(await tapETH.allowance(user.address, spender.address)).to.equal(
        amount
      );
    });
  });
  describe("increaseAllowance", function () {
    it("it Should increase allowance", async function () {
      const { tapETH, accounts, governance, owner, pool1, pool2 } =
        await deployeFixture();
      let user = accounts[4];
      let spender = accounts[5];
      let amount1 = 1_000_000_000_000_000_000_000n;
      let amount2 = 2_000_000_000_000_000_000_000n;
      let totalAmount = amount1 + amount2;
      tapETH.connect(user).approve(spender.address, amount1);
      tapETH.connect(user).increaseAllowance(spender.address, amount2);
      expect(await tapETH.allowance(user.address, spender.address)).to.equal(
        totalAmount
      );
    });
  });

  describe("increaseAllowance", function () {
    it("it Should decrease allowance", async function () {
      const { tapETH, accounts, governance, owner, pool1, pool2 } =
        await deployeFixture();
      let user = accounts[4];
      let spender = accounts[5];
      let amount1 = 1_000_000_000_000_000_000_000n;
      let amount2 = 500_000_000_000_000_000_000n;
      let totalAmount = amount1 - amount2;
      tapETH.connect(user).approve(spender.address, amount1);
      tapETH.connect(user).decreaseAllowance(spender.address, amount2);
      expect(await tapETH.allowance(user.address, spender.address)).to.equal(
        totalAmount
      );
    });
  });

  describe("mintShares", function () {
    it("it Should mint shares for one user", async function () {
      const { tapETH, accounts, governance, owner, pool1, pool2 } =
        await deployeFixture();
      let user = accounts[4];
      await tapETH.connect(governance).addPool(pool1.address);
      let amount = 1_000_000_000_000_000_000_000n;
      await tapETH.connect(pool1).mintShares(user.address, amount);
      expect(await tapETH.totalSupply()).to.equal(amount);
      expect(await tapETH.getTotalShares()).to.equal(amount);
      expect(await tapETH.sharesOf(user.address)).to.equal(amount);
      expect(await tapETH.balanceOf(user.address)).to.equal(amount);
    });

    it("it Should mint shares for many users", async function () {
      const { tapETH, accounts, governance, owner, pool1, pool2 } =
        await deployeFixture();
      let user1 = accounts[4];
      let user2 = accounts[5];
      let user3 = accounts[6];
      await tapETH.connect(governance).addPool(pool1.address);
      let amount1 = 1_000_000_000_000_000_000_000n;
      let amount2 = 2_000_000_000_000_000_000_000n;
      let amount3 = 3_000_000_000_000_000_000_000n;
      let totalAmount = amount1 + amount2 + amount3;
      await tapETH.connect(pool1).mintShares(user1.address, amount1);
      await tapETH.connect(pool1).mintShares(user2.address, amount2);
      await tapETH.connect(pool1).mintShares(user3.address, amount3);
      expect(await tapETH.totalSupply()).to.equal(totalAmount);
      expect(await tapETH.getTotalShares()).to.equal(totalAmount);
      expect(await tapETH.sharesOf(user1.address)).to.equal(amount1);
      expect(await tapETH.balanceOf(user1.address)).to.equal(amount1);
      expect(await tapETH.sharesOf(user2.address)).to.equal(amount2);
      expect(await tapETH.balanceOf(user2.address)).to.equal(amount2);
      expect(await tapETH.sharesOf(user3.address)).to.equal(amount3);
      expect(await tapETH.balanceOf(user3.address)).to.equal(amount3);
    });
    it("it Should revert when the caller is not a pool", async function () {
      const { tapETH, accounts, governance, owner, pool1, pool2 } =
        await deployeFixture();
      let user1 = accounts[4];
      let user2 = accounts[5];
      let user3 = accounts[6];
      await tapETH.connect(governance).addPool(pool1.address);
      let amount1 = 1_000_000_000_000_000_000_000n;
      let amount2 = 2_000_000_000_000_000_000_000n;
      let amount3 = 3_000_000_000_000_000_000_000n;
      let totalAmount = amount1 + amount2 + amount3;
      await tapETH.connect(pool1).mintShares(user1.address, amount1);
      await tapETH.connect(pool1).mintShares(user2.address, amount2);
      await tapETH.connect(pool1).mintShares(user3.address, amount3);
      expect(await tapETH.totalSupply()).to.equal(totalAmount);
      expect(await tapETH.getTotalShares()).to.equal(totalAmount);
      expect(await tapETH.sharesOf(user1.address)).to.equal(amount1);
      expect(await tapETH.balanceOf(user1.address)).to.equal(amount1);
      expect(await tapETH.sharesOf(user2.address)).to.equal(amount2);
      expect(await tapETH.balanceOf(user2.address)).to.equal(amount2);
      expect(await tapETH.sharesOf(user3.address)).to.equal(amount3);
      expect(await tapETH.balanceOf(user3.address)).to.equal(amount3);
    });
  });

  describe("burnShares", function () {
    it("it Should burn shares for one user", async function () {
      const { tapETH, accounts, governance, owner, pool1, pool2 } =
        await deployeFixture();
      let user = accounts[4];
      await tapETH.connect(governance).addPool(pool1.address);
      let amount1 = 1_000_000_000_000_000_000_000n;
      let amount2 = 500_000_000_000_000_000_000n;
      let deltaAmount = amount1 - amount2;
      await tapETH.connect(pool1).mintShares(user.address, amount1);
      await tapETH.connect(user).burnShares(amount2);
      expect(await tapETH.totalSupply()).to.equal(amount1);
      expect(await tapETH.getTotalShares()).to.equal(deltaAmount);
      expect(await tapETH.sharesOf(user.address)).to.equal(deltaAmount);
      expect(await tapETH.balanceOf(user.address)).to.equal(amount1);
    });

    it("it Should burn shares for many users", async function () {
      const { tapETH, accounts, governance, owner, pool1, pool2 } =
        await deployeFixture();
      let user1 = accounts[4];
      let user2 = accounts[5];
      let user3 = accounts[6];
      await tapETH.connect(governance).addPool(pool1.address);
      let amountToBurn = 500_000_000_000_000_000_000n;
      let amount1 = 1_000_000_000_000_000_000_000n;
      let amount2 = 2_000_000_000_000_000_000_000n;
      let amount3 = 3_000_000_000_000_000_000_000n;
      let deltaAmount =
        amount1 -
        amountToBurn +
        amount2 -
        amountToBurn +
        amount3 -
        amountToBurn;
      await tapETH.connect(pool1).mintShares(user1.address, amount1);
      await tapETH.connect(pool1).mintShares(user2.address, amount2);
      await tapETH.connect(pool1).mintShares(user3.address, amount3);
      await tapETH.connect(user1).burnShares(amountToBurn);
      await tapETH.connect(user2).burnShares(amountToBurn);
      await tapETH.connect(user3).burnShares(amountToBurn);
      expect(await tapETH.totalSupply()).to.equal(amount1 + amount2 + amount3);
      expect(await tapETH.getTotalShares()).to.equal(deltaAmount);
      expect(await tapETH.sharesOf(user1.address)).to.equal(
        amount1 - amountToBurn
      );
      expect(await tapETH.balanceOf(user1.address)).to.equal(
        ((amount1 - amountToBurn) * (amount1 + amount2 + amount3)) / deltaAmount
      );
      expect(await tapETH.sharesOf(user2.address)).to.equal(
        amount2 - amountToBurn
      );
      expect(await tapETH.balanceOf(user2.address)).to.equal(
        ((amount2 - amountToBurn) * (amount1 + amount2 + amount3)) / deltaAmount
      );
      expect(await tapETH.sharesOf(user3.address)).to.equal(
        amount3 - amountToBurn
      );
      expect(await tapETH.balanceOf(user3.address)).to.equal(
        ((amount3 - amountToBurn) * (amount1 + amount2 + amount3)) / deltaAmount
      );
    });
  });
});
