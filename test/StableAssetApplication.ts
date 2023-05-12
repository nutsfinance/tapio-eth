import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers, upgrades, web3 } from "hardhat";

const PRECISION = '1';
const MINT_FEE = '10000000';
const SWAP_FEE = '20000000';
const REDEEM_FEE = '50000000';

describe("StableAssetApplication", function () {
  async function deploySwapAndTokens() {
    // Contracts are deployed using the first signer/account by default
    const [owner, feeRecipient, user, user2, yieldRecipient] = await ethers.getSigners();

    const StableAsset = await ethers.getContractFactory("StableAsset");
    const StableAssetApplication = await ethers.getContractFactory("StableAssetApplication");
    const MockToken = await ethers.getContractFactory("MockToken");
    const WETH = await ethers.getContractFactory("WETH9");
    const StableAssetToken = await ethers.getContractFactory("StableAssetToken");
    const ConstantExchangeRateProvider = await ethers.getContractFactory("ConstantExchangeRateProvider");
    const constant = await ConstantExchangeRateProvider.deploy();

    const wETH = await WETH.deploy();
    const token2 = await MockToken.deploy("test 2", "T2", 18);
    const poolToken = await upgrades.deployProxy(StableAssetToken, ["Pool Token", "PT"]);

    const swap = await upgrades.deployProxy(StableAsset, [[wETH.address, token2.address], [PRECISION, PRECISION], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeRecipient.address, yieldRecipient.address, poolToken.address, 100, constant.address, 1]);
    const application = await upgrades.deployProxy(StableAssetApplication, [wETH.address]);
    await poolToken.setMinter(swap.address, true);
    return { swap, wETH, token2, poolToken, application };
  }

  async function deploySwapAndTokensExchangeRate() {
    // Contracts are deployed using the first signer/account by default
    const [owner, feeRecipient, user, user2, yieldRecipient] = await ethers.getSigners();

    const StableAsset = await ethers.getContractFactory("StableAsset");
    const StableAssetApplication = await ethers.getContractFactory("StableAssetApplication");
    const MockToken = await ethers.getContractFactory("MockToken");
    const WETH = await ethers.getContractFactory("WETH9");
    const StableAssetToken = await ethers.getContractFactory("StableAssetToken");
    const MockTokenWithExchangeRate = await ethers.getContractFactory("MockExchangeRateProvider");

    const wETH = await WETH.deploy();
    const token2 = await MockToken.deploy("test 2", "T2", 18);
    const exchangeRate = await MockTokenWithExchangeRate.deploy("1000000000000000000", "18");
    const poolToken = await upgrades.deployProxy(StableAssetToken, ["Pool Token", "PT"]);

    const swap = await upgrades.deployProxy(StableAsset, [[wETH.address, token2.address], [PRECISION, PRECISION], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeRecipient.address, yieldRecipient.address, poolToken.address, 100, exchangeRate.address, 1]);
    const application = await upgrades.deployProxy(StableAssetApplication, [wETH.address]);
    await poolToken.setMinter(swap.address, true);
    return { swap, wETH, token2, poolToken, application };
  }

  async function deploySwapAndTokensForLst() {
    // Contracts are deployed using the first signer/account by default
    const [owner, feeRecipient, user, user2, yieldRecipient] = await ethers.getSigners();

    const StableAsset = await ethers.getContractFactory("StableAsset");
    const StableAssetApplication = await ethers.getContractFactory("StableAssetApplication");
    const MockToken = await ethers.getContractFactory("MockToken");
    const WETH = await ethers.getContractFactory("WETH9");
    const StableAssetToken = await ethers.getContractFactory("StableAssetToken");
    const ConstantExchangeRateProvider = await ethers.getContractFactory("ConstantExchangeRateProvider");
    const constant = await ConstantExchangeRateProvider.deploy();

    const wETH = await WETH.deploy();
    const token1 = await MockToken.deploy("test 1", "T1", 18);
    const token2 = await MockToken.deploy("test 2", "T2", 18);
    const poolToken = await upgrades.deployProxy(StableAssetToken, ["Pool Token", "PT"]);

    const swapOne = await upgrades.deployProxy(StableAsset, [[wETH.address, token1.address], [PRECISION, PRECISION], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeRecipient.address, yieldRecipient.address, poolToken.address, 100, constant.address, 1]);
    const swapTwo = await upgrades.deployProxy(StableAsset, [[wETH.address, token2.address], [PRECISION, PRECISION], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeRecipient.address, yieldRecipient.address, poolToken.address, 100, constant.address, 1]);
    const application = await upgrades.deployProxy(StableAssetApplication, [wETH.address]);
    await poolToken.setMinter(swapOne.address, true);
    await poolToken.setMinter(swapTwo.address, true);
    return { swapOne, swapTwo, wETH, token1, token2, poolToken, application };
  }

  it('should mint', async () => {
    const { swap, wETH, token2, poolToken, application } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user] = await ethers.getSigners();

    await swap.unpause();
    await token2.mint(user.address, web3.utils.toWei('100'));
    await token2.connect(user).approve(application.address, web3.utils.toWei('100'));
    await application.connect(user).mint(swap.address, [web3.utils.toWei('100'), web3.utils.toWei('100')], 0, { value: web3.utils.toWei('100') });

    const balance = await poolToken.balanceOf(user.address);
    expect(balance).to.greaterThan(0);
  });

  it('should swap with ETH', async () => {
    const { swap, wETH, token2, poolToken, application } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user] = await ethers.getSigners();

    await swap.unpause();
    await token2.mint(user.address, web3.utils.toWei('100'));
    await token2.connect(user).approve(application.address, web3.utils.toWei('100'));
    await application.connect(user).mint(swap.address, [web3.utils.toWei('100'), web3.utils.toWei('100')], 0, { value: web3.utils.toWei('100') });

    await application.connect(user).swap(swap.address, 0, 1, web3.utils.toWei('1'), 0, { value: web3.utils.toWei('1') });
    const balance = await token2.balanceOf(user.address);
    expect(balance).to.greaterThan(0);
  });

  it('should swap with token', async () => {
    const { swap, wETH, token2, poolToken, application } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user] = await ethers.getSigners();

    await swap.unpause();
    await token2.mint(user.address, web3.utils.toWei('100'));
    await token2.connect(user).approve(application.address, web3.utils.toWei('100'));
    await application.connect(user).mint(swap.address, [web3.utils.toWei('100'), web3.utils.toWei('100')], 0, { value: web3.utils.toWei('100') });
    await token2.mint(user.address, web3.utils.toWei('1'));

    await token2.connect(user).approve(application.address, web3.utils.toWei('1'));
    const balanceBefore = await ethers.provider.getBalance(user.address);
    await application.connect(user).swap(swap.address, 1, 0, web3.utils.toWei('1'), 0);
    const balanceAfter = await ethers.provider.getBalance(user.address);
    expect(balanceAfter).to.greaterThan(balanceBefore);
  });

  it('should swap with token with exchange rate', async () => {
    const { swap, wETH, token2, poolToken, application } = await loadFixture(deploySwapAndTokensExchangeRate);
    const [owner, feeRecipient, user] = await ethers.getSigners();

    await swap.unpause();
    await token2.mint(user.address, web3.utils.toWei('100'));
    await token2.connect(user).approve(application.address, web3.utils.toWei('100'));

    await application.connect(user).mint(swap.address, [web3.utils.toWei('100'), web3.utils.toWei('100')], 0, { value: web3.utils.toWei('100') });
    await token2.mint(user.address, web3.utils.toWei('1'));

    await token2.connect(user).approve(application.address, web3.utils.toWei('1'));
    const balanceBefore = await ethers.provider.getBalance(user.address);
    await application.connect(user).swap(swap.address, 1, 0, web3.utils.toWei('1'), 0);
    const balanceAfter = await ethers.provider.getBalance(user.address);
    expect(balanceAfter).to.greaterThan(balanceBefore);
  });

  it('should swap with eth with exchange rate', async () => {
    const { swap, wETH, token2, poolToken, application } = await loadFixture(deploySwapAndTokensExchangeRate);
    const [owner, feeRecipient, user] = await ethers.getSigners();

    await swap.unpause();
    await token2.mint(user.address, web3.utils.toWei('100'));
    await token2.connect(user).approve(application.address, web3.utils.toWei('100'));

    await application.connect(user).mint(swap.address, [web3.utils.toWei('100'), web3.utils.toWei('100')], 0, { value: web3.utils.toWei('100') });
    await token2.mint(user.address, web3.utils.toWei('1'));

    const balanceBefore = await token2.balanceOf(user.address);
    await application.connect(user).swap(swap.address, 0, 1, web3.utils.toWei('1'), 0, { value: web3.utils.toWei('1') });
    const balanceAfter = await token2.balanceOf(user.address);
    expect(balanceAfter).to.greaterThan(balanceBefore);
  });

  it('should redeem proportion', async () => {
    const { swap, wETH, token2, poolToken, application } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user] = await ethers.getSigners();

    await swap.unpause();
    await token2.mint(user.address, web3.utils.toWei('100'));
    await token2.connect(user).approve(application.address, web3.utils.toWei('100'));
    await application.connect(user).mint(swap.address, [web3.utils.toWei('100'), web3.utils.toWei('100')], 0, { value: web3.utils.toWei('100') });
    await token2.mint(user.address, web3.utils.toWei('1'));

    const balanceBefore = await ethers.provider.getBalance(user.address);
    const tokenBalanceBefore = await token2.balanceOf(user.address);
    await poolToken.connect(user).approve(application.address, web3.utils.toWei('10'));
    await application.connect(user).redeemProportion(swap.address, web3.utils.toWei('10'), ['0', '0']);
    const balanceAfter = await ethers.provider.getBalance(user.address);
    expect(balanceAfter).to.greaterThan(balanceBefore);
    const tokenBalanceAfter = await token2.balanceOf(user.address);
    expect(tokenBalanceAfter).to.greaterThan(tokenBalanceBefore);
  });

  it('should redeem single eth', async () => {
    const { swap, wETH, token2, poolToken, application } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user] = await ethers.getSigners();

    await swap.unpause();
    await token2.mint(user.address, web3.utils.toWei('100'));
    await token2.connect(user).approve(application.address, web3.utils.toWei('100'));
    await application.connect(user).mint(swap.address, [web3.utils.toWei('100'), web3.utils.toWei('100')], 0, { value: web3.utils.toWei('100') });
    await token2.mint(user.address, web3.utils.toWei('1'));

    const balanceBefore = await ethers.provider.getBalance(user.address);
    await poolToken.connect(user).approve(application.address, web3.utils.toWei('10'));
    await application.connect(user).redeemSingle(swap.address, web3.utils.toWei('10'), 0, 0);
    const balanceAfter = await ethers.provider.getBalance(user.address);
    expect(balanceAfter).to.greaterThan(balanceBefore);
  });

  it('should redeem single token', async () => {
    const { swap, wETH, token2, poolToken, application } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user] = await ethers.getSigners();

    await swap.unpause();
    await token2.mint(user.address, web3.utils.toWei('100'));
    await token2.connect(user).approve(application.address, web3.utils.toWei('100'));
    await application.connect(user).mint(swap.address, [web3.utils.toWei('100'), web3.utils.toWei('100')], 0, { value: web3.utils.toWei('100') });
    await token2.mint(user.address, web3.utils.toWei('1'));

    await poolToken.connect(user).approve(application.address, web3.utils.toWei('10'));
    const balanceBefore = await token2.balanceOf(user.address);
    await application.connect(user).redeemSingle(swap.address, web3.utils.toWei('10'), 1, 0);
    const balanceAfter = await token2.balanceOf(user.address);
    expect(balanceAfter).to.greaterThan(balanceBefore);
  });

  it('should return swap amount cross pool', async () => {
    const { swapOne, swapTwo, wETH, token1, token2, poolToken, application } = await loadFixture(deploySwapAndTokensForLst);
    const [owner, feeRecipient, user] = await ethers.getSigners();

    await swapTwo.unpause();
    await token2.mint(user.address, web3.utils.toWei('100'));
    await token2.connect(user).approve(application.address, web3.utils.toWei('100'));
    await application.connect(user).mint(swapTwo.address, [web3.utils.toWei('100'), web3.utils.toWei('100')], 0, { value: web3.utils.toWei('100') });

    await swapOne.unpause();
    await token1.mint(user.address, web3.utils.toWei('100'));
    await token1.connect(user).approve(application.address, web3.utils.toWei('100'));
    await application.connect(user).mint(swapOne.address, [web3.utils.toWei('100'), web3.utils.toWei('100')], 0, { value: web3.utils.toWei('100') });

    const amount = await application.getSwapAmountCrossPool(swapOne.address, swapTwo.address, token1.address, token2.address, web3.utils.toWei('1'));
    expect(amount).to.greaterThan(0);
  });

  it('should swap cross pool', async () => {
    const { swapOne, swapTwo, wETH, token1, token2, poolToken, application } = await loadFixture(deploySwapAndTokensForLst);
    const [owner, feeRecipient, user] = await ethers.getSigners();

    await swapTwo.unpause();
    await token2.mint(user.address, web3.utils.toWei('100'));
    await token2.connect(user).approve(application.address, web3.utils.toWei('100'));
    await application.connect(user).mint(swapTwo.address, [web3.utils.toWei('100'), web3.utils.toWei('100')], 0, { value: web3.utils.toWei('100') });

    await swapOne.unpause();
    await token1.mint(user.address, web3.utils.toWei('100'));
    await token1.connect(user).approve(application.address, web3.utils.toWei('100'));
    await application.connect(user).mint(swapOne.address, [web3.utils.toWei('100'), web3.utils.toWei('100')], 0, { value: web3.utils.toWei('100') });

    await token1.mint(user.address, web3.utils.toWei('1'));
    await token1.connect(user).approve(application.address, web3.utils.toWei('1'));

    const balanceBefore = await token2.balanceOf(user.address);
    await application.connect(user).swapCrossPool(swapOne.address, swapTwo.address, token1.address, token2.address, web3.utils.toWei('1'), '0');
    const balanceAfter = await token2.balanceOf(user.address);
    expect(balanceAfter).to.greaterThan(balanceBefore);
  });
});
