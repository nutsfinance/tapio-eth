// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Vm } from "forge-std/Vm.sol";
import { Test, console2 } from "forge-std/Test.sol";

import { SelfPeggingAssetFactory } from "../src/SelfPeggingAssetFactory.sol";
import { MockToken } from "../src/mock/MockToken.sol";
import { SelfPeggingAsset } from "../src/SelfPeggingAsset.sol";
import { LPToken } from "../src/LPToken.sol";
import { WLPToken } from "../src/WLPToken.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "../src/misc/ConstantExchangeRateProvider.sol";
import "../src/mock/MockExchangeRateProvider.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract SelfPeggingAssetTest is Test {
    address owner = address(0x01);
    address user = address(0x02);
    address user2 = address(0x03);
    uint256 A = 100;
    LPToken lpToken;
    SelfPeggingAsset pool; // WETH and frxETH Pool
    uint256 feeDenominator = 10_000_000_000;
    uint256 mintFee = 10_000_000;
    uint256 swapFee = 20_000_000;
    uint256 redeemFee = 50_000_000;
    MockToken WETH;
    MockToken frxETH;
    uint256[] precisions;

    function setUp() public {
        WETH = new MockToken("WETH", "WETH", 18);
        frxETH = new MockToken("frxETH", "frxETH", 18);

        bytes memory data = abi.encodeCall(LPToken.initialize, ("LP Token", "LPT"));

        ERC1967Proxy proxy = new ERC1967Proxy(address(new LPToken()), data);

        lpToken = LPToken(address(proxy));
        lpToken.transferOwnership(owner);

        ConstantExchangeRateProvider exchangeRateProvider = new ConstantExchangeRateProvider();

        address[] memory tokens = new address[](2);
        tokens[0] = address(WETH);
        tokens[1] = address(frxETH);

        precisions = new uint256[](2);
        precisions[0] = 1;
        precisions[1] = 1;

        uint256[] memory fees = new uint256[](3);
        fees[0] = mintFee;
        fees[1] = swapFee;
        fees[2] = redeemFee;

        IExchangeRateProvider[] memory exchangeRateProviders = new IExchangeRateProvider[](2);
        exchangeRateProviders[0] = exchangeRateProvider;
        exchangeRateProviders[1] = exchangeRateProvider;

        data = abi.encodeCall(
            SelfPeggingAsset.initialize, (tokens, precisions, fees, 0, lpToken, A, exchangeRateProviders, address(0), 0)
        );

        proxy = new ERC1967Proxy(address(new SelfPeggingAsset()), data);

        pool = SelfPeggingAsset(address(proxy));
        pool.transferOwnership(owner);

        vm.prank(owner);
        lpToken.addPool(address(pool));
    }

    function test_CorrectMintAmount_EqualTokenAmounts() external {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e18;
        amounts[1] = 100e18;

        WETH.mint(user, 100e18);
        frxETH.mint(user, 100e18);

        vm.startPrank(user);
        WETH.approve(address(pool), 100e18);
        frxETH.approve(address(pool), 100e18);
        vm.stopPrank();

        (uint256 lpTokensMinted, uint256 feesCharged) = pool.getMintAmount(amounts);

        uint256 totalAmount = lpTokensMinted + feesCharged;
        assertEq(totalAmount, 200e18);

        assertEq(100e18, WETH.balanceOf(user));
        assertEq(100e18, frxETH.balanceOf(user));
        assertEq(0, lpToken.balanceOf(user));
        assertEq(0, pool.balances(0));
        assertEq(0, pool.balances(1));
        assertEq(0, pool.totalSupply());

        vm.prank(user);
        pool.mint(amounts, 0);

        assertEq(0, WETH.balanceOf(user));
        assertEq(0, frxETH.balanceOf(user));
        assertIsCloseTo(totalAmount, lpToken.balanceOf(user) + lpToken.NUMBER_OF_DEAD_SHARES(), 2 wei);
        assertEq(lpTokensMinted, lpToken.sharesOf(user) + lpToken.NUMBER_OF_DEAD_SHARES());
        assertEq(totalAmount, lpToken.totalSupply());
    }

    function test_Pegging_UnderlyingToken() external {
        MockExchangeRateProvider rETHExchangeRateProvider = new MockExchangeRateProvider(1.1e18, 18);
        MockExchangeRateProvider wstETHExchangeRateProvider = new MockExchangeRateProvider(1.2e18, 18);

        MockToken rETH = new MockToken("rETH", "rETH", 18);
        MockToken wstETH = new MockToken("wstETH", "wstETH", 18);

        address[] memory _tokens = new address[](2);
        _tokens[0] = address(rETH);
        _tokens[1] = address(wstETH);

        IExchangeRateProvider[] memory exchangeRateProviders = new IExchangeRateProvider[](2);
        exchangeRateProviders[0] = IExchangeRateProvider(rETHExchangeRateProvider);
        exchangeRateProviders[1] = IExchangeRateProvider(wstETHExchangeRateProvider);

        // SelfPeggingAsset _pool = new SelfPeggingAsset();
        // LPToken _lpToken = new LPToken();

        bytes memory data = abi.encodeCall(LPToken.initialize, ("LP Token", "LPT"));

        ERC1967Proxy proxy = new ERC1967Proxy(address(new LPToken()), data);
        LPToken _lpToken = LPToken(address(proxy));
        _lpToken.transferOwnership(owner);

        uint256[] memory _fees = new uint256[](3);
        _fees[0] = 0;
        _fees[1] = 0;
        _fees[2] = 0;

        uint256[] memory _precisions = new uint256[](2);
        _precisions[0] = 1;
        _precisions[1] = 1;

        data = abi.encodeCall(
            SelfPeggingAsset.initialize,
            (_tokens, _precisions, _fees, 0, _lpToken, A, exchangeRateProviders, address(0), 0)
        );

        proxy = new ERC1967Proxy(address(new SelfPeggingAsset()), data);
        SelfPeggingAsset _pool = SelfPeggingAsset(address(proxy));

        vm.prank(owner);
        _lpToken.addPool(address(_pool));

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 110e18;
        amounts[1] = 90e18;

        (uint256 lpTokensMinted,) = _pool.getMintAmount(amounts);

        assertIsCloseTo(lpTokensMinted, 229e18, 0.01e18);
    }

    function test_exchangeCorrectAmount() external {
        WETH.mint(user, 105e18);
        frxETH.mint(user, 85e18);

        vm.startPrank(user);
        WETH.approve(address(pool), 105e18);
        frxETH.approve(address(pool), 85e18);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 105e18;
        amounts[1] = 85e18;

        pool.mint(amounts, 0);
        vm.stopPrank();

        frxETH.mint(user2, 8e18);
        vm.startPrank(user2);
        frxETH.approve(address(pool), 8e18);
        vm.stopPrank();

        (uint256 exchangeAmount,) = pool.getSwapAmount(1, 0, 8e18);

        assertEq(WETH.balanceOf(user2), 0);
        assertEq(frxETH.balanceOf(user2), 8e18);

        assertEq(WETH.balanceOf(address(pool)), 105e18);
        assertEq(frxETH.balanceOf(address(pool)), 85e18);

        assertEq(pool.balances(0), 105e18);
        assertEq(pool.balances(1), 85e18);

        assertEq(pool.totalSupply(), 189.994704791049550806e18);

        assertEq(pool.totalSupply(), lpToken.totalSupply());

        vm.prank(user2);
        pool.swap(1, 0, 8e18, 0);

        assertEq(WETH.balanceOf(user2), exchangeAmount);
        assertEq(frxETH.balanceOf(user2), 0);

        assertEq(WETH.balanceOf(address(pool)), 105e18 - exchangeAmount);
        assertEq(frxETH.balanceOf(address(pool)), 85e18 + 8e18);
        assertEq(pool.totalSupply(), lpToken.totalSupply());
    }

    function test_redeemCorrectAmountWithProportionalRedemption() external {
        uint256[] memory mintAmounts = new uint256[](2);
        mintAmounts[0] = 105e18;
        mintAmounts[1] = 85e18;

        uint256 totalAmount = mintAmounts[0] + mintAmounts[1];

        WETH.mint(user, 105e18);
        frxETH.mint(user, 85e18);

        vm.startPrank(user);
        WETH.approve(address(pool), 105e18);
        frxETH.approve(address(pool), 85e18);

        pool.mint(mintAmounts, 0);
        vm.stopPrank();

        (uint256[] memory tokenAmounts,) = pool.getRedeemProportionAmount(25e18);
        uint256 token1Amount = tokenAmounts[0];
        uint256 token2Amount = tokenAmounts[1];

        uint256 totalShares = lpToken.totalShares();
        uint256 totalBalance = lpToken.totalSupply();

        vm.prank(user);
        lpToken.transfer(user2, 25e18);

        uint256 shares2 = lpToken.sharesOf(user2);
        uint256 balance2 = lpToken.balanceOf(user2);

        assertEq(WETH.balanceOf(user2), 0);
        assertEq(frxETH.balanceOf(user2), 0);

        assertEq(WETH.balanceOf(address(pool)), 105e18);
        assertEq(frxETH.balanceOf(address(pool)), 85e18);

        assertEq(pool.balances(0), 105e18);
        assertEq(pool.balances(1), 85e18);

        assertEq(pool.totalSupply(), 189.994704791049550806e18);
        assertEq(lpToken.totalSupply(), 189.994704791049550806e18);

        uint256 amountToRedeem = lpToken.balanceOf(user2);
        vm.startPrank(user2);
        lpToken.approve(address(pool), amountToRedeem);
        uint256[] memory _minRedeemAmounts = new uint256[](2);
        pool.redeemProportion(amountToRedeem, _minRedeemAmounts);
        vm.stopPrank();

        assertEq(WETH.balanceOf(user2), token1Amount);
        assertEq(frxETH.balanceOf(user2), token2Amount);

        assertEq(lpToken.sharesOf(user2), 0);
        assertEq(lpToken.balanceOf(user2), 0);

        assertEq(WETH.balanceOf(address(pool)), 105e18 - token1Amount);
        assertEq(frxETH.balanceOf(address(pool)), 85e18 - token2Amount);

        assertIsCloseTo(pool.balances(0), 105e18 - token1Amount * precisions[0], 0);
        assertIsCloseTo(pool.balances(1), 85e18 - token2Amount * precisions[1], 0);

        assertEq(pool.totalSupply(), lpToken.totalSupply());
    }

    function test_redeemCorrectAmountToSingleToken() external {
        uint256[] memory mintAmounts = new uint256[](2);
        mintAmounts[0] = 105e18;
        mintAmounts[1] = 85e18;

        uint256 totalAmount = mintAmounts[0] + mintAmounts[1];

        WETH.mint(user, 105e18);
        frxETH.mint(user, 85e18);

        vm.startPrank(user);
        WETH.approve(address(pool), 105e18);
        frxETH.approve(address(pool), 85e18);

        pool.mint(mintAmounts, 0);
        vm.stopPrank();

        (uint256 token1Amount, uint256 token2Amount) = pool.getRedeemSingleAmount(25e18, 0);

        vm.prank(user);
        lpToken.transfer(user2, 25e18);

        assertEq(WETH.balanceOf(user2), 0);
        assertEq(frxETH.balanceOf(user2), 0);

        assertEq(WETH.balanceOf(address(pool)), 105e18);
        assertEq(frxETH.balanceOf(address(pool)), 85e18);

        assertEq(pool.balances(0), 105e18);
        assertEq(pool.balances(1), 85e18);

        assertEq(pool.totalSupply(), lpToken.totalSupply());

        uint256 redeemAmount = lpToken.balanceOf(user2);
        vm.startPrank(user2);
        lpToken.approve(address(pool), redeemAmount);
        pool.redeemSingle(redeemAmount, 0, 0);
        vm.stopPrank();

        assertEq(WETH.balanceOf(user2), token1Amount);
        assertEq(frxETH.balanceOf(user2), 0);
        assertEq(lpToken.sharesOf(user2), 0);

        assertEq(WETH.balanceOf(address(pool)), 105e18 - token1Amount);
        assertEq(frxETH.balanceOf(address(pool)), 85e18);
        assertIsCloseTo(pool.balances(0), 105e18 - token1Amount * precisions[0], 0);
        assertEq(pool.balances(1), 85e18);
        assertEq(pool.totalSupply(), lpToken.totalSupply());
    }

    function test_redeemCorrectAmountToMultipleTokens() external {
        uint256[] memory mintAmounts = new uint256[](2);
        mintAmounts[0] = 105e18;
        mintAmounts[1] = 85e18;

        WETH.mint(user, 105e18);
        frxETH.mint(user, 85e18);

        vm.startPrank(user);
        WETH.approve(address(pool), 105e18);
        frxETH.approve(address(pool), 85e18);

        pool.mint(mintAmounts, 0);
        vm.stopPrank();

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10e18;
        amounts[1] = 5e18;
        (uint256 redeemAmount,) = pool.getRedeemMultiAmount(amounts);

        vm.prank(user);
        lpToken.transfer(user2, 25e18);

        uint256 balance = lpToken.balanceOf(user2);

        assertEq(WETH.balanceOf(user2), 0);
        assertEq(frxETH.balanceOf(user2), 0);
        assertEq(lpToken.balanceOf(user2), balance);

        assertEq(WETH.balanceOf(address(pool)), 105e18);
        assertEq(frxETH.balanceOf(address(pool)), 85e18);

        assertEq(pool.balances(0), 105e18);
        assertEq(pool.balances(1), 85e18);

        assertEq(pool.totalSupply(), lpToken.totalSupply());

        vm.startPrank(user2);
        lpToken.approve(address(pool), redeemAmount);
        uint256[] memory redeemAmounts = new uint256[](2);
        redeemAmounts[0] = 10e18;
        redeemAmounts[1] = 5e18;
        pool.redeemMulti(redeemAmounts, redeemAmount);
        vm.stopPrank();

        assertEq(WETH.balanceOf(user2), 10e18);
        assertEq(frxETH.balanceOf(user2), 5e18);

        assertEq(WETH.balanceOf(address(pool)), 105e18 - 10e18);
        assertEq(frxETH.balanceOf(address(pool)), 85e18 - 5e18);

        assertEq(pool.balances(0), 105e18 - 10e18);
        assertEq(pool.balances(1), 85e18 - 5e18);
        assertEq(pool.totalSupply(), lpToken.totalSupply());
    }

    function testRedeemCorrectAmountToSingleTokenRebasing() external {
        uint256[] memory mintAmounts = new uint256[](2);
        mintAmounts[0] = 105e18;
        mintAmounts[1] = 85e18;

        uint256 totalAmount = mintAmounts[0] + mintAmounts[1];

        WETH.mint(user, 105e18);
        frxETH.mint(user, 85e18);

        vm.startPrank(user);
        WETH.approve(address(pool), 105e18);
        frxETH.approve(address(pool), 85e18);

        pool.mint(mintAmounts, 0);
        vm.stopPrank();

        WETH.mint(address(pool), 10e18);
        uint256 redeemAmount = 25e18;
        (uint256 token1Amount, uint256 feeAmount) = pool.getRedeemSingleAmount(redeemAmount, 0);

        assertInvariant(105e18 - (token1Amount * precisions[0]), 85e18, 100, totalAmount - redeemAmount - feeAmount);
    }

    function testRedeemCorrectAmountWithProportionalRedemptionRebasing() external {
        uint256[] memory mintAmounts = new uint256[](2);
        mintAmounts[0] = 105e18;
        mintAmounts[1] = 85e18;

        WETH.mint(user, 105e18);
        frxETH.mint(user, 85e18);

        vm.startPrank(user);
        WETH.approve(address(pool), 105e18);
        frxETH.approve(address(pool), 85e18);

        pool.mint(mintAmounts, 0);
        vm.stopPrank();

        WETH.mint(address(pool), 10e18);
        uint256 redeemAmount = 25e18;
        (uint256[] memory tokenAmounts, uint256 feeAmount) = pool.getRedeemProportionAmount(redeemAmount);

        uint256 token1Amount = tokenAmounts[0];
        uint256 token2Amount = tokenAmounts[1];

        assertEq(token1Amount, 14_303_943_881_560_144_839);
        assertEq(token2Amount, 10_572_480_260_283_585_316);
        assertEq(feeAmount, 125_000_000_000_000_000);
    }

    function testCorrectExchangeAmountRebasing() external {
        WETH.mint(user, 105e18);
        frxETH.mint(user, 85e18);

        vm.startPrank(user);
        WETH.approve(address(pool), 105e18);
        frxETH.approve(address(pool), 85e18);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 105e18;
        amounts[1] = 85e18;

        pool.mint(amounts, 0);
        vm.stopPrank();

        WETH.mint(address(pool), 10e18);
        frxETH.mint(user2, 8e18);
        vm.startPrank(user2);
        frxETH.approve(address(pool), 8e18);
        vm.stopPrank();

        (uint256 exchangeAmount, uint256 feeAmount) = pool.getSwapAmount(1, 0, 8e18);

        assertEq(exchangeAmount, 7.992985053666343961e18);
        assertEq(feeAmount, 0.016018006119571831e18);
    }

    function testDynamicFeeForSwap() external {
        WETH.mint(user, 105e18);
        frxETH.mint(user, 85e18);

        vm.startPrank(user);
        WETH.approve(address(pool), 105e18);
        frxETH.approve(address(pool), 85e18);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 105e18;
        amounts[1] = 85e18;

        pool.mint(amounts, 0);
        vm.stopPrank();

        frxETH.mint(user2, 8e18);
        vm.startPrank(user2);
        frxETH.approve(address(pool), 8e18);
        vm.stopPrank();

        (uint256 exchangeAmount,) = pool.getSwapAmount(1, 0, 8e18);

        vm.prank(owner);
        pool.setOffPegFeeMultiplier(2e10);

        assertEq(WETH.balanceOf(user2), 0);
        assertEq(frxETH.balanceOf(user2), 8e18);

        assertEq(WETH.balanceOf(address(pool)), 105e18);
        assertEq(frxETH.balanceOf(address(pool)), 85e18);

        assertEq(pool.balances(0), 105e18);
        assertEq(pool.balances(1), 85e18);

        assertEq(pool.totalSupply(), 189.994704791049550806e18);

        assertEq(pool.totalSupply(), lpToken.totalSupply());

        vm.prank(user2);
        pool.swap(1, 0, 8e18, 0);

        assertLt(WETH.balanceOf(user2), exchangeAmount);
    }

    function test_LossHandling() external {
        MockExchangeRateProvider rETHExchangeRateProvider = new MockExchangeRateProvider(1e18, 18);
        MockExchangeRateProvider wstETHExchangeRateProvider = new MockExchangeRateProvider(1e18, 18);

        MockToken rETH = new MockToken("rETH", "rETH", 18);
        MockToken wstETH = new MockToken("wstETH", "wstETH", 18);

        address[] memory _tokens = new address[](2);
        _tokens[0] = address(rETH);
        _tokens[1] = address(wstETH);

        IExchangeRateProvider[] memory exchangeRateProviders = new IExchangeRateProvider[](2);
        exchangeRateProviders[0] = IExchangeRateProvider(rETHExchangeRateProvider);
        exchangeRateProviders[1] = IExchangeRateProvider(wstETHExchangeRateProvider);

        bytes memory data = abi.encodeCall(LPToken.initialize, ("LP Token", "LPT"));

        ERC1967Proxy proxy = new ERC1967Proxy(address(new LPToken()), data);
        LPToken _lpToken = LPToken(address(proxy));
        _lpToken.transferOwnership(owner);

        uint256[] memory _fees = new uint256[](3);
        _fees[0] = 0;
        _fees[1] = 0;
        _fees[2] = 0;

        uint256[] memory _precisions = new uint256[](2);
        _precisions[0] = 1;
        _precisions[1] = 1;

        data = abi.encodeCall(
            SelfPeggingAsset.initialize,
            (_tokens, _precisions, _fees, 0, _lpToken, A, exchangeRateProviders, address(0), 0)
        );
        proxy = new ERC1967Proxy(address(new SelfPeggingAsset()), data);
        SelfPeggingAsset _pool = SelfPeggingAsset(address(proxy));

        _pool.transferOwnership(owner);

        vm.prank(owner);
        _lpToken.addPool(address(_pool));

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e18;
        amounts[1] = 100e18;

        // Mint Liquidity
        rETH.mint(user, 100e18);
        wstETH.mint(user, 100e18);

        vm.startPrank(user);
        rETH.approve(address(_pool), 100e18);
        wstETH.approve(address(_pool), 100e18);

        _pool.mint(amounts, 0);
        vm.stopPrank();

        // swap 1 rETH to wstETH
        rETH.mint(user2, 1e18);

        vm.startPrank(user2);
        rETH.approve(address(_pool), 1e18);
        _pool.swap(0, 1, 1e18, 0);
        vm.stopPrank();

        uint256 rETHBalance = rETH.balanceOf(user2);
        uint256 wstETHBalance = wstETH.balanceOf(user2);

        assertEq(rETHBalance, 0);
        assertIsCloseTo(wstETHBalance, 1e18, 0.00005 ether);

        // Set buffer percentage to 5%
        vm.prank(owner);
        _lpToken.setBuffer(0.05e10);
        vm.stopPrank();

        // Add yield
        rETHExchangeRateProvider.newRate(2e18);
        _pool.rebase();

        assertIsCloseTo(_lpToken.bufferAmount(), 5e18, 0.05 ether);
        assertEq(_lpToken.bufferBadDebt(), 0);

        // Drop the exchange rate by 1% so that the pool is in loss and buffer can cover the loss
        rETHExchangeRateProvider.newRate(1.98e18);
        _pool.rebase();

        assertIsCloseTo(_lpToken.bufferAmount(), 3e18, 0.03 ether);
        assertIsCloseTo(_lpToken.bufferBadDebt(), 2e18, 0.02 ether);

        // Drop the exchange rate by 90% so that the pool is in loss and buffer can't cover the loss
        rETHExchangeRateProvider.newRate(0.2e18);
        vm.expectRevert();
        _pool.rebase();

        // Trigger negative rebase
        assertIsCloseTo(_lpToken.totalSupply(), 295e18, 0.9e18);
        vm.startPrank(owner);
        _pool.setAdmin(owner, true);
        _pool.pause();
        _pool.distributeLoss();

        assertIsCloseTo(_lpToken.totalSupply(), 115e18, 1e18);

        // Recover bad debt
        assertNotEq(_lpToken.bufferBadDebt(), 0);
        rETHExchangeRateProvider.newRate(1e18);
        _pool.rebase();
        assertEq(_lpToken.bufferBadDebt(), 0);
    }

    function test_MintDynamicFee() external {
        WETH.mint(user, 105e18);
        frxETH.mint(user, 85e18);

        vm.startPrank(user);
        WETH.approve(address(pool), 105e18);
        frxETH.approve(address(pool), 85e18);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 105e18;
        amounts[1] = 85e18;

        pool.mint(amounts, 0);

        WETH.mint(user, 100e18);
        frxETH.mint(user, 100e18);

        WETH.approve(address(pool), 100e18);
        frxETH.approve(address(pool), 100e18);

        amounts = new uint256[](2);
        amounts[0] = 100e18;
        amounts[1] = 100e18;

        uint256 minted = pool.mint(amounts, 0);
        assertEq(minted, 199.981683542835615016e18);
    }

    function assertAlmostTheSame(uint256 num1, uint256 num2) internal view {
        // Calculate the absolute difference
        uint256 diff = num1 > num2 ? num1 - num2 : num2 - num1;

        // Use the smaller number as the denominator
        uint256 denominator = num1 < num2 ? num1 : num2;
        assert(denominator > 0);

        // Calculate the relative difference scaled by 10000 (0.01% precision)
        uint256 scaledDiff = (diff * 10_000) / denominator;

        // Assert that the relative difference is smaller than 0.15% (scaled value <= 15)
        assert(scaledDiff <= 15);
    }

    function assertInvariant(uint256 balance0, uint256 balance1, uint256 A, uint256 D) internal {
        // We only check n = 2 here
        uint256 left = (A * 4) * (balance0 + balance1) + D;
        uint256 denominator = balance0 * balance1 * 4;
        assert(denominator > 0);
        uint256 right = (A * 4) * D + (D ** 3) / denominator;

        assertAlmostTheSame(left, right);
    }

    function assertIsCloseTo(uint256 a, uint256 b, uint256 tolerance) public pure returns (bool) {
        if (a > b) {
            require(a - b <= tolerance == true, "Not close enough");
        } else {
            require(b - a <= tolerance == true == true, "Not close enough");
        }
    }

    function test_DonateDCorrectlyUpdatesState() external {
        uint256[] memory mintAmounts = new uint256[](2);
        mintAmounts[0] = 100e18;
        mintAmounts[1] = 100e18;

        WETH.mint(user, 100e18);
        frxETH.mint(user, 100e18);

        vm.startPrank(user);
        WETH.approve(address(pool), 100e18);
        frxETH.approve(address(pool), 100e18);
        uint256 mintedAmount = pool.mint(mintAmounts, 0);
        vm.stopPrank();

        uint256[] memory donationAmounts = new uint256[](2);
        donationAmounts[0] = 10e18; // Donate 10 WETH
        donationAmounts[1] = 5e18; // Donate 5 frxETH
        uint256 minDonationAmount = 14e18;

        WETH.mint(user2, 10e18);
        frxETH.mint(user2, 5e18);

        vm.startPrank(user2);
        WETH.approve(address(pool), 10e18);
        frxETH.approve(address(pool), 5e18);

        uint256 initialTotalSupply = pool.totalSupply();
        uint256 initialWETHBalance = pool.balances(0);
        uint256 initialFrxETHBalance = pool.balances(1);
        uint256 initialBuffer = lpToken.bufferAmount();
        assertEq(WETH.balanceOf(user2), 10e18);
        assertEq(frxETH.balanceOf(user2), 5e18);
        assertEq(WETH.balanceOf(address(pool)), 100e18);
        assertEq(frxETH.balanceOf(address(pool)), 100e18);
        assertEq(initialTotalSupply, mintedAmount);

        uint256 donationAmount = pool.donateD(donationAmounts, minDonationAmount);
        vm.stopPrank();

        uint256 expectedWETHBalance = initialWETHBalance + donationAmounts[0] * precisions[0];
        uint256 expectedFrxETHBalance = initialFrxETHBalance + donationAmounts[1] * precisions[1];
        uint256 expectedTotalSupply = initialTotalSupply + donationAmount;
        uint256 expectedBuffer = initialBuffer + donationAmount;

        assertEq(WETH.balanceOf(user2), 0);
        assertEq(frxETH.balanceOf(user2), 0);
        assertEq(WETH.balanceOf(address(pool)), 110e18);
        assertEq(frxETH.balanceOf(address(pool)), 105e18);
        assertEq(pool.balances(0), expectedWETHBalance);
        assertEq(pool.balances(1), expectedFrxETHBalance);
        assertEq(pool.totalSupply(), expectedTotalSupply);
        assertEq(lpToken.bufferAmount(), expectedBuffer);
        assertTrue(donationAmount >= minDonationAmount);
    }

    function test_ExchangeRateFee() external {
        MockExchangeRateProvider rETHExchangeRateProvider1 = new MockExchangeRateProvider(1e18, 18);
        MockExchangeRateProvider wstETHExchangeRateProvider1 = new MockExchangeRateProvider(1e18, 18);

        MockExchangeRateProvider rETHExchangeRateProvider2 = new MockExchangeRateProvider(1e18, 18);
        MockExchangeRateProvider wstETHExchangeRateProvider2 = new MockExchangeRateProvider(1e18, 18);

        MockToken rETH1 = new MockToken("rETH", "rETH", 18);
        MockToken wstETH1 = new MockToken("wstETH", "wstETH", 18);

        MockToken rETH2 = new MockToken("rETH", "rETH", 18);
        MockToken wstETH2 = new MockToken("wstETH", "wstETH", 18);

        address[] memory _tokens1 = new address[](2);
        _tokens1[0] = address(rETH1);
        _tokens1[1] = address(wstETH1);

        address[] memory _tokens2 = new address[](2);
        _tokens2[0] = address(rETH2);
        _tokens2[1] = address(wstETH2);

        IExchangeRateProvider[] memory exchangeRateProviders1 = new IExchangeRateProvider[](2);
        exchangeRateProviders1[0] = IExchangeRateProvider(rETHExchangeRateProvider1);
        exchangeRateProviders1[1] = IExchangeRateProvider(wstETHExchangeRateProvider1);

        IExchangeRateProvider[] memory exchangeRateProviders2 = new IExchangeRateProvider[](2);
        exchangeRateProviders2[0] = IExchangeRateProvider(rETHExchangeRateProvider2);
        exchangeRateProviders2[1] = IExchangeRateProvider(wstETHExchangeRateProvider2);

        bytes memory data = abi.encodeCall(LPToken.initialize, ("LP Token", "LPT"));

        ERC1967Proxy proxy1 = new ERC1967Proxy(address(new LPToken()), data);
        LPToken _lpToken1 = LPToken(address(proxy1));
        _lpToken1.transferOwnership(owner);

        ERC1967Proxy proxy2 = new ERC1967Proxy(address(new LPToken()), data);
        LPToken _lpToken2 = LPToken(address(proxy2));
        _lpToken2.transferOwnership(owner);

        uint256[] memory _fees = new uint256[](3);
        _fees[0] = 0;
        _fees[1] = 0.00001e10;
        _fees[2] = 0;

        uint256[] memory _precisions = new uint256[](2);
        _precisions[0] = 1;
        _precisions[1] = 1;

        data = abi.encodeCall(
            SelfPeggingAsset.initialize,
            (_tokens1, _precisions, _fees, 0, _lpToken1, A, exchangeRateProviders1, address(0), 0)
        );

        proxy1 = new ERC1967Proxy(address(new SelfPeggingAsset()), data);
        SelfPeggingAsset _pool1 = SelfPeggingAsset(address(proxy1));

        _pool1.transferOwnership(owner);

        data = abi.encodeCall(
            SelfPeggingAsset.initialize,
            (_tokens2, _precisions, _fees, 0, _lpToken2, A, exchangeRateProviders2, address(0), 1e10)
        );

        proxy2 = new ERC1967Proxy(address(new SelfPeggingAsset()), data);
        SelfPeggingAsset _pool2 = SelfPeggingAsset(address(proxy2));

        _pool2.transferOwnership(owner);

        vm.startPrank(owner);
        _lpToken1.addPool(address(_pool1));
        _lpToken2.addPool(address(_pool2));
        vm.stopPrank();

        vm.prank(address(_pool1));
        _lpToken1.addBuffer(100e18);

        vm.prank(address(_pool2));
        _lpToken2.addBuffer(100e18);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e18;
        amounts[1] = 100e18;

        rETH1.mint(user, 100e18);
        wstETH1.mint(user, 100e18);

        rETH2.mint(user, 100e18);
        wstETH2.mint(user, 100e18);

        vm.startPrank(user);
        rETH1.approve(address(_pool1), 100e18);
        wstETH1.approve(address(_pool1), 100e18);

        rETH2.approve(address(_pool2), 100e18);
        wstETH2.approve(address(_pool2), 100e18);

        _pool1.mint(amounts, 0);
        _pool2.mint(amounts, 0);
        vm.stopPrank();

        rETH1.mint(user2, 1e18);
        rETH2.mint(user2, 1e18);

        vm.startPrank(user2);
        rETH1.approve(address(_pool1), 1e18);
        rETH2.approve(address(_pool2), 1e18);

        _pool1.swap(0, 1, 1e18, 0);
        _pool2.swap(0, 1, 1e18, 0);
        vm.stopPrank();

        uint256 wstETHBalance1 = wstETH1.balanceOf(user2);
        uint256 wstETHBalance2 = wstETH2.balanceOf(user2);

        assertLt(wstETHBalance1, 1e18);
        assertLt(wstETHBalance2, 1e18);

        rETHExchangeRateProvider1.setExchangeRate(0.994e18);
        rETHExchangeRateProvider2.setExchangeRate(0.994e18);

        vm.startPrank(user2);
        wstETH1.approve(address(_pool1), wstETHBalance1);

        wstETH2.mint(user2, 1);
        wstETH2.approve(address(_pool2), wstETHBalance2 + 1);

        _pool1.swap(1, 0, wstETHBalance1, 0);
        _pool2.swap(1, 0, 1, 0);
        _pool2.swap(1, 0, wstETHBalance2, 0);
        vm.stopPrank();

        uint256 rETHBalance1 = rETH1.balanceOf(user2);
        uint256 rETHBalance2 = rETH2.balanceOf(user2);

        assertGt(rETHBalance1, rETHBalance2);
    }

    function test_ExchangeRateFeeSkipPeriod() external {
        MockExchangeRateProvider rETHExchangeRateProvider1 = new MockExchangeRateProvider(1e18, 18);
        MockExchangeRateProvider wstETHExchangeRateProvider1 = new MockExchangeRateProvider(1e18, 18);

        MockExchangeRateProvider rETHExchangeRateProvider2 = new MockExchangeRateProvider(1e18, 18);
        MockExchangeRateProvider wstETHExchangeRateProvider2 = new MockExchangeRateProvider(1e18, 18);

        MockToken rETH1 = new MockToken("rETH", "rETH", 18);
        MockToken wstETH1 = new MockToken("wstETH", "wstETH", 18);

        MockToken rETH2 = new MockToken("rETH", "rETH", 18);
        MockToken wstETH2 = new MockToken("wstETH", "wstETH", 18);

        address[] memory _tokens1 = new address[](2);
        _tokens1[0] = address(rETH1);
        _tokens1[1] = address(wstETH1);

        address[] memory _tokens2 = new address[](2);
        _tokens2[0] = address(rETH2);
        _tokens2[1] = address(wstETH2);

        IExchangeRateProvider[] memory exchangeRateProviders1 = new IExchangeRateProvider[](2);
        exchangeRateProviders1[0] = IExchangeRateProvider(rETHExchangeRateProvider1);
        exchangeRateProviders1[1] = IExchangeRateProvider(wstETHExchangeRateProvider1);

        IExchangeRateProvider[] memory exchangeRateProviders2 = new IExchangeRateProvider[](2);
        exchangeRateProviders2[0] = IExchangeRateProvider(rETHExchangeRateProvider2);
        exchangeRateProviders2[1] = IExchangeRateProvider(wstETHExchangeRateProvider2);

        bytes memory data = abi.encodeCall(LPToken.initialize, ("LP Token", "LPT"));

        ERC1967Proxy proxy1 = new ERC1967Proxy(address(new LPToken()), data);
        LPToken _lpToken1 = LPToken(address(proxy1));
        _lpToken1.transferOwnership(owner);

        ERC1967Proxy proxy2 = new ERC1967Proxy(address(new LPToken()), data);
        LPToken _lpToken2 = LPToken(address(proxy2));
        _lpToken2.transferOwnership(owner);

        uint256[] memory _fees = new uint256[](3);
        _fees[0] = 0;
        _fees[1] = 0.00001e10;
        _fees[2] = 0;

        uint256[] memory _precisions = new uint256[](2);
        _precisions[0] = 1;
        _precisions[1] = 1;

        data = abi.encodeCall(
            SelfPeggingAsset.initialize,
            (_tokens1, _precisions, _fees, 0, _lpToken1, A, exchangeRateProviders1, address(0), 1e10)
        );

        proxy1 = new ERC1967Proxy(address(new SelfPeggingAsset()), data);
        SelfPeggingAsset _pool1 = SelfPeggingAsset(address(proxy1));
        _pool1.setRateChangeSkipPeriod(10 seconds);

        _pool1.transferOwnership(owner);

        data = abi.encodeCall(
            SelfPeggingAsset.initialize,
            (_tokens2, _precisions, _fees, 0, _lpToken2, A, exchangeRateProviders2, address(0), 1e10)
        );

        proxy2 = new ERC1967Proxy(address(new SelfPeggingAsset()), data);
        SelfPeggingAsset _pool2 = SelfPeggingAsset(address(proxy2));

        _pool2.transferOwnership(owner);

        vm.startPrank(owner);
        _lpToken1.addPool(address(_pool1));
        _lpToken2.addPool(address(_pool2));
        vm.stopPrank();

        vm.prank(address(_pool1));
        _lpToken1.addBuffer(100e18);

        vm.prank(address(_pool2));
        _lpToken2.addBuffer(100e18);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e18;
        amounts[1] = 100e18;

        rETH1.mint(user, 100e18);
        wstETH1.mint(user, 100e18);

        rETH2.mint(user, 100e18);
        wstETH2.mint(user, 100e18);

        vm.startPrank(user);
        rETH1.approve(address(_pool1), 100e18);
        wstETH1.approve(address(_pool1), 100e18);

        rETH2.approve(address(_pool2), 100e18);
        wstETH2.approve(address(_pool2), 100e18);

        _pool1.mint(amounts, 0);
        _pool2.mint(amounts, 0);
        vm.stopPrank();

        rETH1.mint(user2, 1e18);
        rETH2.mint(user2, 1e18);

        vm.startPrank(user2);
        rETH1.approve(address(_pool1), 1e18);
        rETH2.approve(address(_pool2), 1e18);

        _pool1.swap(0, 1, 1e18, 0);
        _pool2.swap(0, 1, 1e18, 0);
        vm.stopPrank();

        uint256 wstETHBalance1 = wstETH1.balanceOf(user2);
        uint256 wstETHBalance2 = wstETH2.balanceOf(user2);

        assertLt(wstETHBalance1, 1e18);
        assertLt(wstETHBalance2, 1e18);

        rETHExchangeRateProvider1.setExchangeRate(0.994e18);
        rETHExchangeRateProvider2.setExchangeRate(0.994e18);

        vm.warp(block.timestamp + 4 minutes);

        vm.startPrank(user2);
        wstETH1.approve(address(_pool1), wstETHBalance1);

        wstETH2.mint(user2, 1);
        wstETH2.approve(address(_pool2), wstETHBalance2 + 1);

        _pool1.swap(1, 0, wstETHBalance1, 0);
        _pool2.swap(1, 0, 1, 0);
        _pool2.swap(1, 0, wstETHBalance2, 0);
        vm.stopPrank();

        uint256 rETHBalance1 = rETH1.balanceOf(user2);
        uint256 rETHBalance2 = rETH2.balanceOf(user2);

        assertGt(rETHBalance1, rETHBalance2);
    }

    function test_VolatilityFee_SkipPeriod() external {
        MockToken rETH = new MockToken("rETH", "rETH", 18);
        MockToken wstETH = new MockToken("wstETH", "wstETH", 18);

        MockExchangeRateProvider provider0 = new MockExchangeRateProvider(1e18, 18);
        MockExchangeRateProvider provider1 = new MockExchangeRateProvider(1e18, 18);

        bytes memory data = abi.encodeCall(LPToken.initialize, ("LP Token", "LPT"));
        ERC1967Proxy proxy = new ERC1967Proxy(address(new LPToken()), data);
        LPToken lpToken = LPToken(address(proxy));
        lpToken.transferOwnership(owner);

        address[] memory tokens = new address[](2);
        tokens[0] = address(rETH);
        tokens[1] = address(wstETH);

        IExchangeRateProvider[] memory providers = new IExchangeRateProvider[](2);
        providers[0] = provider0;
        providers[1] = provider1;

        uint256[] memory fees = new uint256[](3);
        fees[0] = 0.001e10; // 0.1% mint fee
        fees[1] = 0.001e10; // 0.1% swap fee
        fees[2] = 0.001e10; // 0.1% redeem fee

        uint256[] memory precisions = new uint256[](2);
        precisions[0] = 1;
        precisions[1] = 1;

        data = abi.encodeCall(
            SelfPeggingAsset.initialize, (tokens, precisions, fees, 0, lpToken, 100, providers, address(0), 1e10)
        );

        proxy = new ERC1967Proxy(address(new SelfPeggingAsset()), data);
        SelfPeggingAsset pool = SelfPeggingAsset(address(proxy));

        pool.setRateChangeSkipPeriod(10 seconds);
        pool.setDecayPeriod(10 seconds);

        vm.prank(owner);
        lpToken.addPool(address(pool));

        vm.prank(address(pool));
        lpToken.addBuffer(100e18);

        rETH.mint(user, 100e18);
        wstETH.mint(user, 100e18);

        vm.startPrank(user);
        rETH.approve(address(pool), 100e18);
        wstETH.approve(address(pool), 100e18);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e18;
        amounts[1] = 100e18;
        pool.mint(amounts, 0);
        vm.stopPrank();

        (, uint256 initFee) = pool.getRedeemSingleAmount(10e18, 0);
        console2.log("Initial fee:", initFee);

        // Change exchange rate
        provider0.setExchangeRate(0.9e18);
        (, uint256 volatilityFee) = pool.getRedeemSingleAmount(10e18, 0);
        console2.log("fee after volatility period:", volatilityFee);

        // during decay period
        vm.warp(block.timestamp + 9 seconds);
        (, uint256 beforeSkipFee) = pool.getRedeemSingleAmount(10e18, 0);
        console2.log("fee before skip period:", beforeSkipFee);

        // do an operation and fee spike
        vm.startPrank(user);
        lpToken.approve(address(pool), 10e18);
        pool.redeemSingle(10e18, 0, 0);
        vm.stopPrank();

        (, uint256 postOpFeeSpike) = pool.getRedeemSingleAmount(10e18, 0);
        console2.log("Fee after operation:", postOpFeeSpike);

        bool feeSpikeAfterOp =
            (postOpFeeSpike >= beforeSkipFee * 995 / 1000) && (postOpFeeSpike <= beforeSkipFee * 1005 / 1000);

        // Change exchange rate further
        provider0.setExchangeRate(0.8e18);
        (, uint256 volatilityFee2) = pool.getRedeemSingleAmount(10e18, 0);
        console2.log("fee after volatility period:", volatilityFee2);

        // during decay period
        vm.warp(block.timestamp + 9 seconds);
        (, uint256 beforeSkipFee2) = pool.getRedeemSingleAmount(10e18, 0);
        console2.log("fee after skip period:", beforeSkipFee2);

        // skip past decay period
        vm.warp(block.timestamp + 1 hours);
        (, uint256 afterSkipFee) = pool.getRedeemSingleAmount(10e18, 0);
        console2.log("fee after skip period:", afterSkipFee);

        // do an operation and fee doesn't spike
        vm.startPrank(user);
        lpToken.approve(address(pool), 10e18);
        pool.redeemSingle(10e18, 0, 0);
        vm.stopPrank();

        (, uint256 postOpFee) = pool.getRedeemSingleAmount(10e18, 0);
        console2.log("Fee after operation:", postOpFee);

        bool feeAfterOp = (postOpFee >= afterSkipFee * 995 / 1000) && (postOpFee <= afterSkipFee * 1005 / 1000);

        assertNotEq(volatilityFee, initFee, "fee changed during volatility");
        assertEq(feeSpikeAfterOp, false, "fee spike out of range after redeem");
        assertEq(beforeSkipFee2, volatilityFee2, "fee keep spiked before skip");
        assertLt(afterSkipFee, volatilityFee2, "fee stabilized after skip");
        assertEq(feeAfterOp, true, "fee stayed within range after redeem");
    }

    function testFuzz_ExchangeRateFee(
        uint256 initialLiquidity,
        uint256 swapAmount,
        uint256 newRatePercent,
        uint256 exchangeRateFeeFactor,
        uint256 timeElapsed
    )
        public
    {
        initialLiquidity = bound(initialLiquidity, 100e18, 1000e18);
        swapAmount = bound(swapAmount, 1e18, initialLiquidity / 10);
        newRatePercent = bound(newRatePercent, 80, 120);
        uint256 newRate = (1e18 * newRatePercent) / 100;

        exchangeRateFeeFactor = bound(exchangeRateFeeFactor, 1e10, 5e10);
        timeElapsed = bound(timeElapsed, 0, 30 days);

        MockToken rETH1 = new MockToken("rETH1", "rETH1", 18);
        MockToken wstETH1 = new MockToken("wstETH1", "wstETH1", 18);
        MockToken rETH2 = new MockToken("rETH2", "rETH2", 18);
        MockToken wstETH2 = new MockToken("wstETH2", "wstETH2", 18);
        MockExchangeRateProvider rETHProvider1 = new MockExchangeRateProvider(1e18, 18);
        MockExchangeRateProvider wstETHProvider1 = new MockExchangeRateProvider(1e18, 18);
        MockExchangeRateProvider rETHProvider2 = new MockExchangeRateProvider(1e18, 18);
        MockExchangeRateProvider wstETHProvider2 = new MockExchangeRateProvider(1e18, 18);

        address[] memory tokens1 = new address[](2);
        tokens1[0] = address(rETH1);
        tokens1[1] = address(wstETH1);

        address[] memory tokens2 = new address[](2);
        tokens2[0] = address(rETH2);
        tokens2[1] = address(wstETH2);

        IExchangeRateProvider[] memory providers1 = new IExchangeRateProvider[](2);
        providers1[0] = IExchangeRateProvider(rETHProvider1);
        providers1[1] = IExchangeRateProvider(wstETHProvider1);

        IExchangeRateProvider[] memory providers2 = new IExchangeRateProvider[](2);
        providers2[0] = IExchangeRateProvider(rETHProvider2);
        providers2[1] = IExchangeRateProvider(wstETHProvider2);

        bytes memory data = abi.encodeCall(LPToken.initialize, ("LP Token 1", "LPT1"));
        ERC1967Proxy proxy1 = new ERC1967Proxy(address(new LPToken()), data);
        LPToken lpToken1 = LPToken(address(proxy1));
        lpToken1.transferOwnership(owner);

        data = abi.encodeCall(LPToken.initialize, ("LP Token 2", "LPT2"));
        ERC1967Proxy proxy2 = new ERC1967Proxy(address(new LPToken()), data);
        LPToken lpToken2 = LPToken(address(proxy2));
        lpToken2.transferOwnership(owner);

        uint256[] memory fees = new uint256[](3);
        fees[0] = 0;
        fees[1] = 0.00001e10;
        fees[2] = 0;
        precisions[0] = 1;
        precisions[1] = 1;

        data = abi.encodeCall(
            SelfPeggingAsset.initialize, (tokens1, precisions, fees, 0, lpToken1, A, providers1, address(0), 0)
        );
        proxy1 = new ERC1967Proxy(address(new SelfPeggingAsset()), data);
        SelfPeggingAsset pool1 = SelfPeggingAsset(address(proxy1));
        pool1.setRateChangeSkipPeriod(100 days);
        pool1.transferOwnership(owner);

        data = abi.encodeCall(
            SelfPeggingAsset.initialize,
            (tokens2, precisions, fees, 0, lpToken2, A, providers2, address(0), exchangeRateFeeFactor)
        );
        proxy2 = new ERC1967Proxy(address(new SelfPeggingAsset()), data);
        SelfPeggingAsset pool2 = SelfPeggingAsset(address(proxy2));
        pool2.setRateChangeSkipPeriod(100 days);
        pool2.transferOwnership(owner);

        vm.startPrank(owner);
        lpToken1.addPool(address(pool1));
        lpToken2.addPool(address(pool2));
        vm.stopPrank();

        uint256 bufferSize = initialLiquidity * 3;
        vm.prank(address(pool1));
        lpToken1.addBuffer(bufferSize);

        vm.prank(address(pool2));
        lpToken2.addBuffer(bufferSize);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = initialLiquidity;
        amounts[1] = initialLiquidity;

        rETH1.mint(user, initialLiquidity);
        wstETH1.mint(user, initialLiquidity);
        rETH2.mint(user, initialLiquidity);
        wstETH2.mint(user, initialLiquidity);

        vm.startPrank(user);
        rETH1.approve(address(pool1), initialLiquidity);
        wstETH1.approve(address(pool1), initialLiquidity);
        rETH2.approve(address(pool2), initialLiquidity);
        wstETH2.approve(address(pool2), initialLiquidity);

        pool1.mint(amounts, 0);
        pool2.mint(amounts, 0);
        vm.stopPrank();

        rETH1.mint(user2, swapAmount);
        rETH2.mint(user2, swapAmount);

        vm.startPrank(user2);
        rETH1.approve(address(pool1), swapAmount);
        rETH2.approve(address(pool2), swapAmount);

        pool1.swap(0, 1, swapAmount, 0);
        pool2.swap(0, 1, swapAmount, 0);
        vm.stopPrank();

        uint256 wstETHBalance1 = wstETH1.balanceOf(user2);
        uint256 wstETHBalance2 = wstETH2.balanceOf(user2);

        assertApproxEqRel(wstETHBalance1, wstETHBalance2, 0.01e18);

        rETHProvider1.setExchangeRate(newRate);
        rETHProvider2.setExchangeRate(newRate);

        if (timeElapsed > 0) vm.warp(block.timestamp + timeElapsed);

        vm.startPrank(user2);
        wstETH1.approve(address(pool1), wstETHBalance1);
        wstETH2.approve(address(pool2), wstETHBalance2);

        uint256 rETHBalanceBefore1 = rETH1.balanceOf(user2);
        uint256 rETHBalanceBefore2 = rETH2.balanceOf(user2);

        pool1.swap(1, 0, wstETHBalance1, 0);
        uint256 rETHBalance1 = rETH1.balanceOf(user2) - rETHBalanceBefore1;

        pool2.swap(1, 0, wstETHBalance2, 0);
        uint256 rETHBalance2 = rETH2.balanceOf(user2) - rETHBalanceBefore2;
        vm.stopPrank();

        int256 profit1 = int256(rETHBalance1) - int256(swapAmount);
        int256 profit2 = int256(rETHBalance2) - int256(swapAmount);

        bool isSignificantRateChange = newRatePercent <= 95 || newRatePercent >= 105;
        bool isFreshRate = timeElapsed <= 1 days;

        if (isSignificantRateChange && isFreshRate && exchangeRateFeeFactor > 1e10) {
            assertLe(profit2, profit1, "Protected pool should yield less profit on rate exploit");
        }
    }
}
