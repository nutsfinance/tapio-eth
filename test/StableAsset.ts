import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers, upgrades, web3 } from "hardhat";
import BN from "bn.js";

const PRECISION = '1';
const MINT_FEE = '10000000';
const SWAP_FEE = '20000000';
const REDEEM_FEE = '50000000';
const FEE_DENOMITOR = '10000000000';

const assertFee = (getAmount: string, feeAmount: string, fee: string) => {
  const expectedFee = new BN(getAmount).mul(new BN(fee)).div(new BN(FEE_DENOMITOR));
  expect(feeAmount.toString()).to.equal(expectedFee.toString());
};

const assertAlmostTheSame = (num1: BN, num2: BN) => {
  // Assert that the difference is smaller than 0.01%
  const diff = num1.sub(num2).abs().mul(new BN(10000)).div(BN.min(num1, num2)).toNumber();
  expect(diff).to.equal(0);
};

const assetInvariant = async (balance0: string, balance1: string, A: number, D: string) => {
  // We only check n = 2 here
  const left = new BN(A * 4).mul(new BN(balance0).add(new BN(balance1))).add(new BN(D));
  // const num = new BN(D).pow(new BN('3')).div(new BN(balance0).mul(new BN(balance1)).mul(new BN('4')));
  const right = new BN(A * 4).mul(new BN(D)).add(new BN(D).pow(new BN('3')).div(new BN(balance0).mul(new BN(balance1)).mul(new BN('4'))));

  assertAlmostTheSame(left, right);
};

