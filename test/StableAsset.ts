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

    const StableAsset = await ethers.getContractFactory("StableAsset");
    const MockToken = await ethers.getContractFactory("MockToken");
    const StableAssetToken = await ethers.getContractFactory("StableAssetToken");
    const ConstantExchangeRateProvider = await ethers.getContractFactory("ConstantExchangeRateProvider");

    /// Deploy token1 with name "test 1", symbol "T1", decimals 18
    const token1 = await MockToken.deploy("test 1", "T1", 18);
    /// Deploy token2 with name "test 2", symbol "T2", decimals 18
    const token2 = await MockToken.deploy("test 2", "T2", 18);
    /// Deploy pool token with name "Pool Token", symbol "PT", decimals 18
    const poolToken = await upgrades.deployProxy(StableAssetToken, ["Pool Token", "PT"]);
    /// Deploy constant exchange rate provider with exchange rate 1
    const constant = await ConstantExchangeRateProvider.deploy();

    /// Deploy swap contract with [token1, token2], [PRECISION, PRECISION], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeRecipient, yieldRecipient, poolToken, A = 100 and ConstantExchangeRate
    const swap = await upgrades.deployProxy(StableAsset, [[token1.address, token2.address], [PRECISION, PRECISION], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeRecipient.address, yieldRecipient.address, poolToken.address, 100, constant.address, 1]);
    /// Set swap as minter of pool token
    await poolToken.setMinter(swap.address, true);

    return { swap, token1, token2, poolToken };
  }

  async function deploySwapAndTokensExchangeRate() {
    // Contracts are deployed using the first signer/account by default
    const [owner, feeRecipient, user, user2, yieldRecipient] = await ethers.getSigners();

    const StableAsset = await ethers.getContractFactory("StableAsset");
    const MockToken = await ethers.getContractFactory("MockToken");
    const StableAssetToken = await ethers.getContractFactory("StableAssetToken");
    const MockTokenWithExchangeRate = await ethers.getContractFactory("MockExchangeRateProvider");

    /// Deploy token1 with name "test 1", symbol "T1", decimals 18
    const token1 = await MockToken.deploy("test 1", "T1", 18);
    /// Deploy token2 with name "test 2", symbol "T2", decimals 18
    const token2 = await MockToken.deploy("test 2", "T2", 18);
    /// Deploy MockTokenWithExchangeRate with exchange rate 1 and decimals 18
    const exchangeRate = await MockTokenWithExchangeRate.deploy("1000000000000000000", '18');
    /// Deploy pool token with name "Pool Token", symbol "PT", decimals 18
    const poolToken = await upgrades.deployProxy(StableAssetToken, ["Pool Token", "PT"]);

    /// Deploy swap contract with [token1, token2], [PRECISION, PRECISION], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeRecipient, yieldRecipient, poolToken, and A = 100
    const swap = await upgrades.deployProxy(StableAsset, [[token1.address, token2.address], [PRECISION, PRECISION], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeRecipient.address, yieldRecipient.address, poolToken.address, 100, exchangeRate.address, 1]);
    /// Set swap as minter of pool token
    await poolToken.setMinter(swap.address, true);

    return { swap, token1, token2, poolToken, exchangeRate };
  }

  it("should initialize paramters", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient] = await ethers.getSigners();

    /// Check swap tokens[0] is token1
    expect(await swap.tokens(0)).to.equal(token1.address);
    /// Check swap tokens[1] is token2
    expect(await swap.tokens(1)).to.equal(token2.address);
    /// Check swap precisions[0] is PRECISION
    expect((await swap.precisions(0)).toString()).to.equal(PRECISION);
    /// Check swap precisions[1] is PRECISION
    expect((await swap.precisions(1)).toString()).to.equal(PRECISION);
    /// Check swap mintFee is MINT_FEE
    expect((await swap.mintFee()).toString()).to.equal(MINT_FEE);
    /// Check swap swapFee is SWAP_FEE
    expect((await swap.swapFee()).toString()).to.equal(SWAP_FEE);
    /// Check swap redeemFee is REDEEM_FEE
    expect((await swap.redeemFee()).toString()).to.equal(REDEEM_FEE);
    /// Check swap poolToken is poolToken
    expect(await swap.poolToken()).to.equal(poolToken.address);
    /// Check swap feeRecipient is feeRecipient
    expect(await swap.feeRecipient()).to.equal(feeRecipient.address);
    /// Check swap governance is owner
    expect(await swap.governance()).to.equal(owner.address);
    /// Check swap paused is true
    expect(await swap.paused()).to.equal(true);
    /// Check swap initialA is 100
    expect((await swap.initialA()).toNumber()).to.equal(100);
  });

  it("should not initialize paramters", async () => {
    // Contracts are deployed using the first signer/account by default
    const [owner, feeRecipient, user, user2, yieldRecipient] = await ethers.getSigners();

    const StableAsset = await ethers.getContractFactory("StableAsset");
    const MockToken = await ethers.getContractFactory("MockToken");
    const StableAssetToken = await ethers.getContractFactory("StableAssetToken");
    const ConstantExchangeRateProvider = await ethers.getContractFactory("ConstantExchangeRateProvider");
    const constant = await ConstantExchangeRateProvider.deploy();

    /// Deploy token1 with name "test 1", symbol "T1", decimals 18
    const token1 = await MockToken.deploy("test 1", "T1", 18);
    /// Deploy token2 with name "test 2", symbol "T2", decimals 18
    const token2 = await MockToken.deploy("test 2", "T2", 18);
    /// Deploy pool token with name "test 17", symbol "T17", decimals 17
    const token17 = await MockToken.deploy("test 17", "T17", 17);
    /// Deploy pool token with name "test 19", symbol "T19", decimals 19
    const token19 = await MockToken.deploy("test 19", "T19", 19);
    /// Deploy pool token with name "Pool Token", symbol "PT", decimals 18
    const poolToken = await upgrades.deployProxy(StableAssetToken, ["Pool Token", "PT"]);

    /// Check deploy swap with no tokens
    await expect(upgrades.deployProxy(StableAsset, [[], [], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeRecipient.address, yieldRecipient.address, poolToken.address, 100, constant.address, 1]))
      .to.be.revertedWith("input mismatch");

    /// Check deploy swap with token length not match
    await expect(upgrades.deployProxy(StableAsset, [[], [PRECISION, PRECISION], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeRecipient.address, yieldRecipient.address, poolToken.address, 100, constant.address, 1]))
      .to.be.revertedWith("input mismatch");

    /// Check deploy swap with fee length not match
    await expect(upgrades.deployProxy(StableAsset, [[token1.address, token2.address], [PRECISION, PRECISION], [MINT_FEE, SWAP_FEE], feeRecipient.address, yieldRecipient.address, poolToken.address, 0, constant.address, 1]))
      .to.be.revertedWith("no fees");

    /// Check deploy swap with token not set
    await expect(upgrades.deployProxy(StableAsset, [[token1.address, ethers.constants.AddressZero], [PRECISION, PRECISION], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeRecipient.address, yieldRecipient.address, poolToken.address, 0, constant.address, 1]))
      .to.be.revertedWith("token not set");

    await expect(upgrades.deployProxy(StableAsset, [[token1.address, token2.address], [PRECISION, 10], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeRecipient.address, yieldRecipient.address, poolToken.address, 0, constant.address, 1])).to.be.revertedWith("precision not set");

    await expect(upgrades.deployProxy(StableAsset, [[token1.address, token17.address], [PRECISION, "10000000000000000"], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeRecipient.address, yieldRecipient.address, poolToken.address, 0, constant.address, 1])).to.be.revertedWith("precision not set");

    await expect(upgrades.deployProxy(StableAsset, [[token1.address, token19.address], [1, "1000000000000000000"], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeRecipient.address, yieldRecipient.address, poolToken.address, 0, constant.address, 1])).to.be.revertedWithPanic(0x11);

    /// Check deploy swap with fee recipient not set
    await expect(upgrades.deployProxy(StableAsset, [[token1.address, token2.address], [PRECISION, PRECISION], [MINT_FEE, SWAP_FEE, REDEEM_FEE], ethers.constants.AddressZero, yieldRecipient.address, poolToken.address, 0, constant.address, 1]))
      .to.be.revertedWith("fee recipient not set");

    /// Check deploy swap with yield recipient not set
    await expect(upgrades.deployProxy(StableAsset, [[token1.address, token2.address], [PRECISION, PRECISION], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeRecipient.address, ethers.constants.AddressZero, poolToken.address, 0, constant.address, 1]))
      .to.be.revertedWith("yield recipient not set");

    /// Check deploy swap with pool token not set
    await expect(upgrades.deployProxy(StableAsset, [[token1.address, token2.address], [PRECISION, PRECISION], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeRecipient.address, yieldRecipient.address, ethers.constants.AddressZero, 0, constant.address, 1]))
      .to.be.revertedWith("pool token not set");

    /// Check deploy swap with A not set
    await expect(upgrades.deployProxy(StableAsset, [[token1.address, token2.address], [PRECISION, PRECISION], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeRecipient.address, yieldRecipient.address, poolToken.address, 0, constant.address, 1]))
      .to.be.revertedWith("A not set");

    /// Check deploy swap with A exceed max
    await expect(upgrades.deployProxy(StableAsset, [[token1.address, token2.address], [PRECISION, PRECISION], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeRecipient.address, yieldRecipient.address, poolToken.address, 1000000, constant.address, 1]))
      .to.be.revertedWith("A not set");
  });

  it('should return the correct mint amount when two tokens are equal', async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient] = await ethers.getSigners();

    /// Get mint amount with 100 token1 and 100 token2
    const amounts = await swap.getMintAmount([web3.utils.toWei('100'), web3.utils.toWei('100')]);
    /// Check amounts[0] is mint amount
    const mintAmount = amounts[0];
    /// Check amounts[1] is fee amount
    const feeAmount = amounts[1];
    /// Check total amount is correct
    const totalAmount = mintAmount.add(feeAmount);
    /// Check total amount is 200
    expect(totalAmount.toString()).to.equals(web3.utils.toWei('200'));
    /// Check fee amount is correct
    assertFee(totalAmount.toString(), feeAmount.toString(), MINT_FEE);
    /// Check invariant after mint
    assetInvariant(web3.utils.toWei('100'), web3.utils.toWei('100'), 100, web3.utils.toWei('200'));
  });

  it('should return the correct mint amount when two tokens are not equal', async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    /// Get mint amount when token1 is 110 and token2 is 90
    const amounts = await swap.getMintAmount([web3.utils.toWei('110'), web3.utils.toWei('90')]);
    /// Check amounts[0] is mint amount
    const mintAmount = amounts[0];
    /// Check amounts[1] is fee amount
    const feeAmount = amounts[1];
    /// Check total amount is correct
    const totalAmount = mintAmount.add(feeAmount);
    /// Check total amount is 200
    assertFee(totalAmount.toString(), feeAmount.toString(), MINT_FEE);
    /// Check invariant after mint 
    assetInvariant(web3.utils.toWei('100'), web3.utils.toWei('100'), 100, web3.utils.toWei('200'));
  });

  it("should mint the correct amount when two tokens are equal", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user] = await ethers.getSigners();
    /// Unpause swap contract
    await swap.unpause();
    /// Mint 100 token1 to user
    await token1.mint(user.address, web3.utils.toWei('100'));
    /// Mint 100 token2 to user
    await token2.mint(user.address, web3.utils.toWei('100'));
    /// Approve swap contract to spend 100 token1
    await token1.connect(user).approve(swap.address, web3.utils.toWei('100'));
    /// Approve swap contract to spend 100 token2
    await token2.connect(user).approve(swap.address, web3.utils.toWei('100'));

    /// Get mint amount with 100 token1 and 100 token2
    // token1 and token2 has 8 decimals, so it's 100 token1 and 100 token2
    const amounts = await swap.getMintAmount([web3.utils.toWei('100'), web3.utils.toWei('100')]);
    /// Check amounts[0] is mint amount
    const mintAmount = amounts[0];
    /// Check amounts[1] is fee amount
    const feeAmount = amounts[1];

    /// Check token1 balance is 100
    expect((await token1.balanceOf(user.address)).toString()).to.equals(web3.utils.toWei('100'));
    /// Check token2 balance is 100
    expect((await token2.balanceOf(user.address)).toString()).to.equals(web3.utils.toWei('100'));
    /// Check pool token balance is 0
    expect((await poolToken.balanceOf(user.address)).toString()).to.equals('0');
    /// Check fee recipient balance is 0
    expect((await poolToken.balanceOf(feeRecipient.address)).toString()).to.equals('0');
    /// Check swap token1 balance is 0
    expect((await swap.balances(0)).toString()).to.equals('0');
    /// Check swap token2 balance is 0
    expect((await swap.balances(1)).toString()).to.equals('0');
    /// Check swap total supply is 0
    expect((await swap.totalSupply()).toString()).to.equals((await poolToken.totalSupply()).toString());

    /// Mint 100 token1 and 100 token2 to pool token
    await swap.connect(user).mint([web3.utils.toWei('100'), web3.utils.toWei('100')], 0);
    /// Check token1 balance is 0
    expect((await token1.balanceOf(user.address)).toString()).to.equals('0');
    /// Check token2 balance is 0
    expect((await token2.balanceOf(user.address)).toString()).to.equals('0');
    /// Check pool token balance is mint amount
    expect((await poolToken.balanceOf(user.address)).toString()).to.equals(mintAmount.toString());
    /// Check fee recipient balance is fee amount
    expect((await poolToken.balanceOf(feeRecipient.address)).toString()).to.equals(feeAmount.toString());
    /// Check swap token1 balance is 100
    expect((await swap.balances(0)).toString()).to.equals(web3.utils.toWei('100'));
    /// Check swap token2 balance is 100
    expect((await swap.balances(1)).toString()).to.equals(web3.utils.toWei('100'));
    /// Check swap total supply is 200
    expect((await swap.totalSupply()).toString()).to.equals(web3.utils.toWei('200'));
    /// Check pool token total supply is 200
    expect((await swap.totalSupply()).toString()).to.equals((await poolToken.totalSupply()).toString());
  });

  it("should mint the correct amount when two tokens are not equal", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user] = await ethers.getSigners();
    /// Unpause swap contract
    await swap.unpause();
    /// Mint 110 token1 to user
    await token1.mint(user.address, web3.utils.toWei('110'));
    /// Mint 90 token2 to user
    await token2.mint(user.address, web3.utils.toWei('90'));
    /// Approve swap contract to spend 110 token1
    await token1.connect(user).approve(swap.address, web3.utils.toWei('110'));
    /// Approve swap contract to spend 90 token2
    await token2.connect(user).approve(swap.address, web3.utils.toWei('90'));

    /// Get mint amount with 110 token1 and 90 token2
    const amounts = await swap.getMintAmount([web3.utils.toWei('110'), web3.utils.toWei('90')]);
    /// Check amounts[0] is mint amount
    const mintAmount = amounts[0];
    /// Check amounts[1] is fee amount
    const feeAmount = amounts[1];

    /// Check token1 balance is 110
    expect((await token1.balanceOf(user.address)).toString()).to.equals(web3.utils.toWei('110'));
    /// Check token2 balance is 90
    expect((await token2.balanceOf(user.address)).toString()).to.equals(web3.utils.toWei('90'));
    /// Check pool token balance is 0
    expect((await poolToken.balanceOf(user.address)).toString()).to.equals('0');
    /// Check fee recipient balance is 0
    expect((await poolToken.balanceOf(feeRecipient.address)).toString()).to.equals('0');
    /// Check swap token1 balance is 0
    expect((await swap.totalSupply()).toString()).to.equals((await poolToken.totalSupply()).toString());

    /// Mint 110 token1 and 90 token2 to pool token
    await swap.connect(user).mint([web3.utils.toWei('110'), web3.utils.toWei('90')], 0);
    /// Check token1 balance is 0
    expect((await token1.balanceOf(user.address)).toString()).to.equals('0');
    /// Check token2 balance is 0
    expect((await token2.balanceOf(user.address)).toString()).to.equals('0');
    /// Check pool token balance is mint amount
    expect((await poolToken.balanceOf(user.address)).toString()).to.equals(mintAmount.toString());
    /// Check fee recipient balance is fee amount
    expect((await poolToken.balanceOf(feeRecipient.address)).toString()).to.equals(feeAmount.toString());
    /// Check swap token1 balance is 110
    expect((await swap.balances(0)).toString()).to.equals(web3.utils.toWei('110'));
    /// Check swap token2 balance is 90
    expect((await swap.balances(1)).toString()).to.equals(web3.utils.toWei('90'));
    /// Check swap total supply is about 200
    expect((await swap.totalSupply()).toString()).to.equals('199994974999676499958');
    /// Check pool token total supply is about 200
    expect((await swap.totalSupply()).toString()).to.equals((await poolToken.totalSupply()).toString());
  });

  it('should return the correct mint amount with initial balance when two tokens are not equal', async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user] = await ethers.getSigners();

    /// Unpause swap contract
    await swap.unpause();
    /// Mint 105 token1 to user
    await token1.mint(user.address, web3.utils.toWei('105'));
    /// Mint 85 token2 to user
    await token2.mint(user.address, web3.utils.toWei('85'));
    /// Approve swap contract to spend 105 token1
    await token1.connect(user).approve(swap.address, web3.utils.toWei('105'));
    /// Approve swap contract to spend 85 token2
    await token2.connect(user).approve(swap.address, web3.utils.toWei('85'));
    /// Mint 105 token1 and 85 token2 to pool token
    await swap.connect(user).mint([web3.utils.toWei('105'), web3.utils.toWei('85')], 0);

    /// Get mint amount with 110 token1 and 90 token2
    // token1 and token2 has 8 decimals, so it's 110 token1 and 90 token2
    const amounts = await swap.getMintAmount([web3.utils.toWei('110'), web3.utils.toWei('90')]);
    /// Check amounts[0] is mint amount
    const mintAmount = amounts[0];
    expect(mintAmount.toString()).to.equals('199794987163851160846');
    /// Check amounts[1] is fee amount
    const feeAmount = amounts[1];
    expect(feeAmount.toString()).to.equals('199994982145997158');
    /// Check total amount is mint amount + fee amount
    const totalAmount = mintAmount.add(feeAmount);
    expect(totalAmount.toString()).to.equals('199994982145997158004');
    /// Check fee amount is 0.1%
    assertFee(totalAmount.toString(), feeAmount.toString(), MINT_FEE);

    // Convert 110 token1 and 90 token2 to 18 decimals
    /// Check invariant is 110 * 90 = 9900
    assetInvariant(web3.utils.toWei('110'), web3.utils.toWei('90'), 100, totalAmount);
  });

  it("should return the correct exchange amount", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, user2] = await ethers.getSigners();

    /// Unpause swap contract
    await swap.unpause();
    // We use total amount to approximate D!
    /// Get mint amount with 105 token1 and 85 token2
    const amounts = await swap.getMintAmount([web3.utils.toWei('105'), web3.utils.toWei('85')]);
    /// Check total amount is mint amount + fee amount
    const totalAmount = amounts[0].add(amounts[1]);
    /// Mint 105 token1 to user
    await token1.mint(user.address, web3.utils.toWei('105'));
    /// Mint 85 token2 to user
    await token2.mint(user.address, web3.utils.toWei('85'));
    /// Approve swap contract to spend 105 token1
    await token1.connect(user).approve(swap.address, web3.utils.toWei('105'));
    /// Approve swap contract to spend 85 token2
    await token2.connect(user).approve(swap.address, web3.utils.toWei('85'));
    /// Mint 105 token1 and 85 token2 to pool token
    await swap.connect(user).mint([web3.utils.toWei('105'), web3.utils.toWei('85')], 0);

    /// Mint 8 token2 to user2
    await token2.mint(user2.address, web3.utils.toWei('8'));
    /// Approve swap contract to spend 8 token2
    await token2.connect(user2).approve(swap.address, web3.utils.toWei('8'));
    /// Get exchange amount with 8 token2 to token1
    const exchangeAmount = await swap.getSwapAmount(1, 0, web3.utils.toWei('8'));
    expect(exchangeAmount.toString()).to.equals('7989075992756580743,16010172330173508');
  });

  it("should exchange the correct amount", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, user2] = await ethers.getSigners();

    /// Unpause swap contract
    await swap.unpause();
    /// Mint 105 token1 to user
    await token1.mint(user.address, web3.utils.toWei('105'));
    /// Mint 85 token2 to user
    await token2.mint(user.address, web3.utils.toWei('85'));
    /// Approve swap contract to spend 105 token1
    await token1.connect(user).approve(swap.address, web3.utils.toWei('105'));
    /// Approve swap contract to spend 85 token2
    await token2.connect(user).approve(swap.address, web3.utils.toWei('85'));
    /// Mint 105 token1 and 85 token2 to pool token
    await swap.connect(user).mint([web3.utils.toWei('105'), web3.utils.toWei('85')], 0);

    /// Mint 8 token2 to user2
    await token2.mint(user2.address, web3.utils.toWei('8'));
    /// Approve swap contract to spend 8 token2
    await token2.connect(user2).approve(swap.address, web3.utils.toWei('8'));
    /// Get exchange amount with 8 token2 to token1
    const exchangeAmount = (await swap.getSwapAmount(1, 0, web3.utils.toWei('8')))[0];
    /// Check user2 token1 balance is 0
    expect((await token1.balanceOf(user2.address)).toString()).to.equals('0');
    /// Check user2 token2 balance is 8
    expect((await token2.balanceOf(user2.address)).toString()).to.equals(web3.utils.toWei('8'));
    /// Check swap token1 balance is 105
    expect((await token1.balanceOf(swap.address)).toString()).to.equals(web3.utils.toWei('105'));
    /// Check swap token2 balance is 85
    expect((await token2.balanceOf(swap.address)).toString()).to.equals(web3.utils.toWei('85'));
    /// Check pool token1 balance is 105
    expect((await swap.balances(0)).toString()).to.equals(web3.utils.toWei('105'));
    /// Check pool token2 balance is 85
    expect((await swap.balances(1)).toString()).to.equals(web3.utils.toWei('85'));
    /// Check pool token balance is 190
    expect((await swap.totalSupply()).toString()).to.equals('189994704791049550806');
    expect((await swap.totalSupply()).toString()).to.equals((await poolToken.totalSupply()).toString());
    /// Get fee before exchange
    const feeBefore = new BN((await poolToken.balanceOf(feeRecipient.address)).toString());

    /// Swap 8 token2 to token1
    await swap.connect(user2).swap(1, 0, web3.utils.toWei('8'), 0);
    /// Get fee after exchange
    const feeAfter = new BN((await poolToken.balanceOf(feeRecipient.address)).toString());

    /// The amount of token1 got. In original format.
    expect((await token1.balanceOf(user2.address)).toString()).to.equals(exchangeAmount.toString());
    /// The amount of token2 left. In original format.
    expect((await token2.balanceOf(user2.address)).toString()).to.equals('0');
    /// 105 token1 - actual exchange output  (in original format)
    expect((await token1.balanceOf(swap.address)).toString()).to.equals(new BN(web3.utils.toWei('105')).sub(new BN(exchangeAmount.toString())).toString());
    /// 85 token2 + 8 token2  (in original format)
    expect((await token2.balanceOf(swap.address)).toString()).to.equals(web3.utils.toWei('93'));
    /// Check fee after exchange is greater than fee before exchange
    expect(feeAfter.gte(feeBefore)).to.equals(true);
    /// 85 token2 + 8 token2 (in converted format)
    expect((await swap.balances(1)).toString()).to.equals(web3.utils.toWei('93'));
    /// Check pool token balance same as swap token balance
    expect((await swap.totalSupply()).toString()).to.equals((await poolToken.totalSupply()).toString());
  });

  it("should return the correct redeem amount with proportional redemption", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, user2] = await ethers.getSigners();
    await swap.unpause();
    /// We use total amount to approximate D!
    /// Get mint amount with 105 token1 and 85 token2
    const mintAmounts = await swap.getMintAmount([web3.utils.toWei('105'), web3.utils.toWei('85')]);
    /// Get total amount
    const totalAmount = new BN(mintAmounts[0].add(mintAmounts[1]).toString());
    /// Mint 105 token1 to user
    await token1.mint(user.address, web3.utils.toWei('105'));
    /// Mint 85 token2 to user
    await token2.mint(user.address, web3.utils.toWei('85'));
    /// Approve swap contract to spend 105 token1
    await token1.connect(user).approve(swap.address, web3.utils.toWei('105'));
    /// Approve swap contract to spend 85 token2
    await token2.connect(user).approve(swap.address, web3.utils.toWei('85'));
    /// Mint 105 token1 and 85 token2 to pool token
    await swap.connect(user).mint([web3.utils.toWei('105'), web3.utils.toWei('85')], 0);

    /// Get redeem amount with 25 pool token
    const amounts = await swap.getRedeemProportionAmount(web3.utils.toWei('25'));
    /// Get token1 amount
    const token1Amount = new BN(amounts[0][0].toString());
    /// Get token2 amount
    const token2Amount = new BN(amounts[0][1].toString());
    /// Get fee amount
    const feeAmount = new BN(amounts[1].toString());

    /// Assert that poolToken redeemed / poolToken total = token1 amount / token1 balance = token2 amount / token2 balance
    assertAlmostTheSame(new BN(web3.utils.toWei('25')).sub(feeAmount).mul(new BN(web3.utils.toWei('105'))), new BN(token1Amount).mul(new BN(PRECISION)).mul(totalAmount));
    assertAlmostTheSame(new BN(web3.utils.toWei('25')).sub(feeAmount).mul(new BN(web3.utils.toWei('85'))), new BN(token2Amount).mul(new BN(PRECISION)).mul(totalAmount));

    /// Check invariant
    assetInvariant(new BN(web3.utils.toWei('105')).sub(token1Amount.mul(new BN(PRECISION))).toString(),
      new BN(web3.utils.toWei('85')).sub(token2Amount.mul(new BN(PRECISION))).toString(), 100, totalAmount.sub(new BN(web3.utils.toWei('25')).sub(feeAmount)).toString());
  });

  it("should redeem the correct amount with proportional redemption", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, user2] = await ethers.getSigners();
    /// Unpause swap
    await swap.unpause();
    /// We use total amount to approximate D!
    /// Get mint amount with 105 token1 and 85 token2
    const mintAmounts = await swap.getMintAmount([web3.utils.toWei('105'), web3.utils.toWei('85')]);
    /// Get total amount
    const totalAmount = new BN(mintAmounts[0].add(mintAmounts[1]).toString());
    /// Mint 105 token1 to user
    await token1.mint(user.address, web3.utils.toWei('105'));
    /// Mint 85 token2 to user
    await token2.mint(user.address, web3.utils.toWei('85'));
    /// Approve swap contract to spend 105 token1
    await token1.connect(user).approve(swap.address, web3.utils.toWei('105'));
    /// Approve swap contract to spend 85 token2
    await token2.connect(user).approve(swap.address, web3.utils.toWei('85'));
    /// Mint 105 token1 and 85 token2 to pool token
    await swap.connect(user).mint([web3.utils.toWei('105'), web3.utils.toWei('85')], 0);

    /// Get redeem amount with 25 pool token
    const amounts = await swap.getRedeemProportionAmount(web3.utils.toWei('25'));
    /// Get token1 amount
    const token1Amount = new BN(amounts[0][0].toString());
    /// Get token2 amount
    const token2Amount = new BN(amounts[0][1].toString());
    /// Get fee amount
    const feeAmount = new BN(amounts[1].toString());

    /// Transfer 25 pool token to user2
    await poolToken.connect(user).transfer(user2.address, web3.utils.toWei('25'));

    /// Check user2 token1 balance is 0
    expect((await token1.balanceOf(user2.address)).toString()).to.equals('0');
    /// Check user2 token2 balance is 0
    expect((await token2.balanceOf(user2.address)).toString()).to.equals('0');
    /// Check user2 pool token balance is 25
    expect((await poolToken.balanceOf(user2.address)).toString()).to.equals(web3.utils.toWei('25'));
    /// Check swap token1 balance is 105
    expect((await token1.balanceOf(swap.address)).toString()).to.equals(web3.utils.toWei('105'));
    /// Check swap token2 balance is 85
    expect((await token2.balanceOf(swap.address)).toString()).to.equals(web3.utils.toWei('85'));
    /// Check swap pool token1 balance is 105
    expect((await swap.balances(0)).toString()).to.equals(web3.utils.toWei('105'));
    /// Check swap pool token2 balance is 85
    expect((await swap.balances(1)).toString()).to.equals(web3.utils.toWei('85'));
    /// Check swap total supply
    expect((await swap.totalSupply()).toString()).to.equals('189994704791049550806');
    /// Check pool token total supply is same as swap total supply
    expect((await swap.totalSupply()).toString()).to.equals((await poolToken.totalSupply()).toString());

    /// Get fee before
    const feeBefore = new BN((await poolToken.balanceOf(feeRecipient.address)).toString());
    /// Approve swap contract to spend 8 token2
    await poolToken.connect(user2).approve(swap.address, web3.utils.toWei('25'));
    /// Redeem 25 pool token
    await swap.connect(user2).redeemProportion(web3.utils.toWei('25'), [0, 0]);

    /// The amount of token1 got. In original format.
    /// Check user2 token1 balance is token1Amount
    expect((await token1.balanceOf(user2.address)).toString()).to.equals(token1Amount.toString());
    /// Check user2 token2 balance is token2Amount
    expect((await token2.balanceOf(user2.address)).toString()).to.equals(token2Amount.toString());
    /// Check user2 pool token balance is 0
    expect((await poolToken.balanceOf(user2.address)).toString()).to.equals('0');
    /// Check fee recipient pool token balance is feeAmount
    assertAlmostTheSame(new BN((await poolToken.balanceOf(feeRecipient.address)).toString()), new BN(feeAmount.add(feeBefore).toString()));
    /// Check swap token1 balance is 105 - token1Amount
    expect((await token1.balanceOf(swap.address)).toString()).to.equals(new BN(web3.utils.toWei('105')).sub(token1Amount).toString());
    /// Check swap token2 balance is 85 - token2Amount
    expect((await token2.balanceOf(swap.address)).toString()).to.equals(new BN(web3.utils.toWei('85')).sub(token2Amount).toString());
    /// Check swap pool token1 balance is 105 - token1Amount
    assertAlmostTheSame(new BN((await swap.balances(0)).toString()), new BN(web3.utils.toWei('105')).sub(token1Amount.mul(new BN(PRECISION))));
    /// Check swap pool token2 balance is 85 - token2Amount
    assertAlmostTheSame(new BN((await swap.balances(1)).toString()), new BN(web3.utils.toWei('85')).sub(token2Amount.mul(new BN(PRECISION))));
    /// Check swap total supply
    expect((await swap.totalSupply()).toString()).to.equals((await poolToken.totalSupply()).toString());
  });

  it("should return the correct redeem amount to a single token", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, user2] = await ethers.getSigners();

    /// Unpause swap contract
    await swap.unpause();
    /// We use total amount to approximate D!
    /// Get mint amount with 105 token1 and 85 token2
    const mintAmounts = await swap.getMintAmount([web3.utils.toWei('105'), web3.utils.toWei('85')]);
    /// Get total amount
    const totalAmount = new BN(mintAmounts[0].add(mintAmounts[1]).toString());
    /// Mint 105 token1 to user
    await token1.mint(user.address, web3.utils.toWei('105'));
    /// Mint 85 token2 to user
    await token2.mint(user.address, web3.utils.toWei('85'));
    /// Approve swap contract to spend 105 token1
    await token1.connect(user).approve(swap.address, web3.utils.toWei('105'));
    /// Approve swap contract to spend 85 token2
    await token2.connect(user).approve(swap.address, web3.utils.toWei('85'));
    /// Mint 105 token1 and 85 token2 to swap contract
    await swap.connect(user).mint([web3.utils.toWei('105'), web3.utils.toWei('85')], 0);

    /// Get redeem amount with 25 pool token
    const redeemAmount = new BN(web3.utils.toWei('25')).toString();
    /// Get redeem amount to a single token
    const amounts = await swap.getRedeemSingleAmount(redeemAmount, 0);
    /// Get token1 amount from amounts
    const token1Amount = new BN(amounts[0].toString());
    /// Get fee amount from amounts
    const feeAmount = new BN(amounts[1].toString());

    /// Assert invariant
    assetInvariant(new BN(web3.utils.toWei('105')).sub(token1Amount.mul(new BN(PRECISION))).toString(), web3.utils.toWei('85'), 100, totalAmount.sub(new BN(redeemAmount).sub(feeAmount)).toString());
  });

  it("should redeem the correct amount to a single token", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, user2] = await ethers.getSigners();

    /// Unpause swap contract
    await swap.unpause();
    /// We use total amount to approximate D!
    /// Get mint amount with 105 token1 and 85 token2
    const mintAmounts = await swap.getMintAmount([web3.utils.toWei('105'), web3.utils.toWei('85')]);
    /// Get total amount
    const totalAmount = mintAmounts[0].add(mintAmounts[1]);
    /// Mint 105 token1 to user
    await token1.mint(user.address, web3.utils.toWei('105'));
    /// Mint 85 token2 to user
    await token2.mint(user.address, web3.utils.toWei('85'));
    /// Approve swap contract to spend 105 token1
    await token1.connect(user).approve(swap.address, web3.utils.toWei('105'));
    /// Approve swap contract to spend 85 token2
    await token2.connect(user).approve(swap.address, web3.utils.toWei('85'));
    /// Mint 105 token1 and 85 token2 to swap contract
    await swap.connect(user).mint([web3.utils.toWei('105'), web3.utils.toWei('85')], 0);

    /// Get redeem amount with 25 pool token
    const redeemAmount = new BN(web3.utils.toWei('25'));
    /// Get redeem amount to a single token
    const amounts = await swap.getRedeemSingleAmount(redeemAmount.toString(), 0);
    /// Get token1 amount from amounts
    const token1Amount = new BN(amounts[0].toString());
    /// Get fee amount from amounts
    const feeAmount = new BN(amounts[1].toString());

    /// Transfer 25 pool token to user2
    await poolToken.connect(user).transfer(user2.address, redeemAmount.toString());

    /// Check user2 token1 balance is 0
    expect((await token1.balanceOf(user2.address)).toString()).to.equals('0');
    /// Check user2 token2 balance is 0
    expect((await token2.balanceOf(user2.address)).toString()).to.equals('0');
    /// Check user2 swap pool token balance is 25
    expect((await poolToken.balanceOf(user2.address)).toString()).to.equals(redeemAmount.toString());
    /// Check swap pool token1 balance is 105
    expect((await token1.balanceOf(swap.address)).toString()).to.equals(web3.utils.toWei('105'));
    /// Check swap pool token2 balance is 85
    expect((await token2.balanceOf(swap.address)).toString()).to.equals(web3.utils.toWei('85'));
    /// Check swap pool token1 balance is 105
    expect((await swap.balances(0)).toString()).to.equals(web3.utils.toWei('105'));
    /// Check swap pool token2 balance is 85
    expect((await swap.balances(1)).toString()).to.equals(web3.utils.toWei('85'));
    /// Check swap pool total supply is same as pool token total supply
    expect((await swap.totalSupply()).toString()).to.equals((await poolToken.totalSupply()).toString());

    /// Get fee before redeem
    const feeBefore = new BN((await poolToken.balanceOf(feeRecipient.address)).toString());
    /// Approve swap contract to spend 25 pool token
    await poolToken.connect(user2).approve(swap.address, redeemAmount.toString());
    /// Redeem 25 pool token to token1
    await swap.connect(user2).redeemSingle(redeemAmount.toString(), 0, 0);

    /// The amount of token1 got. In original format.
    /// Check user2 token1 balance is token1Amount
    expect((await token1.balanceOf(user2.address)).toString()).to.equals(token1Amount.toString());
    /// Check user2 token2 balance is 0
    expect((await token2.balanceOf(user2.address)).toString()).to.equals('0');
    /// Check user2 swap pool token balance is 0
    expect((await poolToken.balanceOf(user2.address)).toString()).to.equals('0');
    /// Check fee recipient pool token balance is feeAmount + feeBefore
    expect((await poolToken.balanceOf(feeRecipient.address)).toString()).to.equals(feeAmount.add(feeBefore).toString());
    /// Check swap pool token1 balance is 105 - token1Amount
    expect((await token1.balanceOf(swap.address)).toString()).to.equals(new BN(web3.utils.toWei('105')).sub(token1Amount).toString());
    /// Check swap pool token2 balance is 85
    expect((await token2.balanceOf(swap.address)).toString()).to.equals(new BN(web3.utils.toWei('85')).toString());
    /// Check swap pool token1 balance is 105 - token1Amount
    assertAlmostTheSame(new BN((await swap.balances(0)).toString()), new BN(web3.utils.toWei('105')).sub(token1Amount.mul(new BN(PRECISION))));
    /// Check swap pool token2 balance is 85
    expect((await swap.balances(1)).toString()).to.equals(web3.utils.toWei('85'));
    /// Check swap pool total supply is same as pool token total supply
    expect((await swap.totalSupply()).toString()).to.equals((await poolToken.totalSupply()).toString());
  });

  it("should return the correct redeem amount to multiple tokens", async () => {
    /// Deploy swap contract
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, user2] = await ethers.getSigners();

    /// Unpause swap contract
    await swap.unpause();
    /// We use total amount to approximate D!
    /// Get mint amount with 105 token1 and 85 token2
    const mintAmounts = await swap.getMintAmount([web3.utils.toWei('105'), web3.utils.toWei('85')]);
    /// Get total amount
    const totalAmount = mintAmounts[0].add(mintAmounts[1]);
    /// Mint 105 token1 to user
    await token1.mint(user.address, web3.utils.toWei('105'));
    /// Mint 85 token2 to user
    await token2.mint(user.address, web3.utils.toWei('85'));
    /// Approve swap contract to spend 105 token1
    await token1.connect(user).approve(swap.address, web3.utils.toWei('105'));
    /// Approve swap contract to spend 85 token2
    await token2.connect(user).approve(swap.address, web3.utils.toWei('85'));
    /// Mint 105 token1 and 85 token2 to swap contract
    await swap.connect(user).mint([web3.utils.toWei('105'), web3.utils.toWei('85')], 0);

    /// Get redeem amount with 10 token1 and 5 token2
    const amounts = await swap.getRedeemMultiAmount([web3.utils.toWei('10'), web3.utils.toWei('5')]);
    /// Get redeem amount from amounts
    const redeemAmount = amounts[0];
    /// Get fee amount from amounts
    const feeAmount = amounts[1];

    /// Check redeem amount
    assertFee(redeemAmount.toString(), feeAmount.toString(), REDEEM_FEE);
    /// Assert invariant
    assetInvariant(web3.utils.toWei('95'), web3.utils.toWei('80'), 100, totalAmount.sub(redeemAmount.sub(feeAmount)).toString());
  });

  it("should redeem the correct amount to multiple tokens", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, user2] = await ethers.getSigners();

    /// Unpause swap contract
    await swap.unpause();
    /// We use total amount to approximate D!
    /// Get mint amount with 105 token1 and 85 token2
    const mintAmounts = await swap.getMintAmount([web3.utils.toWei('105'), web3.utils.toWei('85')]);
    /// Get total amount
    const totalAmount = mintAmounts[0].add(mintAmounts[1]);
    /// Mint 105 token1 to user
    await token1.mint(user.address, web3.utils.toWei('105'));
    /// Mint 85 token2 to user
    await token2.mint(user.address, web3.utils.toWei('85'));
    /// Approve swap contract to spend 105 token1
    await token1.connect(user).approve(swap.address, web3.utils.toWei('105'));
    /// Approve swap contract to spend 85 token2
    await token2.connect(user).approve(swap.address, web3.utils.toWei('85'));
    /// Mint 105 token1 and 85 token2 to swap contract
    await swap.connect(user).mint([web3.utils.toWei('105'), web3.utils.toWei('85')], 0);

    /// Get redeem amount with 10 token1 and 5 token2
    const amounts = await swap.getRedeemMultiAmount([web3.utils.toWei('10'), web3.utils.toWei('5')]);
    /// Get redeem amount from amounts
    const redeemAmount = amounts[0];
    /// Get fee amount from amounts
    const feeAmount = amounts[1];

    /// Transfer 25 pool token to user2
    await poolToken.connect(user).transfer(user2.address, web3.utils.toWei('25'));

    /// Check user2 token1 balance is 0
    expect((await token1.balanceOf(user2.address)).toString()).to.equals('0');
    /// Check user2 token2 balance is 0
    expect((await token2.balanceOf(user2.address)).toString()).to.equals('0');
    /// Check user2 pool token balance is 25
    expect((await poolToken.balanceOf(user2.address)).toString()).to.equals(web3.utils.toWei('25'));
    /// Check swap pool token1 balance is 105
    expect((await token1.balanceOf(swap.address)).toString()).to.equals(web3.utils.toWei('105'));
    /// Check swap pool token2 balance is 85
    expect((await token2.balanceOf(swap.address)).toString()).to.equals(web3.utils.toWei('85'));
    /// Check swap pool token1 balance is 105
    expect((await swap.balances(0)).toString()).to.equals(web3.utils.toWei('105'));
    /// Check swap pool token2 balance is 85
    expect((await swap.balances(1)).toString()).to.equals(web3.utils.toWei('85'));
    /// Check swap total supply is same as pool token total supply
    expect((await swap.totalSupply()).toString()).to.equals((await poolToken.totalSupply()).toString());

    /// Get fee before
    const feeBefore = await poolToken.balanceOf(feeRecipient.address);
    /// Approve swap contract to spend pool token
    await poolToken.connect(user2).approve(swap.address, redeemAmount);
    /// Redeem 10 token1 and 5 token2 to user2
    await swap.connect(user2).redeemMulti([web3.utils.toWei('10'), web3.utils.toWei('5')], redeemAmount);

    /// The amount of token1 got. In original format.
    /// Check user2 token1 balance is 10
    expect((await token1.balanceOf(user2.address)).toString()).to.equals(web3.utils.toWei('10'));
    /// Check user2 token2 balance is 5
    expect((await token2.balanceOf(user2.address)).toString()).to.equals(web3.utils.toWei('5'));
    /// Check user2 pool token balance is 25 - redeemAmount
    expect((await poolToken.balanceOf(user2.address)).toString()).to.equals(new BN(web3.utils.toWei('25')).sub(new BN(redeemAmount.toString())).toString());
    /// Check fee recipient pool token balance is feeAmount + feeBefore
    expect((await poolToken.balanceOf(feeRecipient.address)).toString()).to.equals(feeAmount.add(feeBefore).toString());
    /// Check swap pool token1 balance is 95
    expect((await token1.balanceOf(swap.address)).toString()).to.equals(web3.utils.toWei('95'));
    /// Check swap pool token2 balance is 80
    expect((await token2.balanceOf(swap.address)).toString()).to.equals(web3.utils.toWei('80'));
    /// Check swap pool token1 balance is 95
    expect((await swap.balances(0)).toString()).to.equals(web3.utils.toWei('95'));
    /// Check swap pool token2 balance is 80
    expect((await swap.balances(1)).toString()).to.equals(web3.utils.toWei('80'));
    /// Check swap total supply is same as pool token total supply
    expect((await swap.totalSupply()).toString()).to.equals((await poolToken.totalSupply()).toString());
  });

  it("should collect yield for rebasing tokens during mint", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, user2, yieldRecipient] = await ethers.getSigners();

    /// Unpause swap contract
    await swap.unpause();
    /// Mint 1000 token1 to user
    await token1.mint(user.address, web3.utils.toWei('1000'));
    /// Mint 1000 token2 to user
    await token2.mint(user.address, web3.utils.toWei('1000'));
    /// Approve swap contract to spend 1000 token1
    await token1.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    /// Approve swap contract to spend 1000 token2
    await token2.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    /// Mint 100 token1 and 100 token2 to swap contract
    await swap.connect(user).mint([web3.utils.toWei('100'), web3.utils.toWei('100')], 0);
    /// Get yield amount before
    const yieldAmountBefore = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    /// Mint 10 token1 to swap contract
    await token1.mint(swap.address, web3.utils.toWei('10'));
    /// Mint 100 token1 and 100 token2 to swap contract
    await swap.connect(user).mint([web3.utils.toWei('100'), web3.utils.toWei('100')], 0);
    /// Get yield amount after
    const yieldAmountAfter = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    /// Check yield amount before is 0
    expect(yieldAmountBefore.toString()).to.equals('0');
    /// Check yield amount is greater than before
    expect(yieldAmountAfter.gt(yieldAmountBefore)).to.equals(true);
  });

  it("should collect yield for rebasing tokens during swap", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, user2, yieldRecipient] = await ethers.getSigners();
    /// Unpause swap contract
    await swap.unpause();
    /// Mint 1000 token1 to user
    await token1.mint(user.address, web3.utils.toWei('1000'));
    /// Mint 1000 token2 to user
    await token2.mint(user.address, web3.utils.toWei('1000'));
    /// Approve swap contract to spend 1000 token1
    await token1.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    /// Approve swap contract to spend 1000 token2
    await token2.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    /// Mint 100 token1 and 100 token2 to swap contract
    await swap.connect(user).mint([web3.utils.toWei('100'), web3.utils.toWei('100')], 0);
    /// Get yield amount before
    const yieldAmountBefore = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    /// Mint 10 token1 to swap contract
    await token1.mint(swap.address, web3.utils.toWei('10'));
    /// Swap 1 token1 to token2
    await swap.connect(user).swap(0, 1, web3.utils.toWei('1'), '0');
    /// Get yield amount after
    const yieldAmountAfter = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    /// Check yield amount before is 0
    expect(yieldAmountBefore.toString()).to.equals('0');
    /// Check yield amount is greater than before
    expect(yieldAmountAfter.gt(yieldAmountBefore)).to.equals(true);
  });

  it("should collect yield for rebasing tokens during redeem proportion", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, user2, yieldRecipient] = await ethers.getSigners();
    /// Unpause swap contract
    await swap.unpause();
    /// Mint 1000 token1 to user
    await token1.mint(user.address, web3.utils.toWei('1000'));
    /// Mint 1000 token2 to user
    await token2.mint(user.address, web3.utils.toWei('1000'));
    /// Approve swap contract to spend 1000 token1
    await token1.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    /// Approve swap contract to spend 1000 token2
    await token2.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    /// Approve swap contract to spend 1000 pool token
    await poolToken.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    /// Mint 100 token1 and 100 token2 to swap contract
    await swap.connect(user).mint([web3.utils.toWei('100'), web3.utils.toWei('100')], 0);
    /// Get yield amount before
    const yieldAmountBefore = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    /// Mint 10 token1 to swap contract
    await token1.mint(swap.address, web3.utils.toWei('10'));
    /// Redeem 1 pool token
    await swap.connect(user).redeemProportion(web3.utils.toWei('1'), ['0', '0']);
    /// Get yield amount after
    const yieldAmountAfter = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    /// Check yield amount before is 0
    expect(yieldAmountBefore.toString()).to.equals('0');
    /// Check yield amount is greater than before
    expect(yieldAmountAfter.gt(yieldAmountBefore)).to.equals(true);
  });

  it("should collect yield for rebasing tokens during redeem single", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, user2, yieldRecipient] = await ethers.getSigners();
    /// Unpause swap contract
    await swap.unpause();
    /// Mint 1000 token1 to user
    await token1.mint(user.address, web3.utils.toWei('1000'));
    /// Mint 1000 token2 to user
    await token2.mint(user.address, web3.utils.toWei('1000'));
    /// Approve swap contract to spend 1000 token1
    await token1.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    /// Approve swap contract to spend 1000 token2
    await token2.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    /// Approve swap contract to spend 1000 pool token
    await poolToken.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    /// Mint 100 token1 and 100 token2 to swap contract
    await swap.connect(user).mint([web3.utils.toWei('100'), web3.utils.toWei('100')], 0);
    /// Get yield amount before
    const yieldAmountBefore = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    /// Mint 10 token1 to swap contract
    await token1.mint(swap.address, web3.utils.toWei('10'));
    /// Redeem 1 token1
    await swap.connect(user).redeemSingle(web3.utils.toWei('1'), '0', '0');
    /// Get yield amount after
    const yieldAmountAfter = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    /// Check yield amount before is 0
    expect(yieldAmountBefore.toString()).to.equals('0');
    /// Check yield amount is greater than before
    expect(yieldAmountAfter.gt(yieldAmountBefore)).to.equals(true);
  });

  it("should collect yield for rebasing tokens during redeem multi", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, user2, yieldRecipient] = await ethers.getSigners();
    /// Unpause swap contract
    await swap.unpause();
    /// Mint 1000 token1 to user
    await token1.mint(user.address, web3.utils.toWei('1000'));
    /// Mint 1000 token2 to user
    await token2.mint(user.address, web3.utils.toWei('1000'));
    /// Approve swap contract to spend 1000 token1
    await token1.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    /// Approve swap contract to spend 1000 token2
    await token2.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    /// Approve swap contract to spend 1000 pool token
    await poolToken.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    /// Mint 100 token1 and 100 token2 to swap contract
    await swap.connect(user).mint([web3.utils.toWei('100'), web3.utils.toWei('100')], 0);
    /// Get yield amount before
    const yieldAmountBefore = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    /// Mint 10 token1 to swap contract
    await token1.mint(swap.address, web3.utils.toWei('10'));
    /// Redeem 1 token1, 1 token2, and max pool token is 100
    await swap.connect(user).redeemMulti([web3.utils.toWei('1'), web3.utils.toWei('1')], web3.utils.toWei('100'));
    /// Get yield amount after
    const yieldAmountAfter = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    /// Check yield amount before is 0
    expect(yieldAmountBefore.toString()).to.equals('0');
    /// Check yield amount is greater than before
    expect(yieldAmountAfter.gt(yieldAmountBefore)).to.equals(true);
  });

  it("should return the correct redeem amount to multiple tokens rebasing", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, user2] = await ethers.getSigners();

    /// Unpause swap contract
    await swap.unpause();
    /// We use total amount to approximate D!
    /// Get mint amount for 105 token1 and 85 token2
    const mintAmounts = await swap.getMintAmount([web3.utils.toWei('105'), web3.utils.toWei('85')]);
    /// Get total amount
    const totalAmount = mintAmounts[0].add(mintAmounts[1]);
    /// Mint 105 token1 to user
    await token1.mint(user.address, web3.utils.toWei('105'));
    /// Mint 85 token2 to user
    await token2.mint(user.address, web3.utils.toWei('85'));
    /// Approve swap contract to spend 105 token1
    await token1.connect(user).approve(swap.address, web3.utils.toWei('105'));
    /// Approve swap contract to spend 85 token2
    await token2.connect(user).approve(swap.address, web3.utils.toWei('85'));
    /// Mint 105 token1 and 85 token2 to swap contract
    await swap.connect(user).mint([web3.utils.toWei('105'), web3.utils.toWei('85')], 0);

    /// Mint 10 token1 to swap contract
    await token1.mint(swap.address, web3.utils.toWei('10'));
    /// Get redeem amount for 10 token1 and 5 token2
    const amounts = await swap.getRedeemMultiAmount([web3.utils.toWei('10'), web3.utils.toWei('5')]);
    /// Get redeem amount from amounts
    const redeemAmount = amounts[0];
    /// Get fee amount from amounts
    const feeAmount = amounts[1];

    /// Check redeem amount
    assertFee(redeemAmount.toString(), feeAmount.toString(), REDEEM_FEE);
    /// Assert invariant
    assetInvariant(web3.utils.toWei('95'), web3.utils.toWei('80'), 100, totalAmount.sub(redeemAmount.sub(feeAmount)).toString());
  });

  it("should return the correct redeem amount to a single token rebasing", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, user2] = await ethers.getSigners();

    /// Unpause swap contract
    await swap.unpause();
    /// We use total amount to approximate D!
    /// Get mint amount for 105 token1 and 85 token2
    const mintAmounts = await swap.getMintAmount([web3.utils.toWei('105'), web3.utils.toWei('85')]);
    /// Get total amount
    const totalAmount = new BN(mintAmounts[0].add(mintAmounts[1]).toString());
    /// Mint 105 token1 to user
    await token1.mint(user.address, web3.utils.toWei('105'));
    /// Mint 85 token2 to user
    await token2.mint(user.address, web3.utils.toWei('85'));
    /// Approve swap contract to spend 105 token1
    await token1.connect(user).approve(swap.address, web3.utils.toWei('105'));
    /// Approve swap contract to spend 85 token2
    await token2.connect(user).approve(swap.address, web3.utils.toWei('85'));
    /// Mint 105 token1 and 85 token2 to swap contract
    await swap.connect(user).mint([web3.utils.toWei('105'), web3.utils.toWei('85')], 0);

    /// Mint 10 token1 to swap contract
    await token1.mint(swap.address, web3.utils.toWei('10'));
    /// Set redeem amount is 25 token1
    const redeemAmount = new BN(web3.utils.toWei('25')).toString();
    /// Get redeem amount
    const amounts = await swap.getRedeemSingleAmount(redeemAmount, 0);
    /// Get token1 amount from amounts
    const token1Amount = new BN(amounts[0].toString());
    /// Get fee amount from amounts
    const feeAmount = new BN(amounts[1].toString());

    /// Assert invariant
    assetInvariant(new BN(web3.utils.toWei('105')).sub(token1Amount.mul(new BN(PRECISION))).toString(), web3.utils.toWei('85'), 100, totalAmount.sub(new BN(redeemAmount).sub(feeAmount)).toString());
  });

  it("should return the correct redeem amount with proportional redemption rebasing", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, user2] = await ethers.getSigners();
    /// Unpause swap contract
    await swap.unpause();
    /// We use total amount to approximate D!
    /// Get mint amount for 105 token1 and 85 token2
    const mintAmounts = await swap.getMintAmount([web3.utils.toWei('105'), web3.utils.toWei('85')]);
    /// Mint 105 token1 to user
    await token1.mint(user.address, web3.utils.toWei('105'));
    /// Mint 85 token2 to user
    await token2.mint(user.address, web3.utils.toWei('85'));
    /// Approve swap contract to spend 105 token1
    await token1.connect(user).approve(swap.address, web3.utils.toWei('105'));
    /// Approve swap contract to spend 85 token2
    await token2.connect(user).approve(swap.address, web3.utils.toWei('85'));
    /// Mint 105 token1 and 85 token2 to swap contract
    await swap.connect(user).mint([web3.utils.toWei('105'), web3.utils.toWei('85')], 0);

    /// Mint 10 token1 to swap contract
    await token1.mint(swap.address, web3.utils.toWei('10'));
    /// Get redeem amounts for 25 poolToken
    const amounts = await swap.getRedeemProportionAmount(web3.utils.toWei('25'));
    /// Get token1 amount from amounts
    const token1Amount = new BN(amounts[0][0].toString());
    /// Get token2 amount from amounts
    const token2Amount = new BN(amounts[0][1].toString());
    /// Get fee amount from amounts
    const feeAmount = new BN(amounts[1].toString());
    expect(token1Amount.toString()).to.equals('14303943881560144839');
    expect(token2Amount.toString()).to.equals('10572480260283585316');
    expect(feeAmount.toString()).to.equals('125000000000000000');
  });

  it("should return the correct exchange amount rebasing", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, user2] = await ethers.getSigners();

    /// Unpause swap contract
    await swap.unpause();
    /// We use total amount to approximate D!
    /// Get mint amount for 105 token1 and 85 token2
    const amounts = await swap.getMintAmount([web3.utils.toWei('105'), web3.utils.toWei('85')]);
    /// Get total amount
    const totalAmount = amounts[0].add(amounts[1]);
    /// Mint 105 token1 to user
    await token1.mint(user.address, web3.utils.toWei('105'));
    /// Mint 85 token2 to user
    await token2.mint(user.address, web3.utils.toWei('85'));
    /// Approve swap contract to spend 105 token1
    await token1.connect(user).approve(swap.address, web3.utils.toWei('105'));
    /// Approve swap contract to spend 85 token2
    await token2.connect(user).approve(swap.address, web3.utils.toWei('85'));
    /// Mint 105 token1 and 85 token2 to swap contract
    await swap.connect(user).mint([web3.utils.toWei('105'), web3.utils.toWei('85')], 0);

    /// Mint 8 token2 to user2
    await token2.mint(user2.address, web3.utils.toWei('8'));
    /// Approve swap contract to spend 8 token2
    await token2.connect(user2).approve(swap.address, web3.utils.toWei('8'));
    /// Mint 8 token2 to swap contract
    await token1.mint(swap.address, web3.utils.toWei('10'));
    /// Get exchange amount for 8 token2
    const exchangeAmount = await swap.getSwapAmount(1, 0, web3.utils.toWei('8'));
    expect(exchangeAmount.toString()).to.equals('7992985053666343961,16018006119571831');
  });

  it('should return the correct mint amount when two tokens are not equal rebasing', async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    /// Mint 10 token1 to swap contract
    await token1.mint(swap.address, web3.utils.toWei('10'));
    /// Mint 10 token2 to swap contract
    await token2.mint(swap.address, web3.utils.toWei('10'));
    /// Get mint amount for 110 token1 and 90 token2
    const amounts = await swap.getMintAmount([web3.utils.toWei('110'), web3.utils.toWei('90')]);
    /// Get mint amount from amounts
    const mintAmount = amounts[0];
    /// Get fee amount from amounts
    const feeAmount = amounts[1];
    /// Get total amount
    const totalAmount = mintAmount.add(feeAmount);
    /// Assert fee amount is correct
    assertFee(totalAmount.toString(), feeAmount.toString(), MINT_FEE);
    /// Assert invariant
    assetInvariant(web3.utils.toWei('100'), web3.utils.toWei('100'), 100, web3.utils.toWei('200'));
  });

  it('should return the correct mint amount when two tokens are equal rebasing', async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    /// Mint 10 token1 to swap contract
    await token1.mint(swap.address, web3.utils.toWei('10'));
    /// Mint 10 token2 to swap contract
    await token2.mint(swap.address, web3.utils.toWei('10'));
    /// Get mint amount for 100 token1 and 100 token2
    const amounts = await swap.getMintAmount([web3.utils.toWei('100'), web3.utils.toWei('100')]);
    /// Get mint amount from amounts
    const mintAmount = amounts[0];
    /// Get fee amount from amounts
    const feeAmount = amounts[1];
    /// Get total amount
    const totalAmount = mintAmount.add(feeAmount);
    /// Check total amount is 200
    expect(totalAmount.toString()).to.equals(web3.utils.toWei('200'));
    /// Assert fee amount is correct
    assertFee(totalAmount.toString(), feeAmount.toString(), MINT_FEE);
    /// Assert invariant
    assetInvariant(web3.utils.toWei('100'), web3.utils.toWei('100'), 100, web3.utils.toWei('200'));
  });

  it("should collect yield for exchange rate tokens during mint", async () => {
    /// Deploy swap and tokensExchangeRate
    const { swap, token1, token2, poolToken, exchangeRate } = await loadFixture(deploySwapAndTokensExchangeRate);
    const [owner, feeRecipient, user, user2, yieldRecipient] = await ethers.getSigners();
    /// Unpause swap contract
    await swap.unpause();
    /// Mint 1000 token1 to user
    await token1.mint(user.address, web3.utils.toWei('1000'));
    /// Mint 1000 token2 to user
    await token2.mint(user.address, web3.utils.toWei('1000'));
    /// Approve swap contract to spend 1000 token1
    await token1.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    /// Approve swap contract to spend 1000 token2
    await token2.connect(user).approve(swap.address, web3.utils.toWei('1000'));

    /// Mint 1000 token1 and 1000 token2 to swap contract
    await swap.connect(user).mint([web3.utils.toWei('100'), web3.utils.toWei('100')], 0);
    /// Get yield amount before
    const yieldAmountBefore = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    /// Set exchange rate to 1.1
    await exchangeRate.newRate("1100000000000000000");
    /// Mint 1000 token1 and 1000 token2 to swap contract
    await swap.connect(user).mint([web3.utils.toWei('100'), web3.utils.toWei('100')], 0);
    /// Get yield amount after
    const yieldAmountAfter = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    /// Assert yield amount before is 0
    expect(yieldAmountBefore.toString()).to.equals('0');
    /// Assert yield amount after is greater than yield amount before
    expect(yieldAmountAfter.gt(yieldAmountBefore)).to.equals(true);
  });

  it("should collect yield for exchange rate tokens during swap", async () => {
    /// Deploy swap and tokensExchangeRate
    const { swap, token1, token2, poolToken, exchangeRate } = await loadFixture(deploySwapAndTokensExchangeRate);
    const [owner, feeRecipient, user, user2, yieldRecipient] = await ethers.getSigners();
    /// Unpause swap contract
    await swap.unpause();
    /// Mint 1000 token1 to user
    await token1.mint(user.address, web3.utils.toWei('1000'));
    /// Mint 1000 token2 to user
    await token2.mint(user.address, web3.utils.toWei('1000'));
    /// Approve swap contract to spend 1000 token1
    await token1.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    /// Approve swap contract to spend 1000 token2
    await token2.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    /// Mint 100 token1 and 100 token2 to swap contract
    await swap.connect(user).mint([web3.utils.toWei('100'), web3.utils.toWei('100')], 0);
    /// Get yield amount before
    const yieldAmountBefore = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    /// Set exchange rate to 1.1
    await exchangeRate.newRate("1100000000000000000");
    /// Swap 1 token1 to token2
    await swap.connect(user).swap(0, 1, web3.utils.toWei('1'), '0');
    /// Get yield amount after
    const yieldAmountAfter = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    /// Assert yield amount before is 0
    expect(yieldAmountBefore.toString()).to.equals('0');
    /// Assert yield amount after is greater than yield amount before
    expect(yieldAmountAfter.gt(yieldAmountBefore)).to.equals(true);
  });

  it("should collect yield for exchange rate tokens during redeem proportion", async () => {
    /// Deploy swap and tokensExchangeRate
    const { swap, token1, token2, poolToken, exchangeRate } = await loadFixture(deploySwapAndTokensExchangeRate);
    const [owner, feeRecipient, user, user2, yieldRecipient] = await ethers.getSigners();
    /// Unpause swap contract
    await swap.unpause();
    /// Mint 1000 token1 to user
    await token1.mint(user.address, web3.utils.toWei('1000'));
    /// Mint 1000 token2 to user
    await token2.mint(user.address, web3.utils.toWei('1000'));
    /// Approve swap contract to spend 1000 token1
    await token1.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    /// Approve swap contract to spend 1000 token2
    await token2.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    /// Approve swap contract to spend 1000 poolToken
    await poolToken.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    /// Mint 100 token1 and 100 token2 to swap contract
    await swap.connect(user).mint([web3.utils.toWei('100'), web3.utils.toWei('100')], 0);
    /// Get yield amount before
    const yieldAmountBefore = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    /// Set exchange rate to 1.1
    await exchangeRate.newRate("1100000000000000000");
    /// Redeem 1 poolToken
    await swap.connect(user).redeemProportion(web3.utils.toWei('1'), ['0', '0']);
    /// Get yield amount after
    const yieldAmountAfter = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    /// Assert yield amount before is 0
    expect(yieldAmountBefore.toString()).to.equals('0');
    /// Assert yield amount after is greater than yield amount before
    expect(yieldAmountAfter.gt(yieldAmountBefore)).to.equals(true);
  });

  it("should collect yield for exchange rate tokens during redeem single", async () => {
    /// Deploy swap and tokensExchangeRate
    const { swap, token1, token2, poolToken, exchangeRate } = await loadFixture(deploySwapAndTokensExchangeRate);
    const [owner, feeRecipient, user, user2, yieldRecipient] = await ethers.getSigners();
    /// Unpause swap contract
    await swap.unpause();
    /// Mint 1000 token1 to user
    await token1.mint(user.address, web3.utils.toWei('1000'));
    /// Mint 1000 token2 to user
    await token2.mint(user.address, web3.utils.toWei('1000'));
    /// Approve swap contract to spend 1000 token1
    await token1.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    /// Approve swap contract to spend 1000 token2
    await token2.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    /// Approve swap contract to spend 1000 poolToken
    await poolToken.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    /// Mint 100 token1 and 100 token2 to swap contract
    await swap.connect(user).mint([web3.utils.toWei('100'), web3.utils.toWei('100')], 0);
    /// Get yield amount before
    const yieldAmountBefore = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    /// Set exchange rate to 1.1
    await exchangeRate.newRate("1100000000000000000");
    /// Redeem 1 poolToken
    await swap.connect(user).redeemSingle(web3.utils.toWei('1'), '1', '0');
    /// Get yield amount after
    const yieldAmountAfter = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    /// Assert yield amount before is 0
    expect(yieldAmountBefore.toString()).to.equals('0');
    /// Assert yield amount after is greater than yield amount before
    expect(yieldAmountAfter.gt(yieldAmountBefore)).to.equals(true);
  });

  it("should collect yield for exchange rate tokens during redeem multi", async () => {
    /// Deploy swap and tokensExchangeRate
    const { swap, token1, token2, poolToken, exchangeRate } = await loadFixture(deploySwapAndTokensExchangeRate);
    const [owner, feeRecipient, user, user2, yieldRecipient] = await ethers.getSigners();
    /// Unpause swap contract
    await swap.unpause();
    /// Mint 1000 token1 to user
    await token1.mint(user.address, web3.utils.toWei('1000'));
    /// Mint 1000 token2 to user
    await token2.mint(user.address, web3.utils.toWei('1000'));
    /// Approve swap contract to spend 1000 token1
    await token1.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    /// Approve swap contract to spend 1000 token2
    await token2.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    await poolToken.connect(user).approve(swap.address, web3.utils.toWei('1000'));
    /// Mint 100 token1 and 100 token2 to swap contract
    await swap.connect(user).mint([web3.utils.toWei('100'), web3.utils.toWei('100')], 0);
    /// Get yield amount before
    const yieldAmountBefore = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    /// Set exchange rate to 1.1
    await exchangeRate.newRate("1100000000000000000");
    /// Redeem 1 token1 and 1 token2
    await swap.connect(user).redeemMulti([web3.utils.toWei('1'), web3.utils.toWei('1')], web3.utils.toWei('100'));
    /// Get yield amount after
    const yieldAmountAfter = new BN((await poolToken.balanceOf(yieldRecipient.address)).toString());

    /// Assert yield amount before is 0
    expect(yieldAmountBefore.toString()).to.equals('0');
    /// Assert yield amount after is greater than yield amount before
    expect(yieldAmountAfter.gt(yieldAmountBefore)).to.equals(true);
  });

  it("should allow to update governance", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, admin] = await ethers.getSigners();
    /// Check can't update governance if not governance
    await expect(swap.connect(admin).setGovernance(user.address)).to.be.revertedWith("not governance");
    /// Update governance to user
    await swap.setGovernance(user.address);
    /// Check governance is user
    expect(await swap.governance()).to.equals(user.address);
  });

  it("should allow to update mint fee", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, admin] = await ethers.getSigners();
    /// Check can't update mint fee if not governance
    await expect(swap.connect(admin).setMintFee('1000')).to.be.revertedWith("not governance");
    /// Update mint fee to 1000
    swap.setMintFee('1000');
    /// Set mint fee is 1000
    expect((await swap.mintFee()).toString()).to.equals('1000');
  });

  it("should allow to update swap fee", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    /// Set swap fee to 1000
    swap.setSwapFee('1000');
    /// Set swap fee is 1000
    expect((await swap.swapFee()).toString()).to.equals('1000');
  });

  it("should allow to update redeem fee", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    /// Set redeem fee to 1000
    swap.setRedeemFee('1000');
    /// Set redeem fee is 1000
    expect((await swap.redeemFee()).toString()).to.equals('1000');
  });

  it("should allow to pause and unpause", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, admin] = await ethers.getSigners();
    /// Check can't pause if not governance
    await expect(swap.connect(admin).pause()).to.be.revertedWith("not governance");
    /// Check can't unpause when paused
    await expect(swap.pause()).to.be.revertedWith("paused");
    /// Pause swap
    await swap.unpause();
    /// Check paused is false
    expect(await swap.paused()).to.equals(false);
    /// Check can't unpause if not governance
    await expect(swap.connect(admin).unpause()).to.be.revertedWith("not governance");
    /// Check can't pause when unpaused
    await expect(swap.unpause()).to.be.revertedWith("not paused");
    /// Pause swap
    await swap.pause();
    /// Check paused is true
    expect(await swap.paused()).to.equals(true);
  });

  it("setFeeRecipient should work", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, admin] = await ethers.getSigners();

    /// Check initial fee recipient is fee recipient
    expect(await swap.feeRecipient()).to.be.equals(feeRecipient.address);

    /// Check can't set fee recipient if not governance
    await expect(swap.connect(admin).setFeeRecipient(ethers.constants.AddressZero)).to.be.revertedWith("not governance");
    /// Check can't set fee recipient to zero address
    await expect(swap.setFeeRecipient(ethers.constants.AddressZero)).to.be.revertedWith("fee recipient not set");

    /// Set fee recipient to user
    await swap.setFeeRecipient(user.address);
    /// Check fee recipient is user
    expect(await swap.feeRecipient()).to.be.equals(user.address);
  });

  it("setAdmin should work", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, admin] = await ethers.getSigners();

    /// Check initial admin is owner
    expect(await swap.admins(admin.address)).to.equals(false);

    //// Check can't set admin if not governance
    await expect(swap.connect(user).setAdmin(ethers.constants.AddressZero, true)).to.be.revertedWith("not governance");
    /// Check can't set admin to zero address
    await expect(swap.setAdmin(ethers.constants.AddressZero, true)).to.be.revertedWith("account not set");

    /// Set admin to true
    await swap.setAdmin(admin.address, true);
    /// Check admin is true
    expect(await swap.admins(admin.address)).to.equals(true);

    /// Set admin to false
    await swap.setAdmin(admin.address, false);
    /// Check admin is false
    expect(await swap.admins(admin.address)).to.equals(false);
  });

  it("updateA should work", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, admin] = await ethers.getSigners();
    /// Check initial A is 100
    expect(await swap.initialA()).to.equals(100);
    /// Check future A is 100
    expect(await swap.futureA()).to.equals(100);

    /// Check updateA fails if not governance
    await expect(swap.connect(admin).updateA(1000, 20)).to.be.revertedWith("not governance");
    /// Check updateA fails if block in the past
    await expect(swap.updateA(1000, 8)).to.be.revertedWith("block in the past");

    /// Check updateA fails if A not set
    await expect(swap.updateA(0, 26)).to.be.revertedWith("A not set");

    /// Check updateA fails if A exceeds max
    await expect(swap.updateA(1000000, 27)).to.be.revertedWith("A not set");

    /// Update A to 1000 at block 28
    await swap.updateA(1000, 30); // need extra block to update
    /// Check initial A is 100
    expect(await swap.initialA()).to.equals(100);
    /// Check future A is 1000
    expect(await swap.futureA()).to.equals(1000);
  });

  it("getA should work", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user, user2] = await ethers.getSigners();

    /// Check initial A is 100
    expect(await swap.initialA()).to.equals(100);
    /// Check future A is 100
    expect(await swap.getA()).to.equals(100);

    /// Update A to 1000 when block is 100
    await swap.updateA(1000, await ethers.provider.getBlockNumber() + 39);
    /// Check future A is 1000
    expect(await swap.initialA()).to.equals(100);
    /// Check future A is 1000
    expect(await swap.futureA()).to.equals(1000);
    /// Check getA is 100
    expect(await swap.getA()).to.equals(100);

    const hre = await import("hardhat");

    /// Mine 35 blocks
    await hre.network.provider.request({
      method: "hardhat_mine",
      params: [ethers.utils.hexlify(35)]
    });
    /// Check getA is 520
    expect(await swap.getA()).to.greaterThan(100);

    /// Mine 38 blocks
    await hre.network.provider.request({
      method: "hardhat_mine",
      params: [ethers.utils.hexlify(39)]
    });
    /// Mine 1 block
    await hre.network.provider.request({
      method: "hardhat_mine",
      params: [ethers.utils.hexStripZeros(ethers.utils.hexlify(1))]
    });
    /// Check getA is 1000
    expect(await swap.getA()).to.equals(1000);
    /// Mine 1 block
    await hre.network.provider.request({
      method: "hardhat_mine",
      params: [ethers.utils.hexStripZeros(ethers.utils.hexlify(1))]
    });
    /// Check getA is 1000
    expect(await swap.getA()).to.equals(1000);

    /// Update A to 500 when block number is 200
    await swap.updateA(500, 200);
    /// Mine 40 blocks
    await hre.network.provider.request({
      method: "hardhat_mine",
      params: [ethers.utils.hexStripZeros(ethers.utils.hexlify(40))]
    });
    /// Check getA is 796
    expect(await swap.getA()).to.lessThan(1000);
    
    await hre.network.provider.request({
      method: "hardhat_mine",
      params: [ethers.utils.hexStripZeros(ethers.utils.hexlify(100))]
    });
    /// Check getA is 500
    expect(await swap.getA()).to.equals(500);
  });
});
