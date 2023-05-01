import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers, upgrades, web3 } from "hardhat";

const PRECISION = '1';
const MINT_FEE = '10000000';
const SWAP_FEE = '20000000';
const REDEEM_FEE = '50000000';

describe("StableSwapApplication", function () {
  async function deploySwapAndTokens() {
    // Contracts are deployed using the first signer/account by default
    const [owner, feeRecipient, user, user2, yieldRecipient] = await ethers.getSigners();

    const StableSwap = await ethers.getContractFactory("StableSwap");
    const StableSwapApplication = await ethers.getContractFactory("StableSwapApplication");
    const MockToken = await ethers.getContractFactory("MockToken");
    const WETH = await ethers.getContractFactory("WETH9");
    const ACoconutBTC = await ethers.getContractFactory("StableSwapToken");

    const wETH = await WETH.deploy();
    const token2 = await MockToken.deploy("test 2", "T2", 18);
    const poolToken = await upgrades.deployProxy(ACoconutBTC, ["Pool Token", "PT"]);

    const swap = await upgrades.deployProxy(StableSwap, [[wETH.address, token2.address], [PRECISION, PRECISION], [MINT_FEE, SWAP_FEE, REDEEM_FEE], feeRecipient.address, yieldRecipient.address, poolToken.address, 100]);
    const application = await upgrades.deployProxy(StableSwapApplication, [wETH.address]);
    await poolToken.setMinter(swap.address, true);
    await swap.approve(wETH.address, swap.address);
    await swap.approve(token2.address, swap.address);
    return { swap, wETH, token2, poolToken, application };
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

  it('should redeem', async () => {
    const { swap, wETH, token2, poolToken, application } = await loadFixture(deploySwapAndTokens);
    const [owner, feeRecipient, user] = await ethers.getSigners();

    await swap.unpause();
    await token2.mint(user.address, web3.utils.toWei('100'));
    await token2.connect(user).approve(application.address, web3.utils.toWei('100'));
    await application.connect(user).mint(swap.address, [web3.utils.toWei('100'), web3.utils.toWei('100')], 0, { value: web3.utils.toWei('100') });
    await token2.mint(user.address, web3.utils.toWei('1'));

    const balanceBefore = await ethers.provider.getBalance(user.address);
    await poolToken.connect(user).approve(application.address, web3.utils.toWei('10'));
    await application.connect(user).redeemProportion(swap.address, web3.utils.toWei('10'), ['0', '0']);
    const balanceAfter = await ethers.provider.getBalance(user.address);
    expect(balanceAfter).to.greaterThan(balanceBefore);
    const balance = await token2.balanceOf(user.address);
    expect(balance).to.greaterThan(0);
  });
});
