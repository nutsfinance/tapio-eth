import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers, upgrades, web3 } from "hardhat";

const PRECISION = "1";
const MINT_FEE = "10000000";
const SWAP_FEE = "20000000";
const REDEEM_FEE = "50000000";

describe("StableAssetApplication", function () {
  async function deploySwapAndTokens() {
    // Contracts are deployed using the first signer/account by default
    const [owner, feeRecipient, user, user2, yieldRecipient, governance] =
      await ethers.getSigners();

    const StableAsset = await ethers.getContractFactory("StableAsset");
    const StableAssetApplication = await ethers.getContractFactory(
      "StableAssetApplication"
    );
    const MockToken = await ethers.getContractFactory("MockToken");
    const WETH = await ethers.getContractFactory("WETH9");
    const StableAssetToken = await ethers.getContractFactory("TapETH");
    const ConstantExchangeRateProvider = await ethers.getContractFactory(
      "ConstantExchangeRateProvider"
    );
    const constant = await ConstantExchangeRateProvider.deploy();

    /// Deploy WETH contract
    const wETH = await WETH.deploy();
    /// Deploy token2 with name "test 2", symbol "T2", decimals 18
    const token2 = await MockToken.deploy("test 2", "T2", 18);
    // Deploy pool token with name "Pool Token", symbol "PT", decimals 18
    const poolToken = await upgrades.deployProxy(StableAssetToken, [
      governance.address,
    ]);

    /// Deploy swap contract with [wETH, token2], [precision, precision], [mint fee, swap fee, redeem fee], fee recipient feeRecipient, yield recipient yieldRecipient, pool token poolToken, A = 100 and ConstantExchangeRate
    const swap = await upgrades.deployProxy(StableAsset, [
      [wETH.address, token2.address],
      [PRECISION, PRECISION],
      [MINT_FEE, SWAP_FEE, REDEEM_FEE],
      feeRecipient.address,
      yieldRecipient.address,
      poolToken.address,
      100,
      constant.address,
      1,
    ]);
    /// Deploy application contract with WETH
    const application = await upgrades.deployProxy(StableAssetApplication, [
      wETH.address,
    ]);
    /// Set minter of pool token to be swap contract
    await poolToken.connect(governance).addPool(swap.address);
    await application.updatePool(swap.address, true);
    return { swap, wETH, token2, poolToken, application };
  }

  async function deploySwapAndTokensExchangeRate() {
    // Contracts are deployed using the first signer/account by default
    const [owner, feeRecipient, user, user2, yieldRecipient, governance] =
      await ethers.getSigners();

    const StableAsset = await ethers.getContractFactory("StableAsset");
    const StableAssetApplication = await ethers.getContractFactory(
      "StableAssetApplication"
    );
    const MockToken = await ethers.getContractFactory("MockToken");
    const WETH = await ethers.getContractFactory("WETH9");
    const StableAssetToken = await ethers.getContractFactory("TapETH");
    const MockTokenWithExchangeRate = await ethers.getContractFactory(
      "MockExchangeRateProvider"
    );

    const wETH = await WETH.deploy();
    const token2 = await MockToken.deploy("test 2", "T2", 18);
    const exchangeRate = await MockTokenWithExchangeRate.deploy(
      "1000000000000000000",
      "18"
    );
    const poolToken = await upgrades.deployProxy(StableAssetToken, [
      governance.address,
    ]);

    const swap = await upgrades.deployProxy(StableAsset, [
      [wETH.address, token2.address],
      [PRECISION, PRECISION],
      [MINT_FEE, SWAP_FEE, REDEEM_FEE],
      feeRecipient.address,
      yieldRecipient.address,
      poolToken.address,
      100,
      exchangeRate.address,
      1,
    ]);
    const application = await upgrades.deployProxy(StableAssetApplication, [
      wETH.address,
    ]);
    /// Set minter of pool token to be swap contract
    await poolToken.connect(governance).addPool(swap.address);
    await application.updatePool(swap.address, true);
    return { swap, wETH, token2, poolToken, application };
  }

  async function deploySwapAndTokensForLst() {
    // Contracts are deployed using the first signer/account by default
    const [owner, feeRecipient, user, user2, yieldRecipient, governance] =
      await ethers.getSigners();

    const StableAsset = await ethers.getContractFactory("StableAsset");
    const StableAssetApplication = await ethers.getContractFactory(
      "StableAssetApplication"
    );
    const MockToken = await ethers.getContractFactory("MockToken");
    const WETH = await ethers.getContractFactory("WETH9");
    const StableAssetToken = await ethers.getContractFactory("TapETH");
    const ConstantExchangeRateProvider = await ethers.getContractFactory(
      "ConstantExchangeRateProvider"
    );
    const constant = await ConstantExchangeRateProvider.deploy();

    const wETH = await WETH.deploy();
    /// Deploy token1 with name "test 1", symbol "T1", decimals 18
    const token1 = await MockToken.deploy("test 1", "T1", 18);
    /// Deploy token2 with name "test 2", symbol "T2", decimals 18
    const token2 = await MockToken.deploy("test 2", "T2", 18);
    /// Deploy pool token with name "Pool Token", symbol "PT", decimals 18
    const poolToken = await upgrades.deployProxy(StableAssetToken, [
      governance.address,
    ]);

    /// Deploy swap contract with [wETH, token1], [precision, precision], [mint fee, swap fee, redeem fee], fee recipient feeRecipient, yield recipient yieldRecipient, pool token poolToken, A = 100 and ConstantExchangeRate
    const swapOne = await upgrades.deployProxy(StableAsset, [
      [wETH.address, token1.address],
      [PRECISION, PRECISION],
      [MINT_FEE, SWAP_FEE, REDEEM_FEE],
      feeRecipient.address,
      yieldRecipient.address,
      poolToken.address,
      100,
      constant.address,
      1,
    ]);
    /// Deploy swap contract with [wETH, token2], [precision, precision], [mint fee, swap fee, redeem fee], fee recipient feeRecipient, yield recipient yieldRecipient, pool token poolToken, A = 100 and ConstantExchangeRate
    const swapTwo = await upgrades.deployProxy(StableAsset, [
      [wETH.address, token2.address],
      [PRECISION, PRECISION],
      [MINT_FEE, SWAP_FEE, REDEEM_FEE],
      feeRecipient.address,
      yieldRecipient.address,
      poolToken.address,
      100,
      constant.address,
      1,
    ]);
    /// Deploy application contract with WETH
    const application = await upgrades.deployProxy(StableAssetApplication, [
      wETH.address,
    ]);
    /// Set minter of pool token to be swapOne contract
    await poolToken.connect(governance).addPool(swapOne.address);
    /// Set minter of pool token to be swapTwo contract
    await poolToken.connect(governance).addPool(swapTwo.address);
    await application.updatePool(swapOne.address, true);
    await application.updatePool(swapTwo.address, true);
    return { swapOne, swapTwo, wETH, token1, token2, poolToken, application };
  }

  it("should mint", async () => {
    /// Deploy swap and tokens
    const { swap, wETH, token2, poolToken, application } = await loadFixture(
      deploySwapAndTokens
    );
    const [owner, feeRecipient, user] = await ethers.getSigners();

    /// Unpause swap contract
    await swap.unpause();
    /// Mint 100 token2 to user
    await token2.mint(user.address, web3.utils.toWei("100"));
    /// Approve application contract to spend 100 token2
    await token2
      .connect(user)
      .approve(application.address, web3.utils.toWei("100"));
    /// Mint 100 ETH and 100 token2 to swap contract
    await application
      .connect(user)
      .mint(
        swap.address,
        [web3.utils.toWei("100"), web3.utils.toWei("100")],
        0,
        { value: web3.utils.toWei("100") }
      );

    /// Check balance of pool token of user is greater than 0
    const balance = await poolToken.balanceOf(user.address);
    expect(balance).to.greaterThan(0);
  });

  it("should swap with ETH", async () => {
    /// Deploy swap and tokens
    const { swap, wETH, token2, poolToken, application } = await loadFixture(
      deploySwapAndTokens
    );
    const [owner, feeRecipient, user] = await ethers.getSigners();

    /// Unpause swap contract
    await swap.unpause();
    /// Mint 100 token2 to user
    await token2.mint(user.address, web3.utils.toWei("100"));
    /// Approve application contract to spend 100 token2
    await token2
      .connect(user)
      .approve(application.address, web3.utils.toWei("100"));
    /// Mint 100 ETH and 100 token2 to swap contract
    await application
      .connect(user)
      .mint(
        swap.address,
        [web3.utils.toWei("100"), web3.utils.toWei("100")],
        0,
        { value: web3.utils.toWei("100") }
      );

    /// Swap 1 ETH to token2
    await application
      .connect(user)
      .swap(swap.address, 0, 1, web3.utils.toWei("1"), 0, {
        value: web3.utils.toWei("1"),
      });
    /// Check balance of token2 of user is greater than 0
    const balance = await token2.balanceOf(user.address);
    expect(balance).to.greaterThan(0);
  });

  it("should swap with token", async () => {
    /// Deploy swap and tokens
    const { swap, wETH, token2, poolToken, application } = await loadFixture(
      deploySwapAndTokens
    );
    const [owner, feeRecipient, user] = await ethers.getSigners();

    /// Unpause swap contract
    await swap.unpause();
    /// Mint 100 token2 to user
    await token2.mint(user.address, web3.utils.toWei("100"));
    /// Approve application contract to spend 100 token2
    await token2
      .connect(user)
      .approve(application.address, web3.utils.toWei("100"));
    /// Mint 100 ETH and 100 token2 to swap contract
    await application
      .connect(user)
      .mint(
        swap.address,
        [web3.utils.toWei("100"), web3.utils.toWei("100")],
        0,
        { value: web3.utils.toWei("100") }
      );
    /// Mint 1 token2 to user
    await token2.mint(user.address, web3.utils.toWei("1"));

    /// Approve application contract to spend 1 token2
    await token2
      .connect(user)
      .approve(application.address, web3.utils.toWei("1"));
    /// Get balance of user before swap
    const balanceBefore = await ethers.provider.getBalance(user.address);
    /// Swap 1 token2 to ETH
    await application
      .connect(user)
      .swap(swap.address, 1, 0, web3.utils.toWei("1"), 0);
    /// Get balance of user after swap and check it is greater than before
    const balanceAfter = await ethers.provider.getBalance(user.address);
    expect(balanceAfter).to.greaterThan(balanceBefore);
  });

  it("should swap with token with exchange rate", async () => {
    const { swap, wETH, token2, poolToken, application } = await loadFixture(
      deploySwapAndTokensExchangeRate
    );
    const [owner, feeRecipient, user] = await ethers.getSigners();

    await swap.unpause();
    await token2.mint(user.address, web3.utils.toWei("100"));
    await token2
      .connect(user)
      .approve(application.address, web3.utils.toWei("100"));

    await application
      .connect(user)
      .mint(
        swap.address,
        [web3.utils.toWei("100"), web3.utils.toWei("100")],
        0,
        { value: web3.utils.toWei("100") }
      );
    await token2.mint(user.address, web3.utils.toWei("1"));

    await token2
      .connect(user)
      .approve(application.address, web3.utils.toWei("1"));
    const balanceBefore = await ethers.provider.getBalance(user.address);
    await application
      .connect(user)
      .swap(swap.address, 1, 0, web3.utils.toWei("1"), 0);
    const balanceAfter = await ethers.provider.getBalance(user.address);
    expect(balanceAfter).to.greaterThan(balanceBefore);
  });

  it("should swap with eth with exchange rate", async () => {
    const { swap, wETH, token2, poolToken, application } = await loadFixture(
      deploySwapAndTokensExchangeRate
    );
    const [owner, feeRecipient, user] = await ethers.getSigners();

    await swap.unpause();
    await token2.mint(user.address, web3.utils.toWei("100"));
    await token2
      .connect(user)
      .approve(application.address, web3.utils.toWei("100"));

    await application
      .connect(user)
      .mint(
        swap.address,
        [web3.utils.toWei("100"), web3.utils.toWei("100")],
        0,
        { value: web3.utils.toWei("100") }
      );
    await token2.mint(user.address, web3.utils.toWei("1"));

    const balanceBefore = await token2.balanceOf(user.address);
    await application
      .connect(user)
      .swap(swap.address, 0, 1, web3.utils.toWei("1"), 0, {
        value: web3.utils.toWei("1"),
      });
    const balanceAfter = await token2.balanceOf(user.address);
    expect(balanceAfter).to.greaterThan(balanceBefore);
  });

  it("should redeem proportion", async () => {
    /// Deploy swap and tokens
    const { swap, wETH, token2, poolToken, application } = await loadFixture(
      deploySwapAndTokens
    );
    const [owner, feeRecipient, user] = await ethers.getSigners();

    /// Unpause swap contract
    await swap.unpause();
    /// Mint 100 token2 to user
    await token2.mint(user.address, web3.utils.toWei("100"));
    /// Approve application contract to spend 100 token2
    await token2
      .connect(user)
      .approve(application.address, web3.utils.toWei("100"));
    /// Mint 100 ETH and 100 token2 to swap contract
    await application
      .connect(user)
      .mint(
        swap.address,
        [web3.utils.toWei("100"), web3.utils.toWei("100")],
        0,
        { value: web3.utils.toWei("100") }
      );
    /// Mint 1 token2 to user
    await token2.mint(user.address, web3.utils.toWei("1"));

    /// Get balance of user before redeem
    const balanceBefore = await ethers.provider.getBalance(user.address);
    /// Get token2 balance of user before redeem
    const tokenBalanceBefore = await token2.balanceOf(user.address);
    /// Approve application contract to spend 10 pool token
    await poolToken
      .connect(user)
      .approve(application.address, web3.utils.toWei("10"));
    /// Redeem 10 pool token
    await application
      .connect(user)
      .redeemProportion(swap.address, web3.utils.toWei("10"), ["0", "0"]);
    /// Get balance of user after redeem and check it is greater than before
    const balanceAfter = await ethers.provider.getBalance(user.address);
    /// Get token2 balance of user after redeem and check it is greater than before
    expect(balanceAfter).to.greaterThan(balanceBefore);
    /// Check token2 balance of user is greater than before
    const tokenBalanceAfter = await token2.balanceOf(user.address);
    expect(tokenBalanceAfter).to.greaterThan(tokenBalanceBefore);
  });

  it("should redeem single eth", async () => {
    /// Deploy swap and tokens
    const { swap, wETH, token2, poolToken, application } = await loadFixture(
      deploySwapAndTokens
    );
    const [owner, feeRecipient, user] = await ethers.getSigners();

    /// Unpause swap contract
    await swap.unpause();
    /// Mint 100 token2 to user
    await token2.mint(user.address, web3.utils.toWei("100"));
    /// Approve application contract to spend 100 token2
    await token2
      .connect(user)
      .approve(application.address, web3.utils.toWei("100"));
    /// Mint 100 ETH and 100 token2 to swap contract
    await application
      .connect(user)
      .mint(
        swap.address,
        [web3.utils.toWei("100"), web3.utils.toWei("100")],
        0,
        { value: web3.utils.toWei("100") }
      );
    /// Mint 1 token2 to user
    await token2.mint(user.address, web3.utils.toWei("1"));

    /// Get balance of user before redeem
    const balanceBefore = await ethers.provider.getBalance(user.address);
    /// Approve application contract to spend 10 pool token
    await poolToken
      .connect(user)
      .approve(application.address, web3.utils.toWei("10"));
    /// Redeem 10 pool token to ETH
    await application
      .connect(user)
      .redeemSingle(swap.address, web3.utils.toWei("10"), 0, 0);
    /// Get balance of user after redeem and check it is greater than before
    const balanceAfter = await ethers.provider.getBalance(user.address);
    expect(balanceAfter).to.greaterThan(balanceBefore);
  });

  it("should redeem single token", async () => {
    /// Deploy swap and tokens
    const { swap, wETH, token2, poolToken, application } = await loadFixture(
      deploySwapAndTokens
    );
    const [owner, feeRecipient, user] = await ethers.getSigners();

    /// Unpause swap contract
    await swap.unpause();
    /// Mint 100 token2 to user
    await token2.mint(user.address, web3.utils.toWei("100"));
    /// Approve application contract to spend 100 token2
    await token2
      .connect(user)
      .approve(application.address, web3.utils.toWei("100"));
    /// Mint 100 ETH and 100 token2 to swap contract
    await application
      .connect(user)
      .mint(
        swap.address,
        [web3.utils.toWei("100"), web3.utils.toWei("100")],
        0,
        { value: web3.utils.toWei("100") }
      );
    /// Mint 1 token2 to user
    await token2.mint(user.address, web3.utils.toWei("1"));

    /// Approve application contract to spend 10 pool token
    await poolToken
      .connect(user)
      .approve(application.address, web3.utils.toWei("10"));
    /// Get balance of user before redeem
    const balanceBefore = await token2.balanceOf(user.address);
    /// Redeem 10 pool token to token2
    await application
      .connect(user)
      .redeemSingle(swap.address, web3.utils.toWei("10"), 1, 0);
    /// Get balance of user after redeem and check it is greater than before
    const balanceAfter = await token2.balanceOf(user.address);
    expect(balanceAfter).to.greaterThan(balanceBefore);
  });

  it("should return swap amount cross pool", async () => {
    /// Deploy swap and tokens
    const { swapOne, swapTwo, wETH, token1, token2, poolToken, application } =
      await loadFixture(deploySwapAndTokensForLst);
    const [owner, feeRecipient, user] = await ethers.getSigners();

    /// Unpause swapTwo contract
    await swapTwo.unpause();
    /// Mint 100 token2 to user
    await token2.mint(user.address, web3.utils.toWei("100"));
    /// Approve application contract to spend 100 token2
    await token2
      .connect(user)
      .approve(application.address, web3.utils.toWei("100"));
    /// Mint 100 ETH and 100 token2 to swap contract
    await application
      .connect(user)
      .mint(
        swapTwo.address,
        [web3.utils.toWei("100"), web3.utils.toWei("100")],
        0,
        { value: web3.utils.toWei("100") }
      );

    /// Unpause swapOne contract
    await swapOne.unpause();
    /// Mint 100 token1 to user
    await token1.mint(user.address, web3.utils.toWei("100"));
    /// Approve application contract to spend 100 token1
    await token1
      .connect(user)
      .approve(application.address, web3.utils.toWei("100"));
    /// Mint 100 ETH and 100 token1 to swap contract
    await application
      .connect(user)
      .mint(
        swapOne.address,
        [web3.utils.toWei("100"), web3.utils.toWei("100")],
        0,
        { value: web3.utils.toWei("100") }
      );

    /// Get swap amount cross pool with token1 to token2
    const amount = await application.getSwapAmountCrossPool(
      swapOne.address,
      swapTwo.address,
      token1.address,
      token2.address,
      web3.utils.toWei("1")
    );
    /// Check amount is greater than 0
    expect(amount.toString()).to.equal("993980347757552144,5994925804469116");
  });

  it("should swap cross pool", async () => {
    /// Deploy swap and tokens
    const { swapOne, swapTwo, wETH, token1, token2, poolToken, application } =
      await loadFixture(deploySwapAndTokensForLst);
    const [owner, feeRecipient, user] = await ethers.getSigners();

    /// Unpause swapTwo contract
    await swapTwo.unpause();
    /// Mint 100 token2 to user
    await token2.mint(user.address, web3.utils.toWei("100"));
    /// Approve application contract to spend 100 token2
    await token2
      .connect(user)
      .approve(application.address, web3.utils.toWei("100"));
    /// Mint 100 ETH and 100 token2 to swap contract
    await application
      .connect(user)
      .mint(
        swapTwo.address,
        [web3.utils.toWei("100"), web3.utils.toWei("100")],
        0,
        { value: web3.utils.toWei("100") }
      );

    /// Unpause swapOne contract
    await swapOne.unpause();
    /// Mint 100 token1 to user
    await token1.mint(user.address, web3.utils.toWei("100"));
    /// Approve application contract to spend 100 token1
    await token1
      .connect(user)
      .approve(application.address, web3.utils.toWei("100"));
    /// Mint 100 ETH and 100 token1 to swap contract
    await application
      .connect(user)
      .mint(
        swapOne.address,
        [web3.utils.toWei("100"), web3.utils.toWei("100")],
        0,
        { value: web3.utils.toWei("100") }
      );

    /// Mint 1 token1 to user
    await token1.mint(user.address, web3.utils.toWei("1"));
    /// Approve application contract to spend 1 token1
    await token1
      .connect(user)
      .approve(application.address, web3.utils.toWei("1"));

    /// Get balance of user before swap
    const balanceBefore = await token2.balanceOf(user.address);
    /// Swap 1 token1 to token2
    await application
      .connect(user)
      .swapCrossPool(
        swapOne.address,
        swapTwo.address,
        token1.address,
        token2.address,
        web3.utils.toWei("1"),
        "0"
      );
    /// Get balance of user after swap and check it is greater than before
    const balanceAfter = await token2.balanceOf(user.address);
    expect(balanceAfter).to.greaterThan(balanceBefore);
  });
});