describe("StableAsset", function () {
  async function deploySwapAndTokens() {
    // Contracts are deployed using the first signer/account by default
    const [owner, feeRecipient, user, user2, yieldRecipient] = await ethers.getSigners();

    const ACoconutSwap = await ethers.getContractFactory("StableAsset");
    const MockToken = await ethers.getContractFactory("MockToken");
    const ACoconutBTC = await ethers.getContractFactory("StableAssetToken");

    const token1 = await MockToken.deploy("test 1", "T1", 18);
    const token2 = await MockToken.deploy("test 2", "T2", 18);
    const poolToken = await upgrades.deployProxy(ACoconutBTC, ["Pool Token", "PT"]);

    const swap = await upgrades.deployProxy(ACoconutSwap, [[token1.address, token2.address], [PRECISION, PRECISION], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeRecipient.address, yieldRecipient.address, poolToken.address, 100]);
    await poolToken.setMinter(swap.address, true);
    await swap.approve(token1.address, swap.address);
    await swap.approve(token2.address, swap.address);

    return { swap, token1, token2, poolToken };
  }

  async function deploySwapAndTokensExchangeRate() {
    // Contracts are deployed using the first signer/account by default
    const [owner, feeRecipient, user, user2, yieldRecipient] = await ethers.getSigners();

    const ACoconutSwap = await ethers.getContractFactory("StableAsset");
    const MockToken = await ethers.getContractFactory("MockToken");
    const ACoconutBTC = await ethers.getContractFactory("StableAssetToken");
    const MockTokenWithExchangeRate = await ethers.getContractFactory("MockExchangeRateProvider");
    const TokensWithExchangeRate = await ethers.getContractFactory("TokensWithExchangeRate");

    const token1 = await MockToken.deploy("test 1", "T1", 18);
    const token2 = await MockToken.deploy("test 2", "T2", 18);
    const exchangeRate = await MockTokenWithExchangeRate.deploy("1000000000000000000");
    const exchangeRateToken = await upgrades.deployProxy(TokensWithExchangeRate, [token2.address, exchangeRate.address, '18']);
    const poolToken = await upgrades.deployProxy(ACoconutBTC, ["Pool Token", "PT"]);

    const swap = await upgrades.deployProxy(ACoconutSwap, [[token1.address, exchangeRateToken.address], [PRECISION, PRECISION], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeRecipient.address, yieldRecipient.address, poolToken.address, 100]);
    await poolToken.setMinter(swap.address, true);
    await swap.approve(token1.address, swap.address);
    await swap.approve(token2.address, swap.address);
    await swap.approve(token1.address, exchangeRateToken.address);
    await swap.approve(token2.address, exchangeRateToken.address);


    return { swap, token1, token2, poolToken, exchangeRate, exchangeRateToken };
  }

  it("should initialize paramters", async () => {
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient] = await ethers.getSigners();

    expect(await swap.tokens(0)).to.equal(token1.address);
    expect(await swap.tokens(1)).to.equal(token2.address);
    expect((await swap.precisions(0)).toString()).to.equal(PRECISION);
    expect((await swap.precisions(1)).toString()).to.equal(PRECISION);
    expect((await swap.mintFee()).toString()).to.equal(MINT_FEE);
    expect((await swap.swapFee()).toString()).to.equal(SWAP_FEE);
    expect((await swap.redeemFee()).toString()).to.equal(REDEEM_FEE);
    expect(await swap.poolToken()).to.equal(poolToken.address);
    expect(await swap.feeRecipient()).to.equal(feeRecipient.address);
    expect(await swap.governance()).to.equal(owner.address);
    expect(await swap.paused()).to.equal(true);
    expect((await swap.initialA()).toNumber()).to.equal(100);
  });

  it("should not initialize paramters", async () => {
    // Contracts are deployed using the first signer/account by default
    const [owner, feeRecipient, user, user2, yieldRecipient] = await ethers.getSigners();

    const ACoconutSwap = await ethers.getContractFactory("StableSwap");
    const MockToken = await ethers.getContractFactory("MockToken");
    const ACoconutBTC = await ethers.getContractFactory("StableSwapToken");

    const token1 = await MockToken.deploy("test 1", "T1", 18);
    const token2 = await MockToken.deploy("test 2", "T2", 18);
    const token17 = await MockToken.deploy("test 17", "T17", 17);
    const token19 = await MockToken.deploy("test 19", "T19", 19);
    const poolToken = await upgrades.deployProxy(ACoconutBTC, ["Pool Token", "PT"]);

    await expect(upgrades.deployProxy(ACoconutSwap, [[], [], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeRecipient.address, yieldRecipient.address, poolToken.address, 100]))
    .to.be.revertedWith("input mismatch");

    await expect(upgrades.deployProxy(ACoconutSwap, [[], [PRECISION, PRECISION], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeRecipient.address, yieldRecipient.address, poolToken.address, 100]))
        .to.be.revertedWith("input mismatch");

    await expect(upgrades.deployProxy(ACoconutSwap, [[token1.address, token2.address], [PRECISION, PRECISION], [MINT_FEE, SWAP_FEE], feeRecipient.address, yieldRecipient.address, poolToken.address, 0]))
        .to.be.revertedWith("no fees");

    await expect(upgrades.deployProxy(ACoconutSwap, [[token1.address, ethers.constants.AddressZero], [PRECISION, PRECISION], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeRecipient.address, yieldRecipient.address, poolToken.address, 0]))
        .to.be.revertedWith("token not set");

    // TODO: uncomment after fix the TODO in initialize
    // await expect(upgrades.deployProxy(ACoconutSwap, [[token1.address, token2.address], [PRECISION, 10], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeRecipient.address, yieldRecipient.address, poolToken.address, 0]))
    //     .to.be.revertedWith("precision not set");

    // await expect(upgrades.deployProxy(ACoconutSwap, [[token1.address, token17.address], [PRECISION, "10000000000000000"], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeRecipient.address, yieldRecipient.address, poolToken.address, 0]))
    //     .to.be.revertedWith("precision not set");

    // await expect(upgrades.deployProxy(ACoconutSwap, [[token1.address, token19.address], [1, "1000000000000000000"], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeRecipient.address, yieldRecipient.address, poolToken.address, 0]))
    //     .to.be.revertedWithPanic(0x11);

    await expect(upgrades.deployProxy(ACoconutSwap, [[token1.address, token2.address], [PRECISION, PRECISION], [MINT_FEE, SWAP_FEE, REDEEM_FEE], ethers.constants.AddressZero, yieldRecipient.address, poolToken.address, 0]))
        .to.be.revertedWith("fee recipient not set");

    await expect(upgrades.deployProxy(ACoconutSwap, [[token1.address, token2.address], [PRECISION, PRECISION], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeRecipient.address, ethers.constants.AddressZero, poolToken.address, 0]))
    .to.be.revertedWith("yield recipient not set");

    await expect(upgrades.deployProxy(ACoconutSwap, [[token1.address, token2.address], [PRECISION, PRECISION], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeRecipient.address, yieldRecipient.address, ethers.constants.AddressZero, 0]))
    .to.be.revertedWith("pool token not set");

    await expect(upgrades.deployProxy(ACoconutSwap, [[token1.address, token2.address], [PRECISION, PRECISION], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeRecipient.address, yieldRecipient.address, poolToken.address, 0]))
        .to.be.revertedWith("A not set");

    await expect(upgrades.deployProxy(ACoconutSwap, [[token1.address, token2.address], [PRECISION, PRECISION], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeRecipient.address, yieldRecipient.address, poolToken.address, 1000000]))
        .to.be.revertedWith("A not set");
  });

  it('should return the correct mint amount when two tokens are equal', async () => {
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient] = await ethers.getSigners();

    const amounts = await swap.getMintAmount([web3.utils.toWei('100'), web3.utils.toWei('100')]);
    const mintAmount = amounts[0];
    const feeAmount = amounts[1];
    const totalAmount = mintAmount.add(feeAmount);
    expect(totalAmount.toString()).to.equals(web3.utils.toWei('200'));
    assertFee(totalAmount.toString(), feeAmount.toString(), MINT_FEE);
    assetInvariant(web3.utils.toWei('100'), web3.utils.toWei('100'), 100, web3.utils.toWei('200'));
  });

  it('should return the correct mint amount when two tokens are not equal', async () => {
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const amounts = await swap.getMintAmount([web3.utils.toWei('110'), web3.utils.toWei('90')]);
    const mintAmount = amounts[0];
    const feeAmount = amounts[1];
    const totalAmount = mintAmount.add(feeAmount);
    assertFee(totalAmount.toString(), feeAmount.toString(), MINT_FEE);
    assetInvariant(web3.utils.toWei('100'), web3.utils.toWei('100'), 100, web3.utils.toWei('200'));
  });

  it("should mint the correct amount when two tokens are equal", async () => {
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user] = await ethers.getSigners();
    await swap.unpause();
    await token1.mint(user.address, web3.utils.toWei('100'));
    await token2.mint(user.address, web3.utils.toWei('100'));
    await token1.connect(user).approve(swap.address, web3.utils.toWei('100'));
    await token2.connect(user).approve(swap.address, web3.utils.toWei('100'));

    // token1 and token2 has 8 decimals, so it's 100 token1 and 100 token2
    const amounts = await swap.getMintAmount([web3.utils.toWei('100'), web3.utils.toWei('100')]);
    const mintAmount = amounts[0];
    const feeAmount = amounts[1];

    expect((await token1.balanceOf(user.address)).toString()).to.equals(web3.utils.toWei('100'));
    expect((await token2.balanceOf(user.address)).toString()).to.equals(web3.utils.toWei('100'));
    expect((await poolToken.balanceOf(user.address)).toString()).to.equals('0');
    expect((await poolToken.balanceOf(feeRecipient.address)).toString()).to.equals('0');
    expect((await swap.balances(0)).toString()).to.equals('0');
    expect((await swap.balances(1)).toString()).to.equals('0');
    expect((await swap.totalSupply()).toString()).to.equals((await poolToken.totalSupply()).toString());

    await swap.connect(user).mint([web3.utils.toWei('100'), web3.utils.toWei('100')], 0);
    expect((await token1.balanceOf(user.address)).toString()).to.equals('0');
    expect((await token2.balanceOf(user.address)).toString()).to.equals('0');
    expect((await poolToken.balanceOf(user.address)).toString()).to.equals(mintAmount.toString());
    expect((await poolToken.balanceOf(feeRecipient.address)).toString()).to.equals(feeAmount.toString());
    expect((await swap.balances(0)).toString()).to.equals(web3.utils.toWei('100'));
    expect((await swap.balances(1)).toString()).to.equals(web3.utils.toWei('100'));
    expect((await swap.totalSupply()).toString()).to.equals((await poolToken.totalSupply()).toString());
  });

  it("should mint the correct amount when two tokens are not equal", async () => {
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user] = await ethers.getSigners();
    await swap.unpause();
    await token1.mint(user.address, web3.utils.toWei('110'));
    await token2.mint(user.address, web3.utils.toWei('90'));
    await token1.connect(user).approve(swap.address, web3.utils.toWei('110'));
    await token2.connect(user).approve(swap.address, web3.utils.toWei('90'));

    const amounts = await swap.getMintAmount([web3.utils.toWei('110'), web3.utils.toWei('90')]);
    const mintAmount = amounts[0];
    const feeAmount = amounts[1];

    expect((await token1.balanceOf(user.address)).toString()).to.equals(web3.utils.toWei('110'));
    expect((await token2.balanceOf(user.address)).toString()).to.equals(web3.utils.toWei('90'));
    expect((await poolToken.balanceOf(user.address)).toString()).to.equals('0');
    expect((await poolToken.balanceOf(feeRecipient.address)).toString()).to.equals('0');
    expect((await swap.totalSupply()).toString()).to.equals((await poolToken.totalSupply()).toString());

    await swap.connect(user).mint([web3.utils.toWei('110'), web3.utils.toWei('90')], 0);
    expect((await token1.balanceOf(user.address)).toString()).to.equals('0');
    expect((await token2.balanceOf(user.address)).toString()).to.equals('0');
    expect((await poolToken.balanceOf(user.address)).toString()).to.equals(mintAmount.toString());
    expect((await poolToken.balanceOf(feeRecipient.address)).toString()).to.equals(feeAmount.toString());
    expect((await swap.balances(0)).toString()).to.equals(web3.utils.toWei('110'));
    expect((await swap.balances(1)).toString()).to.equals(web3.utils.toWei('90'));
    expect((await swap.totalSupply()).toString()).to.equals((await poolToken.totalSupply()).toString());
  });

  it('should return the correct mint amount with initial balance when two tokens are not equal', async () => {
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user] = await ethers.getSigners();

    await swap.unpause();
    await token1.mint(user.address, web3.utils.toWei('105'));
    await token2.mint(user.address, web3.utils.toWei('85'));
    await token1.connect(user).approve(swap.address, web3.utils.toWei('105'));
    await token2.connect(user).approve(swap.address, web3.utils.toWei('85'));
    await swap.connect(user).mint([web3.utils.toWei('105'), web3.utils.toWei('85')], 0);

    // token1 and token2 has 8 decimals, so it's 110 token1 and 90 token2
    const amounts = await swap.getMintAmount([web3.utils.toWei('110'), web3.utils.toWei('90')]);
    const mintAmount = amounts[0];
    const feeAmount = amounts[1];
    const totalAmount = mintAmount.add(feeAmount);
    assertFee(totalAmount.toString(), feeAmount.toString(), MINT_FEE);

    // Convert 110 token1 and 90 token2 to 18 decimals
    assetInvariant(web3.utils.toWei('110'), web3.utils.toWei('90'), 100, totalAmount);
  });

  it("should return the correct exchange amount", async () => {
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, user2] = await ethers.getSigners();

    await swap.unpause();
    // We use total amount to approximate D!
    const amounts = await swap.getMintAmount([web3.utils.toWei('105'), web3.utils.toWei('85')]);
    const totalAmount = amounts[0].add(amounts[1]);
    await token1.mint(user.address, web3.utils.toWei('105'));
    await token2.mint(user.address, web3.utils.toWei('85'));
    await token1.connect(user).approve(swap.address, web3.utils.toWei('105'));
    await token2.connect(user).approve(swap.address, web3.utils.toWei('85'));
    await swap.connect(user).mint([web3.utils.toWei('105'), web3.utils.toWei('85')], 0);

    await token2.mint(user2.address, web3.utils.toWei('8'));
    await token2.connect(user2).approve(swap.address, web3.utils.toWei('8'));
    const exchangeAmounts = await swap.getSwapAmount(1, 0, web3.utils.toWei('8'));
    const exchangeTotal = new BN(exchangeAmounts[0].toString()).mul(new BN(FEE_DENOMITOR)).div(new BN(FEE_DENOMITOR).sub(new BN(SWAP_FEE)));

    // Before exchange, we have 105 token1 and 85 token2
    // After exchange, 8 token2 is exchanged in so that token2 balance becomes 93
    assetInvariant(new BN(web3.utils.toWei('105')).sub(exchangeTotal.mul(new BN(PRECISION))).toString(), web3.utils.toWei('93'), 100, totalAmount);
  });

  it("should exchange the correct amount", async () => {
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, user2] = await ethers.getSigners();

    await swap.unpause();
    await token1.mint(user.address, web3.utils.toWei('105'));
    await token2.mint(user.address, web3.utils.toWei('85'));
    await token1.connect(user).approve(swap.address, web3.utils.toWei('105'));
    await token2.connect(user).approve(swap.address, web3.utils.toWei('85'));
    await swap.connect(user).mint([web3.utils.toWei('105'), web3.utils.toWei('85')], 0);

    await token2.mint(user2.address, web3.utils.toWei('8'));
    await token2.connect(user2).approve(swap.address, web3.utils.toWei('8'));
    // 8 token2
    const exchangeAmounts = await swap.getSwapAmount(1, 0, web3.utils.toWei('8'));
    const exchangeTotal = new BN(exchangeAmounts[0].toString()).mul(new BN(FEE_DENOMITOR)).div(new BN(FEE_DENOMITOR).sub(new BN(SWAP_FEE)));

    expect((await token1.balanceOf(user2.address)).toString()).to.equals('0');
    expect((await token2.balanceOf(user2.address)).toString()).to.equals(web3.utils.toWei('8'));
    expect((await token1.balanceOf(swap.address)).toString()).to.equals(web3.utils.toWei('105'));
    expect((await token2.balanceOf(swap.address)).toString()).to.equals(web3.utils.toWei('85'));
    expect((await swap.balances(0)).toString()).to.equals(web3.utils.toWei('105'));
    expect((await swap.balances(1)).toString()).to.equals(web3.utils.toWei('85'));
    expect((await swap.totalSupply()).toString()).to.equals((await poolToken.totalSupply()).toString());
    const feeBefore = new BN((await poolToken.balanceOf(feeRecipient.address)).toString());

    // Swap 8 token2 to token1
    await swap.connect(user2).swap(1, 0, web3.utils.toWei('8'), 0);
    const feeAfter = new BN((await poolToken.balanceOf(feeRecipient.address)).toString());

    // The amount of token1 got. In original format.
    expect((await token1.balanceOf(user2.address)).toString()).to.equals(exchangeAmounts[0].toString());
    expect((await token2.balanceOf(user2.address)).toString()).to.equals('0');
    // 105 token1 - actual exchange output  (in original format)
    expect((await token1.balanceOf(swap.address)).toString()).to.equals(new BN(web3.utils.toWei('105')).sub(new BN(exchangeAmounts[0].toString())).toString());
    // 85 token2 + 8 token2  (in original format)
    expect((await token2.balanceOf(swap.address)).toString()).to.equals(web3.utils.toWei('93'));
    expect(feeAfter.gte(feeBefore)).to.equals(true);
    // 85 token2 + 8 token2 (in converted format)
    expect((await swap.balances(1)).toString()).to.equals(web3.utils.toWei('93'));
    expect((await swap.totalSupply()).toString()).to.equals((await poolToken.totalSupply()).toString());
  });

  it("should return the correct redeem amount with proportional redemption", async () => {
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, user2] = await ethers.getSigners();
    await swap.unpause();
    // We use total amount to approximate D!
    const mintAmounts = await swap.getMintAmount([web3.utils.toWei('105'), web3.utils.toWei('85')]);
    const totalAmount = new BN(mintAmounts[0].add(mintAmounts[1]).toString());
    await token1.mint(user.address, web3.utils.toWei('105'));
    await token2.mint(user.address, web3.utils.toWei('85'));
    await token1.connect(user).approve(swap.address, web3.utils.toWei('105'));
    await token2.connect(user).approve(swap.address, web3.utils.toWei('85'));
    await swap.connect(user).mint([web3.utils.toWei('105'), web3.utils.toWei('85')], 0);

    const amounts = await swap.getRedeemProportionAmount(web3.utils.toWei('25'));
    const token1Amount = new BN(amounts[0][0].toString());
    const token2Amount = new BN(amounts[0][1].toString());
    const feeAmount = new BN(amounts[1].toString());

    // Assert that poolToken redeemed / poolToken total = token1 amount / token1 balance = token2 amount / token2 balance
    assertAlmostTheSame(new BN(web3.utils.toWei('25')).sub(feeAmount).mul(new BN(web3.utils.toWei('105'))), new BN(token1Amount).mul(new BN(PRECISION)).mul(totalAmount));
    assertAlmostTheSame(new BN(web3.utils.toWei('25')).sub(feeAmount).mul(new BN(web3.utils.toWei('85'))), new BN(token2Amount).mul(new BN(PRECISION)).mul(totalAmount));

    assetInvariant(new BN(web3.utils.toWei('105')).sub(token1Amount.mul(new BN(PRECISION))).toString(),
      new BN(web3.utils.toWei('85')).sub(token2Amount.mul(new BN(PRECISION))).toString(), 100, totalAmount.sub(new BN(web3.utils.toWei('25')).sub(feeAmount)).toString());
  });

  it("should redeem the correct amount with proportional redemption", async () => {
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, user2] = await ethers.getSigners();
    await swap.unpause();
    // We use total amount to approximate D!
    const mintAmounts = await swap.getMintAmount([web3.utils.toWei('105'), web3.utils.toWei('85')]);
    const totalAmount = new BN(mintAmounts[0].add(mintAmounts[1]).toString());
    await token1.mint(user.address, web3.utils.toWei('105'));
    await token2.mint(user.address, web3.utils.toWei('85'));
    await token1.connect(user).approve(swap.address, web3.utils.toWei('105'));
    await token2.connect(user).approve(swap.address, web3.utils.toWei('85'));
    await swap.connect(user).mint([web3.utils.toWei('105'), web3.utils.toWei('85')], 0);

    const amounts = await swap.getRedeemProportionAmount(web3.utils.toWei('25'));
    const token1Amount = new BN(amounts[0][0].toString());
    const token2Amount = new BN(amounts[0][1].toString());
    const feeAmount = new BN(amounts[1].toString());

    await poolToken.connect(user).transfer(user2.address, web3.utils.toWei('25'));

    expect((await token1.balanceOf(user2.address)).toString()).to.equals('0');
    expect((await token2.balanceOf(user2.address)).toString()).to.equals('0');
    expect((await poolToken.balanceOf(user2.address)).toString()).to.equals(web3.utils.toWei('25'));
    expect((await token1.balanceOf(swap.address)).toString()).to.equals(web3.utils.toWei('105'));
    expect((await token2.balanceOf(swap.address)).toString()).to.equals(web3.utils.toWei('85'));
    expect((await swap.balances(0)).toString()).to.equals(web3.utils.toWei('105'));
    expect((await swap.balances(1)).toString()).to.equals(web3.utils.toWei('85'));
    expect((await swap.totalSupply()).toString()).to.equals((await poolToken.totalSupply()).toString());

    const feeBefore = new BN((await poolToken.balanceOf(feeRecipient.address)).toString());
    // Swap 8 token2 to token1
    await poolToken.connect(user2).approve(swap.address, web3.utils.toWei('25'));
    await swap.connect(user2).redeemProportion(web3.utils.toWei('25'), [0, 0]);

    // The amount of token1 got. In original format.
    expect((await token1.balanceOf(user2.address)).toString()).to.equals(token1Amount.toString());
    expect((await token2.balanceOf(user2.address)).toString()).to.equals(token2Amount.toString());
    expect((await poolToken.balanceOf(user2.address)).toString()).to.equals('0');
    assertAlmostTheSame(new BN((await poolToken.balanceOf(feeRecipient.address)).toString()), new BN(feeAmount.add(feeBefore).toString()));
    expect((await token1.balanceOf(swap.address)).toString()).to.equals(new BN(web3.utils.toWei('105')).sub(token1Amount).toString());
    expect((await token2.balanceOf(swap.address)).toString()).to.equals(new BN(web3.utils.toWei('85')).sub(token2Amount).toString());
    assertAlmostTheSame(new BN((await swap.balances(0)).toString()), new BN(web3.utils.toWei('105')).sub(token1Amount.mul(new BN(PRECISION))));
    assertAlmostTheSame(new BN((await swap.balances(1)).toString()), new BN(web3.utils.toWei('85')).sub(token2Amount.mul(new BN(PRECISION))));
    expect((await swap.totalSupply()).toString()).to.equals((await poolToken.totalSupply()).toString());
  });

  it("should return the correct redeem amount to a single token", async () => {
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, user2] = await ethers.getSigners();

    await swap.unpause();
    // We use total amount to approximate D!
    const mintAmounts = await swap.getMintAmount([web3.utils.toWei('105'), web3.utils.toWei('85')]);
    const totalAmount = new BN(mintAmounts[0].add(mintAmounts[1]).toString());
    await token1.mint(user.address, web3.utils.toWei('105'));
    await token2.mint(user.address, web3.utils.toWei('85'));
    await token1.connect(user).approve(swap.address, web3.utils.toWei('105'));
    await token2.connect(user).approve(swap.address, web3.utils.toWei('85'));
    await swap.connect(user).mint([web3.utils.toWei('105'), web3.utils.toWei('85')], 0);

    const redeemAmount = new BN(web3.utils.toWei('25')).toString();
    const amounts = await swap.getRedeemSingleAmount(redeemAmount, 0);
    const token1Amount = new BN(amounts[0].toString());
    const feeAmount = new BN(amounts[1].toString());

    assetInvariant(new BN(web3.utils.toWei('105')).sub(token1Amount.mul(new BN(PRECISION))).toString(), web3.utils.toWei('85'), 100, totalAmount.sub(new BN(redeemAmount).sub(feeAmount)).toString());
  });

  it("should redeem the correct amount to a single token", async () => {
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, user2] = await ethers.getSigners();

    await swap.unpause();
    // We use total amount to approximate D!
    const mintAmounts = await swap.getMintAmount([web3.utils.toWei('105'), web3.utils.toWei('85')]);
    const totalAmount = mintAmounts[0].add(mintAmounts[1]);
    await token1.mint(user.address, web3.utils.toWei('105'));
    await token2.mint(user.address, web3.utils.toWei('85'));
    await token1.connect(user).approve(swap.address, web3.utils.toWei('105'));
    await token2.connect(user).approve(swap.address, web3.utils.toWei('85'));
    await swap.connect(user).mint([web3.utils.toWei('105'), web3.utils.toWei('85')], 0);

    const redeemAmount = new BN(web3.utils.toWei('25'));
    const amounts = await swap.getRedeemSingleAmount(redeemAmount.toString(), 0);
    const token1Amount = new BN(amounts[0].toString());
    const feeAmount = new BN(amounts[1].toString());

    await poolToken.connect(user).transfer(user2.address, redeemAmount.toString());

    expect((await token1.balanceOf(user2.address)).toString()).to.equals('0');
    expect((await token2.balanceOf(user2.address)).toString()).to.equals('0');
    expect((await poolToken.balanceOf(user2.address)).toString()).to.equals(redeemAmount.toString());
    expect((await token1.balanceOf(swap.address)).toString()).to.equals(web3.utils.toWei('105'));
    expect((await token2.balanceOf(swap.address)).toString()).to.equals(web3.utils.toWei('85'));
    expect((await swap.balances(0)).toString()).to.equals(web3.utils.toWei('105'));
    expect((await swap.balances(1)).toString()).to.equals(web3.utils.toWei('85'));
    expect((await swap.totalSupply()).toString()).to.equals((await poolToken.totalSupply()).toString());

    const feeBefore = new BN((await poolToken.balanceOf(feeRecipient.address)).toString());
    await poolToken.connect(user2).approve(swap.address, redeemAmount.toString());
    await swap.connect(user2).redeemSingle(redeemAmount.toString(), 0, 0);

    // The amount of token1 got. In original format.
    expect((await token1.balanceOf(user2.address)).toString()).to.equals(token1Amount.toString());
    expect((await token2.balanceOf(user2.address)).toString()).to.equals('0');
    expect((await poolToken.balanceOf(user2.address)).toString()).to.equals('0');
    expect((await poolToken.balanceOf(feeRecipient.address)).toString()).to.equals(feeAmount.add(feeBefore).toString());
    expect((await token1.balanceOf(swap.address)).toString()).to.equals(new BN(web3.utils.toWei('105')).sub(token1Amount).toString());
    expect((await token2.balanceOf(swap.address)).toString()).to.equals(new BN(web3.utils.toWei('85')).toString());
    assertAlmostTheSame(new BN((await swap.balances(0)).toString()), new BN(web3.utils.toWei('105')).sub(token1Amount.mul(new BN(PRECISION))));
    expect((await swap.balances(1)).toString()).to.equals(web3.utils.toWei('85'));
    expect((await swap.totalSupply()).toString()).to.equals((await poolToken.totalSupply()).toString());
  });

  it("should return the correct redeem amount to multiple tokens", async () => {
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, user2] = await ethers.getSigners();

    await swap.unpause();
    // We use total amount to approximate D!
    const mintAmounts = await swap.getMintAmount([web3.utils.toWei('105'), web3.utils.toWei('85')]);
    const totalAmount = mintAmounts[0].add(mintAmounts[1]);
    await token1.mint(user.address, web3.utils.toWei('105'));
    await token2.mint(user.address, web3.utils.toWei('85'));
    await token1.connect(user).approve(swap.address, web3.utils.toWei('105'));
    await token2.connect(user).approve(swap.address, web3.utils.toWei('85'));
    await swap.connect(user).mint([web3.utils.toWei('105'), web3.utils.toWei('85')], 0);

    const amounts = await swap.getRedeemMultiAmount([web3.utils.toWei('10'), web3.utils.toWei('5')]);
    const redeemAmount = amounts[0];
    const feeAmount = amounts[1];

    assertFee(redeemAmount.toString(), feeAmount.toString(), REDEEM_FEE);
    assetInvariant(web3.utils.toWei('95'), web3.utils.toWei('80'), 100, totalAmount.sub(redeemAmount.sub(feeAmount)).toString());
  });

  it("should redeem the correct amount to multiple tokens", async () => {
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, user2] = await ethers.getSigners();

    await swap.unpause();
    // We use total amount to approximate D!
    const mintAmounts = await swap.getMintAmount([web3.utils.toWei('105'), web3.utils.toWei('85')]);
    const totalAmount = mintAmounts[0].add(mintAmounts[1]);
    await token1.mint(user.address, web3.utils.toWei('105'));
    await token2.mint(user.address, web3.utils.toWei('85'));
    await token1.connect(user).approve(swap.address, web3.utils.toWei('105'));
    await token2.connect(user).approve(swap.address, web3.utils.toWei('85'));
    await swap.connect(user).mint([web3.utils.toWei('105'), web3.utils.toWei('85')], 0);

    const amounts = await swap.getRedeemMultiAmount([web3.utils.toWei('10'), web3.utils.toWei('5')]);
    const redeemAmount = amounts[0];
    const feeAmount = amounts[1];

    await poolToken.connect(user).transfer(user2.address, web3.utils.toWei('25'));

    expect((await token1.balanceOf(user2.address)).toString()).to.equals('0');
    expect((await token2.balanceOf(user2.address)).toString()).to.equals('0');
    expect((await poolToken.balanceOf(user2.address)).toString()).to.equals(web3.utils.toWei('25'));
    expect((await token1.balanceOf(swap.address)).toString()).to.equals(web3.utils.toWei('105'));
    expect((await token2.balanceOf(swap.address)).toString()).to.equals(web3.utils.toWei('85'));
    expect((await swap.balances(0)).toString()).to.equals(web3.utils.toWei('105'));
    expect((await swap.balances(1)).toString()).to.equals(web3.utils.toWei('85'));
    expect((await swap.totalSupply()).toString()).to.equals((await poolToken.totalSupply()).toString());

    const feeBefore = await poolToken.balanceOf(feeRecipient.address);
    await poolToken.connect(user2).approve(swap.address, redeemAmount);
    await swap.connect(user2).redeemMulti([web3.utils.toWei('10'), web3.utils.toWei('5')], redeemAmount);

    // The amount of token1 got. In original format.
    expect((await token1.balanceOf(user2.address)).toString()).to.equals(web3.utils.toWei('10'));
    expect((await token2.balanceOf(user2.address)).toString()).to.equals(web3.utils.toWei('5'));
    expect((await poolToken.balanceOf(user2.address)).toString()).to.equals(new BN(web3.utils.toWei('25')).sub(new BN(redeemAmount.toString())).toString());
    expect((await poolToken.balanceOf(feeRecipient.address)).toString()).to.equals(feeAmount.add(feeBefore).toString());
    expect((await token1.balanceOf(swap.address)).toString()).to.equals(web3.utils.toWei('95'));
    expect((await token2.balanceOf(swap.address)).toString()).to.equals(web3.utils.toWei('80'));
    expect((await swap.balances(0)).toString()).to.equals(web3.utils.toWei('95'));
    expect((await swap.balances(1)).toString()).to.equals(web3.utils.toWei('80'));
    expect((await swap.totalSupply()).toString()).to.equals((await poolToken.totalSupply()).toString());
  });

  it("should collect yield for rebasing tokens during mint", async () => {
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, user2, yieldRecipient] = await ethers.getSigners();
    await swap.unpause();
    await token1.mint(user.address, web3.utils.toWei('1000'));
    await token2.mint(user.address, web3.utils.toWei('1000'));
    await token1.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    await token2.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    await swap.connect(user).mint([web3.utils.toWei('100'), web3.utils.toWei('100')], 0);
    const yieldAmountBefore = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    await token1.mint(swap.address, web3.utils.toWei('10'));
    await swap.connect(user).mint([web3.utils.toWei('100'), web3.utils.toWei('100')], 0);
    const yieldAmountAfter = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    expect(yieldAmountBefore.toString()).to.equals('0');
    expect(yieldAmountAfter.gt(yieldAmountBefore)).to.equals(true);
  });

  it("should collect yield for rebasing tokens during swap", async () => {
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, user2, yieldRecipient] = await ethers.getSigners();
    await swap.unpause();
    await token1.mint(user.address, web3.utils.toWei('1000'));
    await token2.mint(user.address, web3.utils.toWei('1000'));
    await token1.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    await token2.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    await swap.connect(user).mint([web3.utils.toWei('100'), web3.utils.toWei('100')], 0);
    const yieldAmountBefore = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    await token1.mint(swap.address, web3.utils.toWei('10'));
    await swap.connect(user).swap(0, 1, web3.utils.toWei('1'), '0');
    const yieldAmountAfter = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    expect(yieldAmountBefore.toString()).to.equals('0');
    expect(yieldAmountAfter.gt(yieldAmountBefore)).to.equals(true);
  });

  it("should collect yield for rebasing tokens during redeem proportion", async () => {
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, user2, yieldRecipient] = await ethers.getSigners();
    await swap.unpause();
    await token1.mint(user.address, web3.utils.toWei('1000'));
    await token2.mint(user.address, web3.utils.toWei('1000'));
    await token1.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    await token2.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    await poolToken.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    await swap.connect(user).mint([web3.utils.toWei('100'), web3.utils.toWei('100')], 0);
    const yieldAmountBefore = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    await token1.mint(swap.address, web3.utils.toWei('10'));
    await swap.connect(user).redeemProportion(web3.utils.toWei('1'), ['0', '0']);
    const yieldAmountAfter = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    expect(yieldAmountBefore.toString()).to.equals('0');
    expect(yieldAmountAfter.gt(yieldAmountBefore)).to.equals(true);
  });

  it("should collect yield for rebasing tokens during redeem single", async () => {
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, user2, yieldRecipient] = await ethers.getSigners();
    await swap.unpause();
    await token1.mint(user.address, web3.utils.toWei('1000'));
    await token2.mint(user.address, web3.utils.toWei('1000'));
    await token1.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    await token2.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    await poolToken.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    await swap.connect(user).mint([web3.utils.toWei('100'), web3.utils.toWei('100')], 0);
    const yieldAmountBefore = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    await token1.mint(swap.address, web3.utils.toWei('10'));
    await swap.connect(user).redeemSingle(web3.utils.toWei('1'), '0', '0');
    const yieldAmountAfter = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    expect(yieldAmountBefore.toString()).to.equals('0');
    expect(yieldAmountAfter.gt(yieldAmountBefore)).to.equals(true);
  });

  it("should collect yield for rebasing tokens during redeem multi", async () => {
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, user2, yieldRecipient] = await ethers.getSigners();
    await swap.unpause();
    await token1.mint(user.address, web3.utils.toWei('1000'));
    await token2.mint(user.address, web3.utils.toWei('1000'));
    await token1.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    await token2.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    await poolToken.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    await swap.connect(user).mint([web3.utils.toWei('100'), web3.utils.toWei('100')], 0);
    const yieldAmountBefore = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    await token1.mint(swap.address, web3.utils.toWei('10'));
    await swap.connect(user).redeemMulti([web3.utils.toWei('1'), web3.utils.toWei('1')], web3.utils.toWei('100'));
    const yieldAmountAfter = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    expect(yieldAmountBefore.toString()).to.equals('0');
    expect(yieldAmountAfter.gt(yieldAmountBefore)).to.equals(true);
  });

  it("should return the correct redeem amount to multiple tokens rebasing", async () => {
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, user2] = await ethers.getSigners();

    await swap.unpause();
    // We use total amount to approximate D!
    const mintAmounts = await swap.getMintAmount([web3.utils.toWei('105'), web3.utils.toWei('85')]);
    const totalAmount = mintAmounts[0].add(mintAmounts[1]);
    await token1.mint(user.address, web3.utils.toWei('105'));
    await token2.mint(user.address, web3.utils.toWei('85'));
    await token1.connect(user).approve(swap.address, web3.utils.toWei('105'));
    await token2.connect(user).approve(swap.address, web3.utils.toWei('85'));
    await swap.connect(user).mint([web3.utils.toWei('105'), web3.utils.toWei('85')], 0);

    await token1.mint(swap.address, web3.utils.toWei('10'));
    const amounts = await swap.getRedeemMultiAmount([web3.utils.toWei('10'), web3.utils.toWei('5')]);
    const redeemAmount = amounts[0];
    const feeAmount = amounts[1];

    assertFee(redeemAmount.toString(), feeAmount.toString(), REDEEM_FEE);
    assetInvariant(web3.utils.toWei('95'), web3.utils.toWei('80'), 100, totalAmount.sub(redeemAmount.sub(feeAmount)).toString());
  });

  it("should return the correct redeem amount to a single token rebasing", async () => {
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, user2] = await ethers.getSigners();

    await swap.unpause();
    // We use total amount to approximate D!
    const mintAmounts = await swap.getMintAmount([web3.utils.toWei('105'), web3.utils.toWei('85')]);
    const totalAmount = new BN(mintAmounts[0].add(mintAmounts[1]).toString());
    await token1.mint(user.address, web3.utils.toWei('105'));
    await token2.mint(user.address, web3.utils.toWei('85'));
    await token1.connect(user).approve(swap.address, web3.utils.toWei('105'));
    await token2.connect(user).approve(swap.address, web3.utils.toWei('85'));
    await swap.connect(user).mint([web3.utils.toWei('105'), web3.utils.toWei('85')], 0);

    await token1.mint(swap.address, web3.utils.toWei('10'));
    const redeemAmount = new BN(web3.utils.toWei('25')).toString();
    const amounts = await swap.getRedeemSingleAmount(redeemAmount, 0);
    const token1Amount = new BN(amounts[0].toString());
    const feeAmount = new BN(amounts[1].toString());

    assetInvariant(new BN(web3.utils.toWei('105')).sub(token1Amount.mul(new BN(PRECISION))).toString(), web3.utils.toWei('85'), 100, totalAmount.sub(new BN(redeemAmount).sub(feeAmount)).toString());
  });

  it("should return the correct redeem amount with proportional redemption rebasing", async () => {
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, user2] = await ethers.getSigners();
    await swap.unpause();
    // We use total amount to approximate D!
    const mintAmounts = await swap.getMintAmount([web3.utils.toWei('105'), web3.utils.toWei('85')]);
    await token1.mint(user.address, web3.utils.toWei('105'));
    await token2.mint(user.address, web3.utils.toWei('85'));
    await token1.connect(user).approve(swap.address, web3.utils.toWei('105'));
    await token2.connect(user).approve(swap.address, web3.utils.toWei('85'));
    await swap.connect(user).mint([web3.utils.toWei('105'), web3.utils.toWei('85')], 0);

    await token1.mint(swap.address, web3.utils.toWei('10'));
    const amounts = await swap.getRedeemProportionAmount(web3.utils.toWei('25'));
    const token1Amount = new BN(amounts[0][0].toString());
    const token2Amount = new BN(amounts[0][1].toString());
    const feeAmount = new BN(amounts[1].toString());
    const totalAmount = new BN(amounts[2].toString());

    // Assert that poolToken redeemed / poolToken total = token1 amount / token1 balance = token2 amount / token2 balance
    assertAlmostTheSame(new BN(web3.utils.toWei('25')).sub(feeAmount).mul(new BN(web3.utils.toWei('115'))), new BN(token1Amount).mul(new BN(PRECISION)).mul(totalAmount));
    assertAlmostTheSame(new BN(web3.utils.toWei('25')).sub(feeAmount).mul(new BN(web3.utils.toWei('85'))), new BN(token2Amount).mul(new BN(PRECISION)).mul(totalAmount));

    assetInvariant(new BN(web3.utils.toWei('105')).sub(token1Amount.mul(new BN(PRECISION))).toString(),
      new BN(web3.utils.toWei('85')).sub(token2Amount.mul(new BN(PRECISION))).toString(), 100, totalAmount.sub(new BN(web3.utils.toWei('25')).sub(feeAmount)).toString());
  });

  it("should return the correct exchange amount rebasing", async () => {
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, user2] = await ethers.getSigners();

    await swap.unpause();
    // We use total amount to approximate D!
    const amounts = await swap.getMintAmount([web3.utils.toWei('105'), web3.utils.toWei('85')]);
    const totalAmount = amounts[0].add(amounts[1]);
    await token1.mint(user.address, web3.utils.toWei('105'));
    await token2.mint(user.address, web3.utils.toWei('85'));
    await token1.connect(user).approve(swap.address, web3.utils.toWei('105'));
    await token2.connect(user).approve(swap.address, web3.utils.toWei('85'));
    await swap.connect(user).mint([web3.utils.toWei('105'), web3.utils.toWei('85')], 0);

    await token2.mint(user2.address, web3.utils.toWei('8'));
    await token2.connect(user2).approve(swap.address, web3.utils.toWei('8'));
    await token1.mint(swap.address, web3.utils.toWei('10'));
    const exchangeAmounts = await swap.getSwapAmount(1, 0, web3.utils.toWei('8'));
    const exchangeTotal = new BN(exchangeAmounts[0].toString()).mul(new BN(FEE_DENOMITOR)).div(new BN(FEE_DENOMITOR).sub(new BN(SWAP_FEE)));

    // Before exchange, we have 105 token1 and 85 token2
    // After exchange, 8 token2 is exchanged in so that token2 balance becomes 93
    assetInvariant(new BN(web3.utils.toWei('105')).sub(exchangeTotal.mul(new BN(PRECISION))).toString(), web3.utils.toWei('93'), 100, totalAmount);
  });

  it('should return the correct mint amount when two tokens are not equal rebasing', async () => {
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    await token1.mint(swap.address, web3.utils.toWei('10'));
    await token2.mint(swap.address, web3.utils.toWei('10'));
    
    const amounts = await swap.getMintAmount([web3.utils.toWei('110'), web3.utils.toWei('90')]);
    const mintAmount = amounts[0];
    const feeAmount = amounts[1];
    const totalAmount = mintAmount.add(feeAmount);
    assertFee(totalAmount.toString(), feeAmount.toString(), MINT_FEE);
    assetInvariant(web3.utils.toWei('100'), web3.utils.toWei('100'), 100, web3.utils.toWei('200'));
  });

  it('should return the correct mint amount when two tokens are equal rebasing', async () => {
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    await token1.mint(swap.address, web3.utils.toWei('10'));
    await token2.mint(swap.address, web3.utils.toWei('10'));
    
    const amounts = await swap.getMintAmount([web3.utils.toWei('100'), web3.utils.toWei('100')]);
    const mintAmount = amounts[0];
    const feeAmount = amounts[1];
    const totalAmount = mintAmount.add(feeAmount);
    expect(totalAmount.toString()).to.equals(web3.utils.toWei('200'));
    assertFee(totalAmount.toString(), feeAmount.toString(), MINT_FEE);
    assetInvariant(web3.utils.toWei('100'), web3.utils.toWei('100'), 100, web3.utils.toWei('200'));
  });

  it("should collect yield for exchange rate tokens during mint", async () => {
    const { swap, token1, token2, poolToken, exchangeRate, exchangeRateToken } = await loadFixture(deploySwapAndTokensExchangeRate);
    const [owner, feeRecipient, user, user2, yieldRecipient] = await ethers.getSigners();
    await swap.unpause();
    await token1.mint(user.address, web3.utils.toWei('1000'));
    await token2.mint(user.address, web3.utils.toWei('1000'));
    await token1.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    await token2.connect(user).approve(exchangeRateToken.address, web3.utils.toWei('1000'));

    await swap.connect(user).mint([web3.utils.toWei('100'), web3.utils.toWei('100')], 0);
    const yieldAmountBefore = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    await exchangeRate.newRate("1100000000000000000");
    await swap.connect(user).mint([web3.utils.toWei('100'), web3.utils.toWei('100')], 0);
    const yieldAmountAfter = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    expect(yieldAmountBefore.toString()).to.equals('0');
    expect(yieldAmountAfter.gt(yieldAmountBefore)).to.equals(true);
  });

  it("should collect yield for exchange rate tokens during swap", async () => {
    const { swap, token1, token2, poolToken, exchangeRate, exchangeRateToken } = await loadFixture(deploySwapAndTokensExchangeRate);
    const [owner, feeRecipient, user, user2, yieldRecipient] = await ethers.getSigners();
    await swap.unpause();
    await token1.mint(user.address, web3.utils.toWei('1000'));
    await token2.mint(user.address, web3.utils.toWei('1000'));
    await token1.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    await token2.connect(user).approve(exchangeRateToken.address, web3.utils.toWei('1000'));
    await swap.connect(user).mint([web3.utils.toWei('100'), web3.utils.toWei('100')], 0);
    const yieldAmountBefore = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    await exchangeRate.newRate("1100000000000000000");
    await swap.connect(user).swap(0, 1, web3.utils.toWei('1'), '0');
    const yieldAmountAfter = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    expect(yieldAmountBefore.toString()).to.equals('0');
    expect(yieldAmountAfter.gt(yieldAmountBefore)).to.equals(true);
  });

  it("should collect yield for exchange rate tokens during redeem proportion", async () => {
    const { swap, token1, token2, poolToken, exchangeRate, exchangeRateToken } = await loadFixture(deploySwapAndTokensExchangeRate);
    const [owner, feeRecipient, user, user2, yieldRecipient] = await ethers.getSigners();
    await swap.unpause();
    await token1.mint(user.address, web3.utils.toWei('1000'));
    await token2.mint(user.address, web3.utils.toWei('1000'));
    await token1.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    await token2.connect(user).approve(exchangeRateToken.address, web3.utils.toWei('1000'));
    await poolToken.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    await swap.connect(user).mint([web3.utils.toWei('100'), web3.utils.toWei('100')], 0);
    const yieldAmountBefore = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    await exchangeRate.newRate("1100000000000000000");
    await swap.connect(user).redeemProportion(web3.utils.toWei('1'), ['0', '0']);
    const yieldAmountAfter = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    expect(yieldAmountBefore.toString()).to.equals('0');
    expect(yieldAmountAfter.gt(yieldAmountBefore)).to.equals(true);
  });

  it("should collect yield for exchange rate tokens during redeem single", async () => {
    const { swap, token1, token2, poolToken, exchangeRate, exchangeRateToken } = await loadFixture(deploySwapAndTokensExchangeRate);
    const [owner, feeRecipient, user, user2, yieldRecipient] = await ethers.getSigners();
    await swap.unpause();
    await token1.mint(user.address, web3.utils.toWei('1000'));
    await token2.mint(user.address, web3.utils.toWei('1000'));
    await token1.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    await token2.connect(user).approve(exchangeRateToken.address, web3.utils.toWei('1000'));
    await poolToken.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    await swap.connect(user).mint([web3.utils.toWei('100'), web3.utils.toWei('100')], 0);
    const yieldAmountBefore = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    await exchangeRate.newRate("1100000000000000000");
    await swap.connect(user).redeemSingle(web3.utils.toWei('1'), '1', '0');
    const yieldAmountAfter = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    expect(yieldAmountBefore.toString()).to.equals('0');
    expect(yieldAmountAfter.gt(yieldAmountBefore)).to.equals(true);
  });

  it("should collect yield for exchange rate tokens during redeem multi", async () => {
    const { swap, token1, token2, poolToken, exchangeRate, exchangeRateToken } = await loadFixture(deploySwapAndTokensExchangeRate);
    const [owner, feeRecipient, user, user2, yieldRecipient] = await ethers.getSigners();
    await swap.unpause();
    await token1.mint(user.address, web3.utils.toWei('1000'));
    await token2.mint(user.address, web3.utils.toWei('1000'));
    await token1.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    await token2.connect(user).approve(exchangeRateToken.address, web3.utils.toWei('1000'));
    await poolToken.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    await swap.connect(user).mint([web3.utils.toWei('100'), web3.utils.toWei('100')], 0);
    const yieldAmountBefore = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    await exchangeRate.newRate("1100000000000000000");
    await swap.connect(user).redeemMulti([web3.utils.toWei('1'), web3.utils.toWei('1')], web3.utils.toWei('100'));
    const yieldAmountAfter = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    expect(yieldAmountBefore.toString()).to.equals('0');
    expect(yieldAmountAfter.gt(yieldAmountBefore)).to.equals(true);
  });

  it("should allow to update governance", async () => {
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, admin] = await ethers.getSigners();
    await expect(swap.connect(admin).setGovernance(user.address)).to.be.revertedWith("not governance");
    await swap.setGovernance(user.address);
    expect(await swap.governance()).to.equals(user.address);
  });

  it("should allow to update mint fee", async () => {
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, admin] = await ethers.getSigners();
    await expect(swap.connect(admin).setMintFee('1000')).to.be.revertedWith("not governance");
    swap.setMintFee('1000');
    expect((await swap.mintFee()).toString()).to.equals('1000');
  });

  it("should allow to update swap fee", async () => {
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    swap.setSwapFee('1000');
    expect((await swap.swapFee()).toString()).to.equals('1000');
  });

  it("should allow to update redeem fee", async () => {
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    swap.setRedeemFee('1000');
    expect((await swap.redeemFee()).toString()).to.equals('1000');
  });

  it("should allow to pause and unpause", async () => {
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, admin] = await ethers.getSigners();
    await expect(swap.connect(admin).pause()).to.be.revertedWith("not governance");
    await expect(swap.pause()).to.be.revertedWith("paused");
    await swap.unpause();
    expect(await swap.paused()).to.equals(false);
    await expect(swap.connect(admin).unpause()).to.be.revertedWith("not governance");
    await expect(swap.unpause()).to.be.revertedWith("not paused");
    await swap.pause();
    expect(await swap.paused()).to.equals(true);
  });

  it("setFeeRecipient should work", async () => {
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, admin] = await ethers.getSigners();

    expect(await swap.feeRecipient()).to.be.equals(feeRecipient.address);

    await expect(swap.connect(admin).setFeeRecipient(ethers.constants.AddressZero)).to.be.revertedWith("not governance");
    await expect(swap.setFeeRecipient(ethers.constants.AddressZero)).to.be.revertedWith("fee recipient not set");

    await swap.setFeeRecipient(user.address);
    expect(await swap.feeRecipient()).to.be.equals(user.address);
  });

  it("setPoolToken should work", async () => {
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, admin] = await ethers.getSigners();

    expect(await swap.poolToken()).to.equals(poolToken.address);

    await expect(swap.connect(admin).setPoolToken(ethers.constants.AddressZero)).to.be.revertedWith("not governance");
    await expect(swap.setPoolToken(ethers.constants.AddressZero)).to.be.revertedWith("pool token not set");

    await swap.setPoolToken(token2.address);
    expect(await swap.poolToken()).to.be.equals(token2.address);
  });

  it("setAdmin should work", async () => {
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, admin] = await ethers.getSigners();

    expect(await swap.admins(admin.address)).to.equals(false);

    await expect(swap.connect(user).setAdmin(ethers.constants.AddressZero, true)).to.be.revertedWith("not governance");
    await expect(swap.setAdmin(ethers.constants.AddressZero, true)).to.be.revertedWith("account not set");

    await swap.setAdmin(admin.address, true);
    expect(await swap.admins(admin.address)).to.equals(true);

    await swap.setAdmin(admin.address, false);
    expect(await swap.admins(admin.address)).to.equals(false);
  });

  it("updateA should work", async () => {
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, admin] = await ethers.getSigners();
    expect(await swap.initialA()).to.equals(100);
    expect(await swap.initialABlock()).to.equals(7);
    expect(await swap.futureA()).to.equals(100);
    expect(await swap.futureABlock()).to.equals(7);

    await expect(swap.connect(admin).updateA(1000, 20)).to.be.revertedWith("not governance");

    await expect(swap.updateA(1000, 7)).to.be.revertedWith("block in the past");

    expect(await ethers.provider.getBlockNumber()).to.be.equals(12);
    await expect(swap.updateA(0, 12)).to.be.revertedWith("A not set");

    expect(await ethers.provider.getBlockNumber()).to.be.equals(13);
    await expect(swap.updateA(1000000, 13)).to.be.revertedWith("A not set");

    expect(await ethers.provider.getBlockNumber()).to.be.equals(14);
    await swap.updateA(1000, 16); // need extra block to update
    expect(await swap.initialA()).to.equals(100);
    expect(await swap.initialABlock()).to.equals(15);
    expect(await swap.futureA()).to.equals(1000);
    expect(await swap.futureABlock()).to.equals(16);
  });

  it("getA should work", async () => {
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, user2] = await ethers.getSigners();

    expect(await swap.initialA()).to.equals(100);
    expect(await swap.initialABlock()).to.equals(7);
    expect(await swap.getA()).to.equals(100);

    await swap.updateA(1000, 100);
    expect(await swap.initialA()).to.equals(100);
    expect(await swap.initialABlock()).to.equals(11);
    expect(await swap.futureA()).to.equals(1000);
    expect(await swap.futureABlock()).to.equals(100);
    expect(await swap.getA()).to.equals(100);

    const hre = await import("hardhat");

    await hre.network.provider.request({
      method: "hardhat_mine",
      params: [ethers.utils.hexlify(50)]
    });
    expect(await ethers.provider.getBlockNumber()).to.be.equals(61);
    expect(await swap.getA()).to.equals(605);

    await hre.network.provider.request({
      method: "hardhat_mine",
      params: [ethers.utils.hexlify(38)]
    });
    expect(await ethers.provider.getBlockNumber()).to.be.equals(99);
    expect(await swap.getA()).to.equals(989);

    await hre.network.provider.request({
      method: "hardhat_mine",
      params: [ethers.utils.hexStripZeros(ethers.utils.hexlify(1))]
    });
    expect(await ethers.provider.getBlockNumber()).to.be.equals(100);
    expect(await swap.getA()).to.equals(1000);
    await hre.network.provider.request({
      method: "hardhat_mine",
      params: [ethers.utils.hexStripZeros(ethers.utils.hexlify(1))]
    });
    expect(await swap.getA()).to.equals(1000);

    expect(await ethers.provider.getBlockNumber()).to.be.equals(101);
    await swap.updateA(500, 200);
    await hre.network.provider.request({
      method: "hardhat_mine",
      params: [ethers.utils.hexStripZeros(ethers.utils.hexlify(40))]
    });
    expect(await ethers.provider.getBlockNumber()).to.be.equals(142);
    expect(await swap.getA()).to.equals(796);

    await hre.network.provider.request({
      method: "hardhat_mine",
      params: [ethers.utils.hexlify(57)]
    });
    expect(await ethers.provider.getBlockNumber()).to.be.equals(199);
    expect(await swap.getA()).to.equals(506);
    await hre.network.provider.request({
      method: "hardhat_mine",
      params: [ethers.utils.hexStripZeros(ethers.utils.hexlify(1))]
    });
    expect(await ethers.provider.getBlockNumber()).to.be.equals(200);
    expect(await swap.getA()).to.equals(500);
    await hre.network.provider.request({
      method: "hardhat_mine",
      params: [ethers.utils.hexStripZeros(ethers.utils.hexlify(1))]
    });
    expect(await ethers.provider.getBlockNumber()).to.be.equals(201);
    expect(await swap.getA()).to.equals(500);
  });
});
