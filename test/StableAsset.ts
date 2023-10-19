import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers, upgrades, web3 } from "hardhat";
import BN from "bn.js";

const PRECISION = "1";
const MINT_FEE = "10000000";
const SWAP_FEE = "20000000";
const REDEEM_FEE = "50000000";
const FEE_DENOMITOR = "10000000000";

const assertFee = (getAmount: string, feeAmount: string, fee: string) => {
  const expectedFee = new BN(getAmount)
    .mul(new BN(fee))
    .div(new BN(FEE_DENOMITOR));
  expect(feeAmount.toString()).to.equal(expectedFee.toString());
};

const assertAlmostTheSame = (num1: BN, num2: BN) => {
  // Assert that the difference is smaller than 0.01%
  const diff = num1
    .sub(num2)
    .abs()
    .mul(new BN(10000))
    .div(BN.min(num1, num2))
    .toNumber();
  expect(diff).to.equal(0);
};

const assetInvariant = async (
  balance0: string,
  balance1: string,
  A: number,
  D: string
) => {
  // We only check n = 2 here
  const left = new BN(A * 4)
    .mul(new BN(balance0).add(new BN(balance1)))
    .add(new BN(D));
  // const num = new BN(D).pow(new BN('3')).div(new BN(balance0).mul(new BN(balance1)).mul(new BN('4')));
  const right = new BN(A * 4)
    .mul(new BN(D))
    .add(
      new BN(D)
        .pow(new BN("3"))
        .div(new BN(balance0).mul(new BN(balance1)).mul(new BN("4")))
    );

  assertAlmostTheSame(left, right);
};

describe("StableAsset", function () {
  async function deploySwapAndTokens() {
    // Contracts are deployed using the first signer/account by default
    const [owner, feeRecipient, user, user2, yieldRecipient, governance] =
      await ethers.getSigners();

    const StableAsset = await ethers.getContractFactory("StableAsset");
    const MockToken = await ethers.getContractFactory("MockToken");
    const StableAssetToken = await ethers.getContractFactory("TapETH");
    const ConstantExchangeRateProvider = await ethers.getContractFactory(
      "ConstantExchangeRateProvider"
    );

    /// Deploy token1 with name "test 1", symbol "T1", decimals 18
    const token1 = await MockToken.deploy("test 1", "T1", 18);
    /// Deploy token2 with name "test 2", symbol "T2", decimals 18
    const token2 = await MockToken.deploy("test 2", "T2", 18);
    /// Deploy pool token with name "Pool Token", symbol "PT", decimals 18
    const poolToken = await upgrades.deployProxy(StableAssetToken, [
      governance.address,
    ]);
    /// Deploy constant exchange rate provider with exchange rate 1
    const constant = await ConstantExchangeRateProvider.deploy();

    /// Deploy swap contract with [token1, token2], [PRECISION, PRECISION], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeRecipient, yieldRecipient, poolToken, A = 100 and ConstantExchangeRate
    const swap = await upgrades.deployProxy(StableAsset, [
      [token1.address, token2.address],
      [PRECISION, PRECISION],
      [MINT_FEE, SWAP_FEE, REDEEM_FEE],
      feeRecipient.address,
      yieldRecipient.address,
      poolToken.address,
      100,
      constant.address,
      1,
    ]);
    /// Set swap as minter of pool token
    await poolToken.connect(governance).addPool(swap.address);

    return { swap, token1, token2, poolToken };
  }

  async function deploySwapAndTokensExchangeRate() {
    // Contracts are deployed using the first signer/account by default
    const [owner, feeRecipient, user, user2, yieldRecipient, governance] =
      await ethers.getSigners();

    const StableAsset = await ethers.getContractFactory("StableAsset");
    const MockToken = await ethers.getContractFactory("MockToken");
    const StableAssetToken = await ethers.getContractFactory(
      "StableAssetToken"
    );
    const MockTokenWithExchangeRate = await ethers.getContractFactory(
      "MockExchangeRateProvider"
    );

    /// Deploy token1 with name "test 1", symbol "T1", decimals 18
    const token1 = await MockToken.deploy("test 1", "T1", 18);
    /// Deploy token2 with name "test 2", symbol "T2", decimals 18
    const token2 = await MockToken.deploy("test 2", "T2", 18);
    /// Deploy MockTokenWithExchangeRate with exchange rate 1 and decimals 18
    const exchangeRate = await MockTokenWithExchangeRate.deploy(
      "1000000000000000000",
      "18"
    );
    /// Deploy pool token with name "Pool Token", symbol "PT", decimals 18
    const poolToken = await upgrades.deployProxy(StableAssetToken, [
      governance.address,
    ]);

    /// Deploy swap contract with [token1, token2], [PRECISION, PRECISION], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeRecipient, yieldRecipient, poolToken, and A = 100
    const swap = await upgrades.deployProxy(StableAsset, [
      [token1.address, token2.address],
      [PRECISION, PRECISION],
      [MINT_FEE, SWAP_FEE, REDEEM_FEE],
      feeRecipient.address,
      yieldRecipient.address,
      poolToken.address,
      100,
      exchangeRate.address,
      1,
    ]);
    /// Set swap as minter of pool token
    await poolToken.connect(governance).addPool(swap.address);

    return { swap, token1, token2, poolToken, exchangeRate };
  }

  it("should initialize paramters", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(
      deploySwapAndTokens
    );
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
    const [owner, feeRecipient, user, user2, yieldRecipient, governance] =
      await ethers.getSigners();

    const StableAsset = await ethers.getContractFactory("StableAsset");
    const MockToken = await ethers.getContractFactory("MockToken");
    const StableAssetToken = await ethers.getContractFactory("TapETH");
    const ConstantExchangeRateProvider = await ethers.getContractFactory(
      "ConstantExchangeRateProvider"
    );
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
    const poolToken = await upgrades.deployProxy(StableAssetToken, [
      governance.address,
    ]);

    /// Check deploy swap with no tokens
    await expect(
      upgrades.deployProxy(StableAsset, [
        [],
        [],
        [MINT_FEE, SWAP_FEE, REDEEM_FEE],
        feeRecipient.address,
        yieldRecipient.address,
        poolToken.address,
        100,
        constant.address,
        1,
      ])
    ).to.be.revertedWith("input mismatch");

    /// Check deploy swap with token length not match
    await expect(
      upgrades.deployProxy(StableAsset, [
        [],
        [PRECISION, PRECISION],
        [MINT_FEE, SWAP_FEE, REDEEM_FEE],
        feeRecipient.address,
        yieldRecipient.address,
        poolToken.address,
        100,
        constant.address,
        1,
      ])
    ).to.be.revertedWith("input mismatch");

    /// Check deploy swap with fee length not match
    await expect(
      upgrades.deployProxy(StableAsset, [
        [token1.address, token2.address],
        [PRECISION, PRECISION],
        [MINT_FEE, SWAP_FEE],
        feeRecipient.address,
        yieldRecipient.address,
        poolToken.address,
        0,
        constant.address,
        1,
      ])
    ).to.be.revertedWith("no fees");

    /// Check deploy swap with token not set
    await expect(
      upgrades.deployProxy(StableAsset, [
        [token1.address, ethers.constants.AddressZero],
        [PRECISION, PRECISION],
        [MINT_FEE, SWAP_FEE, REDEEM_FEE],
        feeRecipient.address,
        yieldRecipient.address,
        poolToken.address,
        0,
        constant.address,
        1,
      ])
    ).to.be.revertedWith("token not set");

    await expect(
      upgrades.deployProxy(StableAsset, [
        [token1.address, token2.address],
        [PRECISION, 10],
        [MINT_FEE, SWAP_FEE, REDEEM_FEE],
        feeRecipient.address,
        yieldRecipient.address,
        poolToken.address,
        0,
        constant.address,
        1,
      ])
    ).to.be.revertedWith("precision not set");

    await expect(
      upgrades.deployProxy(StableAsset, [
        [token1.address, token17.address],
        [PRECISION, "10000000000000000"],
        [MINT_FEE, SWAP_FEE, REDEEM_FEE],
        feeRecipient.address,
        yieldRecipient.address,
        poolToken.address,
        0,
        constant.address,
        1,
      ])
    ).to.be.revertedWith("precision not set");

    await expect(
      upgrades.deployProxy(StableAsset, [
        [token1.address, token19.address],
        [1, "1000000000000000000"],
        [MINT_FEE, SWAP_FEE, REDEEM_FEE],
        feeRecipient.address,
        yieldRecipient.address,
        poolToken.address,
        0,
        constant.address,
        1,
      ])
    ).to.be.revertedWithPanic(0x11);

    /// Check deploy swap with fee recipient not set
    await expect(
      upgrades.deployProxy(StableAsset, [
        [token1.address, token2.address],
        [PRECISION, PRECISION],
        [MINT_FEE, SWAP_FEE, REDEEM_FEE],
        ethers.constants.AddressZero,
        yieldRecipient.address,
        poolToken.address,
        0,
        constant.address,
        1,
      ])
    ).to.be.revertedWith("fee recipient not set");

    /// Check deploy swap with yield recipient not set
    await expect(
      upgrades.deployProxy(StableAsset, [
        [token1.address, token2.address],
        [PRECISION, PRECISION],
        [MINT_FEE, SWAP_FEE, REDEEM_FEE],
        feeRecipient.address,
        ethers.constants.AddressZero,
        poolToken.address,
        0,
        constant.address,
        1,
      ])
    ).to.be.revertedWith("yield recipient not set");

    /// Check deploy swap with pool token not set
    await expect(
      upgrades.deployProxy(StableAsset, [
        [token1.address, token2.address],
        [PRECISION, PRECISION],
        [MINT_FEE, SWAP_FEE, REDEEM_FEE],
        feeRecipient.address,
        yieldRecipient.address,
        ethers.constants.AddressZero,
        0,
        constant.address,
        1,
      ])
    ).to.be.revertedWith("pool token not set");

    /// Check deploy swap with A not set
    await expect(
      upgrades.deployProxy(StableAsset, [
        [token1.address, token2.address],
        [PRECISION, PRECISION],
        [MINT_FEE, SWAP_FEE, REDEEM_FEE],
        feeRecipient.address,
        yieldRecipient.address,
        poolToken.address,
        0,
        constant.address,
        1,
      ])
    ).to.be.revertedWith("A not set");

    /// Check deploy swap with A exceed max
    await expect(
      upgrades.deployProxy(StableAsset, [
        [token1.address, token2.address],
        [PRECISION, PRECISION],
        [MINT_FEE, SWAP_FEE, REDEEM_FEE],
        feeRecipient.address,
        yieldRecipient.address,
        poolToken.address,
        1000000,
        constant.address,
        1,
      ])
    ).to.be.revertedWith("A not set");
  });

  it("should return the correct mint amount when two tokens are equal", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(
      deploySwapAndTokens
    );
    const [owner, feeRecipient] = await ethers.getSigners();

    /// Get mint amount with 100 token1 and 100 token2
    const amounts = await swap.getMintAmount([
      web3.utils.toWei("100"),
      web3.utils.toWei("100"),
    ]);
    /// Check amounts[0] is mint amount
    const mintAmount = amounts[0];
    /// Check amounts[1] is fee amount
    const feeAmount = amounts[1];
    /// Check total amount is correct
    const totalAmount = mintAmount.add(feeAmount);
    /// Check total amount is 200
    expect(totalAmount.toString()).to.equals(web3.utils.toWei("200"));
    /// Check fee amount is correct
    assertFee(totalAmount.toString(), feeAmount.toString(), MINT_FEE);
    /// Check invariant after mint
    assetInvariant(
      web3.utils.toWei("100"),
      web3.utils.toWei("100"),
      100,
      web3.utils.toWei("200")
    );
  });

  it("should return the correct mint amount when two tokens are not equal", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(
      deploySwapAndTokens
    );
    /// Get mint amount when token1 is 110 and token2 is 90
    const amounts = await swap.getMintAmount([
      web3.utils.toWei("110"),
      web3.utils.toWei("90"),
    ]);
    /// Check amounts[0] is mint amount
    const mintAmount = amounts[0];
    /// Check amounts[1] is fee amount
    const feeAmount = amounts[1];
    /// Check total amount is correct
    const totalAmount = mintAmount.add(feeAmount);
    /// Check total amount is 200
    assertFee(totalAmount.toString(), feeAmount.toString(), MINT_FEE);
    /// Check invariant after mint
    assetInvariant(
      web3.utils.toWei("100"),
      web3.utils.toWei("100"),
      100,
      web3.utils.toWei("200")
    );
  });

  it("should mint the correct amount when two tokens are equal", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(
      deploySwapAndTokens
    );
    const [owner, feeRecipient, user] = await ethers.getSigners();
    /// Unpause swap contract
    await swap.unpause();
    /// Mint 100 token1 to user
    await token1.mint(user.address, web3.utils.toWei("100"));
    /// Mint 100 token2 to user
    await token2.mint(user.address, web3.utils.toWei("100"));
    /// Approve swap contract to spend 100 token1
    await token1.connect(user).approve(swap.address, web3.utils.toWei("100"));
    /// Approve swap contract to spend 100 token2
    await token2.connect(user).approve(swap.address, web3.utils.toWei("100"));

    /// Get mint amount with 100 token1 and 100 token2
    // token1 and token2 has 8 decimals, so it's 100 token1 and 100 token2
    const amounts = await swap.getMintAmount([
      web3.utils.toWei("100"),
      web3.utils.toWei("100"),
    ]);
    /// Check amounts[0] is mint amount
    const mintAmount = amounts[0];
    console.log(mintAmount);
    /// Check amounts[1] is fee amount
    const feeAmount = amounts[1];
    console.log(feeAmount);
    const totalAmount = mintAmount.add(feeAmount);
    console.log(feeAmount);
    /// Check token1 balance is 100
    expect((await token1.balanceOf(user.address)).toString()).to.equals(
      web3.utils.toWei("100")
    );
    /// Check token2 balance is 100
    expect((await token2.balanceOf(user.address)).toString()).to.equals(
      web3.utils.toWei("100")
    );
    /// Check pool token balance is 0
    expect((await poolToken.balanceOf(user.address)).toString()).to.equals("0");
    /// Check fee recipient balance is 0
    expect(
      (await poolToken.balanceOf(feeRecipient.address)).toString()
    ).to.equals("0");
    /// Check swap token1 balance is 0
    expect((await swap.balances(0)).toString()).to.equals("0");
    /// Check swap token2 balance is 0
    expect((await swap.balances(1)).toString()).to.equals("0");
    /// Check swap total supply is 0
    expect((await swap.totalSupply()).toString()).to.equals("0");

    /// Mint 100 token1 and 100 token2 to pool token
    await swap
      .connect(user)
      .mint([web3.utils.toWei("100"), web3.utils.toWei("100")], 0);
    /// Check token1 balance is 0
    expect((await token1.balanceOf(user.address)).toString()).to.equals("0");
    /// Check token2 balance is 0
    expect((await token2.balanceOf(user.address)).toString()).to.equals("0");
    /// Check pool token balance is mint amount
    expect((await poolToken.balanceOf(user.address)).toString()).to.equals(
      totalAmount.toString()
    );
    expect((await poolToken.sharesOf(user.address)).toString()).to.equals(
      mintAmount.toString()
    );
    expect((await poolToken.getTotalShares()).toString()).to.equals(
      mintAmount.toString()
    );
    expect((await poolToken.totalSupply()).toString()).to.equals(
      totalAmount.toString()
    );
    /// Check fee recipient balance is fee amount
    // expect(
    //(await poolToken.balanceOf(feeRecipient.address)).toString()
    //).to.equals(feeAmount.toString());
    /// Check swap token1 balance is 100
    expect((await swap.balances(0)).toString()).to.equals(
      web3.utils.toWei("100")
    );
    /// Check swap token2 balance is 100
    expect((await swap.balances(1)).toString()).to.equals(
      web3.utils.toWei("100")
    );
    /// Check swap total supply is 200
    expect((await swap.totalSupply()).toString()).to.equals(
      web3.utils.toWei("200")
    );
    /// Check pool token total supply is 200
    expect((await swap.totalSupply()).toString()).to.equals(
      (await poolToken.totalSupply()).toString()
    );
  });

  it("should mint the correct amount when two tokens are not equal", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(
      deploySwapAndTokens
    );
    const [owner, feeRecipient, user] = await ethers.getSigners();
    /// Unpause swap contract
    await swap.unpause();
    /// Mint 110 token1 to user
    await token1.mint(user.address, web3.utils.toWei("110"));
    /// Mint 90 token2 to user
    await token2.mint(user.address, web3.utils.toWei("90"));
    /// Approve swap contract to spend 110 token1
    await token1.connect(user).approve(swap.address, web3.utils.toWei("110"));
    /// Approve swap contract to spend 90 token2
    await token2.connect(user).approve(swap.address, web3.utils.toWei("90"));

    /// Get mint amount with 110 token1 and 90 token2
    const amounts = await swap.getMintAmount([
      web3.utils.toWei("110"),
      web3.utils.toWei("90"),
    ]);
    /// Check amounts[0] is mint amount
    const mintAmount = amounts[0];
    /// Check amounts[1] is fee amount
    const feeAmount = amounts[1];
    const totalAmount = mintAmount.add(feeAmount);

    /// Check token1 balance is 110
    expect((await token1.balanceOf(user.address)).toString()).to.equals(
      web3.utils.toWei("110")
    );
    /// Check token2 balance is 90
    expect((await token2.balanceOf(user.address)).toString()).to.equals(
      web3.utils.toWei("90")
    );
    /// Check pool token balance is 0
    expect((await poolToken.balanceOf(user.address)).toString()).to.equals("0");
    /// Check fee recipient balance is 0
    //expect(
    //(await poolToken.balanceOf(feeRecipient.address)).toString()
    //).to.equals("0");
    /// Check swap token1 balance is 0
    expect((await swap.totalSupply()).toString()).to.equals("0");

    /// Mint 110 token1 and 90 token2 to pool token
    await swap
      .connect(user)
      .mint([web3.utils.toWei("110"), web3.utils.toWei("90")], 0);
    /// Check token1 balance is 0
    expect((await token1.balanceOf(user.address)).toString()).to.equals("0");
    /// Check token2 balance is 0
    expect((await token2.balanceOf(user.address)).toString()).to.equals("0");
    /// Check pool token balance is mint amount
    expect((await poolToken.balanceOf(user.address)).toString()).to.equals(
      totalAmount.toString()
    );
    expect((await poolToken.sharesOf(user.address)).toString()).to.equals(
      mintAmount.toString()
    );
    expect((await poolToken.getTotalShares()).toString()).to.equals(
      mintAmount.toString()
    );
    /// Check fee recipient balance is fee amount
    //expect(
    //(await poolToken.balanceOf(feeRecipient.address)).toString()
    //).to.equals(feeAmount.toString());
    /// Check swap token1 balance is 110
    expect((await swap.balances(0)).toString()).to.equals(
      web3.utils.toWei("110")
    );
    /// Check swap token2 balance is 90
    expect((await swap.balances(1)).toString()).to.equals(
      web3.utils.toWei("90")
    );
    /// Check swap total supply is about 200
    expect((await swap.totalSupply()).toString()).to.equals(
      "199994974999676499958"
    );
    /// Check pool token total supply is about 200
    expect((await poolToken.totalSupply()).toString()).to.equals(
      totalAmount.toString()
    );
  });

  it("should return the correct mint amount with initial balance when two tokens are not equal", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(
      deploySwapAndTokens
    );
    const [owner, feeRecipient, user] = await ethers.getSigners();

    /// Unpause swap contract
    await swap.unpause();
    /// Mint 105 token1 to user
    await token1.mint(user.address, web3.utils.toWei("105"));
    /// Mint 85 token2 to user
    await token2.mint(user.address, web3.utils.toWei("85"));
    /// Approve swap contract to spend 105 token1
    await token1.connect(user).approve(swap.address, web3.utils.toWei("105"));
    /// Approve swap contract to spend 85 token2
    await token2.connect(user).approve(swap.address, web3.utils.toWei("85"));
    /// Mint 105 token1 and 85 token2 to pool token
    await swap
      .connect(user)
      .mint([web3.utils.toWei("105"), web3.utils.toWei("85")], 0);

    /// Get mint amount with 110 token1 and 90 token2
    // token1 and token2 has 8 decimals, so it's 110 token1 and 90 token2
    const amounts = await swap.getMintAmount([
      web3.utils.toWei("110"),
      web3.utils.toWei("90"),
    ]);
    /// Check amounts[0] is mint amount
    const mintAmount = amounts[0];
    expect(mintAmount.toString()).to.equals("199794987163851160846");
    /// Check amounts[1] is fee amount
    const feeAmount = amounts[1];
    expect(feeAmount.toString()).to.equals("199994982145997158");
    /// Check total amount is mint amount + fee amount
    const totalAmount = mintAmount.add(feeAmount);
    expect(totalAmount.toString()).to.equals("199994982145997158004");
    /// Check fee amount is 0.1%
    assertFee(totalAmount.toString(), feeAmount.toString(), MINT_FEE);

    // Convert 110 token1 and 90 token2 to 18 decimals
    /// Check invariant is 110 * 90 = 9900
    assetInvariant(
      web3.utils.toWei("110"),
      web3.utils.toWei("90"),
      100,
      totalAmount
    );
  });

  it("should return the correct exchange amount", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(
      deploySwapAndTokens
    );
    const [owner, feeRecipient, user, user2] = await ethers.getSigners();

    /// Unpause swap contract
    await swap.unpause();
    // We use total amount to approximate D!
    /// Get mint amount with 105 token1 and 85 token2
    const amounts = await swap.getMintAmount([
      web3.utils.toWei("105"),
      web3.utils.toWei("85"),
    ]);
    /// Check total amount is mint amount + fee amount
    const totalAmount = amounts[0].add(amounts[1]);
    /// Mint 105 token1 to user
    await token1.mint(user.address, web3.utils.toWei("105"));
    /// Mint 85 token2 to user
    await token2.mint(user.address, web3.utils.toWei("85"));
    /// Approve swap contract to spend 105 token1
    await token1.connect(user).approve(swap.address, web3.utils.toWei("105"));
    /// Approve swap contract to spend 85 token2
    await token2.connect(user).approve(swap.address, web3.utils.toWei("85"));
    /// Mint 105 token1 and 85 token2 to pool token
    await swap
      .connect(user)
      .mint([web3.utils.toWei("105"), web3.utils.toWei("85")], 0);

    /// Mint 8 token2 to user2
    await token2.mint(user2.address, web3.utils.toWei("8"));
    /// Approve swap contract to spend 8 token2
    await token2.connect(user2).approve(swap.address, web3.utils.toWei("8"));
    /// Get exchange amount with 8 token2 to token1
    const exchangeAmount = await swap.getSwapAmount(
      1,
      0,
      web3.utils.toWei("8")
    );
    expect(exchangeAmount.toString()).to.equals(
      "7989075992756580743,16010172330173508"
    );
  });

  it("should exchange the correct amount", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(
      deploySwapAndTokens
    );
    const [owner, feeRecipient, user, user2] = await ethers.getSigners();

    /// Unpause swap contract
    await swap.unpause();
    /// Mint 105 token1 to user
    await token1.mint(user.address, web3.utils.toWei("105"));
    /// Mint 85 token2 to user
    await token2.mint(user.address, web3.utils.toWei("85"));
    /// Approve swap contract to spend 105 token1
    await token1.connect(user).approve(swap.address, web3.utils.toWei("105"));
    /// Approve swap contract to spend 85 token2
    await token2.connect(user).approve(swap.address, web3.utils.toWei("85"));
    /// Mint 105 token1 and 85 token2 to pool token
    await swap
      .connect(user)
      .mint([web3.utils.toWei("105"), web3.utils.toWei("85")], 0);

    /// Mint 8 token2 to user2
    await token2.mint(user2.address, web3.utils.toWei("8"));
    /// Approve swap contract to spend 8 token2
    await token2.connect(user2).approve(swap.address, web3.utils.toWei("8"));
    /// Get exchange amount with 8 token2 to token1
    const exchangeAmount = (
      await swap.getSwapAmount(1, 0, web3.utils.toWei("8"))
    )[0];
    /// Check user2 token1 balance is 0
    expect((await token1.balanceOf(user2.address)).toString()).to.equals("0");
    /// Check user2 token2 balance is 8
    expect((await token2.balanceOf(user2.address)).toString()).to.equals(
      web3.utils.toWei("8")
    );
    /// Check swap token1 balance is 105
    expect((await token1.balanceOf(swap.address)).toString()).to.equals(
      web3.utils.toWei("105")
    );
    /// Check swap token2 balance is 85
    expect((await token2.balanceOf(swap.address)).toString()).to.equals(
      web3.utils.toWei("85")
    );
    /// Check pool token1 balance is 105
    expect((await swap.balances(0)).toString()).to.equals(
      web3.utils.toWei("105")
    );
    /// Check pool token2 balance is 85
    expect((await swap.balances(1)).toString()).to.equals(
      web3.utils.toWei("85")
    );
    /// Check pool token balance is 190
    expect((await swap.totalSupply()).toString()).to.equals(
      "189994704791049550806"
    );
    expect((await swap.totalSupply()).toString()).to.equals(
      (await poolToken.totalSupply()).toString()
    );
    /// Get fee before exchange
    const feeBefore = new BN(
      (await poolToken.balanceOf(feeRecipient.address)).toString()
    );

    /// Swap 8 token2 to token1
    await swap.connect(user2).swap(1, 0, web3.utils.toWei("8"), 0);
    /// Get fee after exchange
    const feeAfter = new BN(
      (await poolToken.balanceOf(feeRecipient.address)).toString()
    );

    /// The amount of token1 got. In original format.
    expect((await token1.balanceOf(user2.address)).toString()).to.equals(
      exchangeAmount.toString()
    );
    /// The amount of token2 left. In original format.
    expect((await token2.balanceOf(user2.address)).toString()).to.equals("0");
    /// 105 token1 - actual exchange output  (in original format)
    expect((await token1.balanceOf(swap.address)).toString()).to.equals(
      new BN(web3.utils.toWei("105"))
        .sub(new BN(exchangeAmount.toString()))
        .toString()
    );
    /// 85 token2 + 8 token2  (in original format)
    expect((await token2.balanceOf(swap.address)).toString()).to.equals(
      web3.utils.toWei("93")
    );
    /// Check fee after exchange is greater than fee before exchange
    expect(feeAfter.gte(feeBefore)).to.equals(true);
    /// 85 token2 + 8 token2 (in converted format)
    expect((await swap.balances(1)).toString()).to.equals(
      web3.utils.toWei("93")
    );
    /// Check pool token balance same as swap token balance
    expect((await swap.totalSupply()).toString()).to.equals(
      (await poolToken.totalSupply()).toString()
    );
  });

  it("should return the correct redeem amount with proportional redemption", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(
      deploySwapAndTokens
    );
    const [owner, feeRecipient, user, user2] = await ethers.getSigners();
    await swap.unpause();
    /// We use total amount to approximate D!
    /// Get mint amount with 105 token1 and 85 token2
    const mintAmounts = await swap.getMintAmount([
      web3.utils.toWei("105"),
      web3.utils.toWei("85"),
    ]);
    /// Get total amount
    const totalAmount = new BN(mintAmounts[0].add(mintAmounts[1]).toString());
    /// Mint 105 token1 to user
    await token1.mint(user.address, web3.utils.toWei("105"));
    /// Mint 85 token2 to user
    await token2.mint(user.address, web3.utils.toWei("85"));
    /// Approve swap contract to spend 105 token1
    await token1.connect(user).approve(swap.address, web3.utils.toWei("105"));
    /// Approve swap contract to spend 85 token2
    await token2.connect(user).approve(swap.address, web3.utils.toWei("85"));
    /// Mint 105 token1 and 85 token2 to pool token
    await swap
      .connect(user)
      .mint([web3.utils.toWei("105"), web3.utils.toWei("85")], 0);

    /// Get redeem amount with 25 pool token
    const amounts = await swap.getRedeemProportionAmount(
      web3.utils.toWei("25")
    );
    /// Get token1 amount
    const token1Amount = new BN(amounts[0][0].toString());
    /// Get token2 amount
    const token2Amount = new BN(amounts[0][1].toString());
    /// Get fee amount
    const feeAmount = new BN(amounts[1].toString());

    /// Assert that poolToken redeemed / poolToken total = token1 amount / token1 balance = token2 amount / token2 balance
    assertAlmostTheSame(
      new BN(web3.utils.toWei("25"))
        .sub(feeAmount)
        .mul(new BN(web3.utils.toWei("105"))),
      new BN(token1Amount).mul(new BN(PRECISION)).mul(totalAmount)
    );
    assertAlmostTheSame(
      new BN(web3.utils.toWei("25"))
        .sub(feeAmount)
        .mul(new BN(web3.utils.toWei("85"))),
      new BN(token2Amount).mul(new BN(PRECISION)).mul(totalAmount)
    );

    /// Check invariant
    assetInvariant(
      new BN(web3.utils.toWei("105"))
        .sub(token1Amount.mul(new BN(PRECISION)))
        .toString(),
      new BN(web3.utils.toWei("85"))
        .sub(token2Amount.mul(new BN(PRECISION)))
        .toString(),
      100,
      totalAmount.sub(new BN(web3.utils.toWei("25")).sub(feeAmount)).toString()
    );
  });

  it("should redeem the correct amount with proportional redemption", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(
      deploySwapAndTokens
    );
    const [owner, feeRecipient, user, user2] = await ethers.getSigners();
    /// Unpause swap
    await swap.unpause();
    /// We use total amount to approximate D!
    /// Get mint amount with 105 token1 and 85 token2
    const mintAmounts = await swap.getMintAmount([
      web3.utils.toWei("105"),
      web3.utils.toWei("85"),
    ]);
    /// Get total amount
    const totalAmount = new BN(mintAmounts[0].add(mintAmounts[1]).toString());
    /// Mint 105 token1 to user
    await token1.mint(user.address, web3.utils.toWei("105"));
    /// Mint 85 token2 to user
    await token2.mint(user.address, web3.utils.toWei("85"));
    /// Approve swap contract to spend 105 token1
    await token1.connect(user).approve(swap.address, web3.utils.toWei("105"));
    /// Approve swap contract to spend 85 token2
    await token2.connect(user).approve(swap.address, web3.utils.toWei("85"));
    /// Mint 105 token1 and 85 token2 to pool token
    await swap
      .connect(user)
      .mint([web3.utils.toWei("105"), web3.utils.toWei("85")], 0);

    /// Get redeem amount with 25 pool token
    const amounts = await swap.getRedeemProportionAmount(
      web3.utils.toWei("25")
    );
    /// Get token1 amount
    const token1Amount = new BN(amounts[0][0].toString());
    /// Get token2 amount
    const token2Amount = new BN(amounts[0][1].toString());
    /// Get fee amount
    const feeAmount = new BN(amounts[1].toString());

    const totalShares = await poolToken.getTotalShares();
    const totalBalance = await poolToken.totalSupply();
    console.log(totalShares);
    console.log(totalBalance);
    /// Transfer 25 pool token to user2
    await poolToken
      .connect(user)
      .transfer(user2.address, web3.utils.toWei("25"));

    const shares2 = await poolToken.sharesOf(user2.address);
    const balance2 = await poolToken.balanceOf(user2.address);
    console.log(shares2);
    console.log(balance2);

    /// Check user2 token1 balance is 0
    expect((await token1.balanceOf(user2.address)).toString()).to.equals("0");
    /// Check user2 token2 balance is 0
    expect((await token2.balanceOf(user2.address)).toString()).to.equals("0");
    /// Check user2 pool token balance is 25
    // expect((await poolToken.balanceOf(user2.address)).toString()).to.equals(
    // web3.utils.toWei("25")
    //);
    /// Check swap token1 balance is 105
    expect((await token1.balanceOf(swap.address)).toString()).to.equals(
      web3.utils.toWei("105")
    );
    /// Check swap token2 balance is 85
    expect((await token2.balanceOf(swap.address)).toString()).to.equals(
      web3.utils.toWei("85")
    );
    /// Check swap pool token1 balance is 105
    expect((await swap.balances(0)).toString()).to.equals(
      web3.utils.toWei("105")
    );
    /// Check swap pool token2 balance is 85
    expect((await swap.balances(1)).toString()).to.equals(
      web3.utils.toWei("85")
    );
    /// Check swap total supply
    expect((await swap.totalSupply()).toString()).to.equals(
      "189994704791049550806"
    );
    /// Check pool token total supply is same as swap total supply
    expect((await poolToken.totalSupply()).toString()).to.equals(
      totalAmount.toString()
    );

    /// Get fee before
    //const feeBefore = new BN(
    // (await poolToken.balanceOf(feeRecipient.address)).toString()
    //);
    /// Approve swap contract to spend 8 token2
    const amountToReedem = await poolToken.balanceOf(user2.address);
    await poolToken.connect(user2).approve(swap.address, amountToReedem);
    console.log(await poolToken.balanceOf(user2.address));
    console.log(await poolToken.sharesOf(user2.address));
    /// Redeem 25 pool token
    await swap.connect(user2).redeemProportion(amountToReedem, [0, 0]);

    /// The amount of token1 got. In original format.
    /// Check user2 token1 balance is token1Amount
    expect((await token1.balanceOf(user2.address)).toString()).to.equals(
      token1Amount.toString()
    );
    /// Check user2 token2 balance is token2Amount
    expect((await token2.balanceOf(user2.address)).toString()).to.equals(
      token2Amount.toString()
    );
    console.log(await poolToken.balanceOf(user2.address));
    console.log(await poolToken.sharesOf(user2.address));

    /// Check user2 pool token balance is 0
    expect((await poolToken.sharesOf(user2.address)).toString()).to.equals("1");
    expect((await poolToken.balanceOf(user2.address)).toString()).to.equals(
      "1"
    );
    /// Check fee recipient pool token balance is feeAmount
    // assertAlmostTheSame(
    // new BN((await poolToken.balanceOf(feeRecipient.address)).toString()),
    //new BN(feeAmount.add(feeBefore).toString())
    //);
    /// Check swap token1 balance is 105 - token1Amount
    expect((await token1.balanceOf(swap.address)).toString()).to.equals(
      new BN(web3.utils.toWei("105")).sub(token1Amount).toString()
    );
    /// Check swap token2 balance is 85 - token2Amount
    expect((await token2.balanceOf(swap.address)).toString()).to.equals(
      new BN(web3.utils.toWei("85")).sub(token2Amount).toString()
    );
    /// Check swap pool token1 balance is 105 - token1Amount
    assertAlmostTheSame(
      new BN((await swap.balances(0)).toString()),
      new BN(web3.utils.toWei("105")).sub(token1Amount.mul(new BN(PRECISION)))
    );
    /// Check swap pool token2 balance is 85 - token2Amount
    assertAlmostTheSame(
      new BN((await swap.balances(1)).toString()),
      new BN(web3.utils.toWei("85")).sub(token2Amount.mul(new BN(PRECISION)))
    );
    /// Check swap total supply
    expect((await swap.totalSupply()).toString()).to.equals(
      (await poolToken.totalSupply()).toString()
    );
  });

  it("should return the correct redeem amount to a single token", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(
      deploySwapAndTokens
    );
    const [owner, feeRecipient, user, user2] = await ethers.getSigners();

    /// Unpause swap contract
    await swap.unpause();
    /// We use total amount to approximate D!
    /// Get mint amount with 105 token1 and 85 token2
    const mintAmounts = await swap.getMintAmount([
      web3.utils.toWei("105"),
      web3.utils.toWei("85"),
    ]);
    /// Get total amount
    const totalAmount = new BN(mintAmounts[0].add(mintAmounts[1]).toString());
    /// Mint 105 token1 to user
    await token1.mint(user.address, web3.utils.toWei("105"));
    /// Mint 85 token2 to user
    await token2.mint(user.address, web3.utils.toWei("85"));
    /// Approve swap contract to spend 105 token1
    await token1.connect(user).approve(swap.address, web3.utils.toWei("105"));
    /// Approve swap contract to spend 85 token2
    await token2.connect(user).approve(swap.address, web3.utils.toWei("85"));
    /// Mint 105 token1 and 85 token2 to swap contract
    await swap
      .connect(user)
      .mint([web3.utils.toWei("105"), web3.utils.toWei("85")], 0);

    /// Get redeem amount with 25 pool token
    const redeemAmount = web3.utils.toWei("25");
    /// Get redeem amount to a single token
    const amounts = await swap.getRedeemSingleAmount(redeemAmount, 0);
    /// Get token1 amount from amounts
    const token1Amount = new BN(amounts[0].toString());
    /// Get fee amount from amounts
    const feeAmount = new BN(amounts[1].toString());

    /// Assert invariant
    assetInvariant(
      new BN(web3.utils.toWei("105"))
        .sub(token1Amount.mul(new BN(PRECISION)))
        .toString(),
      web3.utils.toWei("85"),
      100,
      totalAmount.sub(new BN(redeemAmount).sub(feeAmount)).toString()
    );
  });

  it("should redeem the correct amount to a single token", async () => {
    /// Deploy swap and tokens
    const { swap, token1, token2, poolToken } = await loadFixture(
      deploySwapAndTokens
    );
    const [owner, feeRecipient, user, user2] = await ethers.getSigners();

    /// Unpause swap contract
    await swap.unpause();
    /// We use total amount to approximate D!
    /// Get mint amount with 105 token1 and 85 token2
    const mintAmounts = await swap.getMintAmount([
      web3.utils.toWei("105"),
      web3.utils.toWei("85"),
    ]);
    /// Get total amount
    const totalAmount = mintAmounts[0].add(mintAmounts[1]);
    /// Mint 105 token1 to user
    await token1.mint(user.address, web3.utils.toWei("105"));
    /// Mint 85 token2 to user
    await token2.mint(user.address, web3.utils.toWei("85"));
    /// Approve swap contract to spend 105 token1
    await token1.connect(user).approve(swap.address, web3.utils.toWei("105"));
    /// Approve swap contract to spend 85 token2
    await token2.connect(user).approve(swap.address, web3.utils.toWei("85"));
    /// Mint 105 token1 and 85 token2 to swap contract
    await swap
      .connect(user)
      .mint([web3.utils.toWei("105"), web3.utils.toWei("85")], 0);

    /// Get redeem amount to a single token
    const amounts = await swap.getRedeemSingleAmount(web3.utils.toWei("25"), 0);
    /// Get token1 amount from amounts
    const token1Amount = new BN(amounts[0].toString());
    /// Get fee amount from amounts
    const feeAmount = new BN(amounts[1].toString());

    /// Transfer 25 pool token to user2
    await poolToken
      .connect(user)
      .transfer(user2.address, web3.utils.toWei("25").toString());

    /// Check user2 token1 balance is 0
    expect((await token1.balanceOf(user2.address)).toString()).to.equals("0");
    /// Check user2 token2 balance is 0
    expect((await token2.balanceOf(user2.address)).toString()).to.equals("0");
    /// Check user2 swap pool token balance is 25
    // expect((await poolToken.balanceOf(user2.address)).toString()).to.equals(
    //redeemAmount.toString()
    //);
    /// Check swap pool token1 balance is 105
    expect((await token1.balanceOf(swap.address)).toString()).to.equals(
      web3.utils.toWei("105")
    );
    /// Check swap pool token2 balance is 85
    expect((await token2.balanceOf(swap.address)).toString()).to.equals(
      web3.utils.toWei("85")
    );
    /// Check swap pool token1 balance is 105
    expect((await swap.balances(0)).toString()).to.equals(
      web3.utils.toWei("105")
    );
    /// Check swap pool token2 balance is 85
    expect((await swap.balances(1)).toString()).to.equals(
      web3.utils.toWei("85")
    );
    /// Check swap pool total supply is same as pool token total supply
    expect((await swap.totalSupply()).toString()).to.equals(
      (await poolToken.totalSupply()).toString()
    );

    const redeemAmount = await poolToken.balanceOf(user2.address);
    /// Approve swap contract to spend 25 pool token
    await poolToken
      .connect(user2)
      .approve(swap.address, redeemAmount.toString());
    /// Redeem 25 pool token to token1

    await swap.connect(user2).redeemSingle(redeemAmount.toString(), 0, 0);

    /// The amount of token1 got. In original format.
    /// Check user2 token1 balance is token1Amount
    expect((await token1.balanceOf(user2.address)).toString()).to.equals(
      token1Amount.toString()
    );
    /// Check user2 token2 balance is 0
    expect((await token2.balanceOf(user2.address)).toString()).to.equals("0");
    /// Check user2 swap pool token balance is 0
    expect((await poolToken.balanceOf(user2.address)).toString()).to.equals(
      "1"
    );
    /// Check fee recipient pool token balance is feeAmount + feeBefore
    //expect(
    //(await poolToken.balanceOf(feeRecipient.address)).toString()
    //).to.equals(feeAmount.add(feeBefore).toString());
    /// Check swap pool token1 balance is 105 - token1Amount
    expect((await token1.balanceOf(swap.address)).toString()).to.equals(
      new BN(web3.utils.toWei("105")).sub(token1Amount).toString()
    );
    /// Check swap pool token2 balance is 85
    expect((await token2.balanceOf(swap.address)).toString()).to.equals(
      new BN(web3.utils.toWei("85")).toString()
    );
    /// Check swap pool token1 balance is 105 - token1Amount
    assertAlmostTheSame(
      new BN((await swap.balances(0)).toString()),
      new BN(web3.utils.toWei("105")).sub(token1Amount.mul(new BN(PRECISION)))
    );
    /// Check swap pool token2 balance is 85
    expect((await swap.balances(1)).toString()).to.equals(
      web3.utils.toWei("85")
    );
    /// Check swap pool total supply is same as pool token total supply
    expect((await swap.totalSupply()).toString()).to.equals(
      (await poolToken.totalSupply()).toString()
    );
  });

  it("should return the correct redeem amount to multiple tokens", async () => {
    /// Deploy swap contract
    const { swap, token1, token2, poolToken } = await loadFixture(
      deploySwapAndTokens
    );
    const [owner, feeRecipient, user, user2] = await ethers.getSigners();

    /// Unpause swap contract
    await swap.unpause();
    /// We use total amount to approximate D!
    /// Get mint amount with 105 token1 and 85 token2
    const mintAmounts = await swap.getMintAmount([
      web3.utils.toWei("105"),
      web3.utils.toWei("85"),
    ]);
    /// Get total amount
    const totalAmount = mintAmounts[0].add(mintAmounts[1]);
    /// Mint 105 token1 to user
    await token1.mint(user.address, web3.utils.toWei("105"));
    /// Mint 85 token2 to user
    await token2.mint(user.address, web3.utils.toWei("85"));
    /// Approve swap contract to spend 105 token1
    await token1.connect(user).approve(swap.address, web3.utils.toWei("105"));
    /// Approve swap contract to spend 85 token2
    await token2.connect(user).approve(swap.address, web3.utils.toWei("85"));
    /// Mint 105 token1 and 85 token2 to swap contract
    await swap
      .connect(user)
      .mint([web3.utils.toWei("105"), web3.utils.toWei("85")], 0);

    /// Get redeem amount with 10 token1 and 5 token2
    const amounts = await swap.getRedeemMultiAmount([
      web3.utils.toWei("10"),
      web3.utils.toWei("5"),
    ]);
    /// Get redeem amount from amounts
    const redeemAmount = amounts[0];
    /// Get fee amount from amounts
    const feeAmount = amounts[1];

    /// Check redeem amount
    assertFee(redeemAmount.toString(), feeAmount.toString(), REDEEM_FEE);
    /// Assert invariant
    assetInvariant(
      web3.utils.toWei("95"),
      web3.utils.toWei("80"),
      100,
      totalAmount.sub(redeemAmount.sub(feeAmount)).toString()
    );
  });
});
