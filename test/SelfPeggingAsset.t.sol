// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Vm } from "forge-std/Vm.sol";
import { Test, console2 } from "forge-std/Test.sol";

import { SelfPeggingAssetFactory } from "../src/SelfPeggingAssetFactory.sol";
import { MockToken } from "../src/mock/MockToken.sol";
import { SelfPeggingAsset } from "../src/SelfPeggingAsset.sol";
import { SPAToken } from "../src/SPAToken.sol";
import { WSPAToken } from "../src/WSPAToken.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "../src/misc/ConstantExchangeRateProvider.sol";
import "../src/mock/MockExchangeRateProvider.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { RampAController } from "../src/periphery/RampAController.sol";

contract SelfPeggingAssetTest is Test {
    address owner = address(0x01);
    address user = address(0x02);
    address user2 = address(0x03);
    uint256 A = 100;
    SPAToken spaToken;
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

        ERC1967Proxy proxy = new ERC1967Proxy(address(new SPAToken()), new bytes(0));

        spaToken = SPAToken(address(proxy));

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

        bytes memory data = abi.encodeCall(
            SelfPeggingAsset.initialize,
            (tokens, precisions, fees, 0, spaToken, A, exchangeRateProviders, address(0), 0, owner)
        );

        proxy = new ERC1967Proxy(address(new SelfPeggingAsset()), data);

        pool = SelfPeggingAsset(address(proxy));
        spaToken.initialize("SPA Token", "SPA", 0, owner, address(pool));
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

        (uint256 spaTokensMinted, uint256 feesCharged) = pool.getMintAmount(amounts);

        uint256 totalAmount = spaTokensMinted + feesCharged;
        assertEq(totalAmount, 200e18);

        assertEq(100e18, WETH.balanceOf(user));
        assertEq(100e18, frxETH.balanceOf(user));
        assertEq(0, spaToken.balanceOf(user));
        assertEq(0, pool.balances(0));
        assertEq(0, pool.balances(1));
        assertEq(0, pool.totalSupply());

        vm.prank(user);
        pool.mint(amounts, 0);

        assertEq(0, WETH.balanceOf(user));
        assertEq(0, frxETH.balanceOf(user));
        assertIsCloseTo(totalAmount, spaToken.balanceOf(user) + spaToken.NUMBER_OF_DEAD_SHARES(), 2 wei);
        assertEq(spaTokensMinted, spaToken.sharesOf(user) + spaToken.NUMBER_OF_DEAD_SHARES());
        assertEq(totalAmount, spaToken.totalSupply());
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
        // spaToken _spaToken = new spaToken();

        ERC1967Proxy proxy = new ERC1967Proxy(address(new SPAToken()), new bytes(0));
        SPAToken _spaToken = SPAToken(address(proxy));

        uint256[] memory _fees = new uint256[](3);
        _fees[0] = 0;
        _fees[1] = 0;
        _fees[2] = 0;

        uint256[] memory _precisions = new uint256[](2);
        _precisions[0] = 1;
        _precisions[1] = 1;

        bytes memory data = abi.encodeCall(
            SelfPeggingAsset.initialize,
            (_tokens, _precisions, _fees, 0, _spaToken, A, exchangeRateProviders, address(0), 0, owner)
        );

        proxy = new ERC1967Proxy(address(new SelfPeggingAsset()), data);
        SelfPeggingAsset _pool = SelfPeggingAsset(address(proxy));

        _spaToken.initialize("SPA Token", "SPAT", 5e8, owner, address(_pool));

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 110e18;
        amounts[1] = 90e18;

        (uint256 spaTokensMinted,) = _pool.getMintAmount(amounts);

        assertIsCloseTo(spaTokensMinted, 229e18, 0.01e18);
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

        assertEq(pool.totalSupply(), 189.994_704_791_049_550_806e18);

        assertEq(pool.totalSupply(), spaToken.totalSupply());

        vm.prank(user2);
        pool.swap(1, 0, 8e18, 0);

        assertEq(WETH.balanceOf(user2), exchangeAmount);
        assertEq(frxETH.balanceOf(user2), 0);

        assertEq(WETH.balanceOf(address(pool)), 105e18 - exchangeAmount);
        assertEq(frxETH.balanceOf(address(pool)), 85e18 + 8e18);
        assertEq(pool.totalSupply(), spaToken.totalSupply());
    }

    function test_redeemCorrectAmountWithProportionalRedemption() external {
        uint256[] memory mintAmounts = new uint256[](2);
        mintAmounts[0] = 105e18;
        mintAmounts[1] = 85e18;

        // uint256 totalAmount = mintAmounts[0] + mintAmounts[1];

        WETH.mint(user, 105e18);
        frxETH.mint(user, 85e18);

        vm.startPrank(user);
        WETH.approve(address(pool), 105e18);
        frxETH.approve(address(pool), 85e18);

        pool.mint(mintAmounts, 0);
        vm.stopPrank();

        (uint256[] memory tokenAmounts) = pool.getRedeemProportionAmount(25e18);
        uint256 token1Amount = tokenAmounts[0];
        uint256 token2Amount = tokenAmounts[1];

        // uint256 totalShares = spaToken.totalShares();
        // uint256 totalBalance = spaToken.totalSupply();

        vm.prank(user);
        spaToken.transfer(user2, 25e18);

        // uint256 shares2 = spaToken.sharesOf(user2);
        // uint256 balance2 = spaToken.balanceOf(user2);

        assertEq(WETH.balanceOf(user2), 0);
        assertEq(frxETH.balanceOf(user2), 0);

        assertEq(WETH.balanceOf(address(pool)), 105e18);
        assertEq(frxETH.balanceOf(address(pool)), 85e18);

        assertEq(pool.balances(0), 105e18);
        assertEq(pool.balances(1), 85e18);

        assertEq(pool.totalSupply(), 189.994_704_791_049_550_806e18);
        assertEq(spaToken.totalSupply(), 189.994_704_791_049_550_806e18);

        uint256 amountToRedeem = spaToken.balanceOf(user2);
        vm.startPrank(user2);
        spaToken.approve(address(pool), amountToRedeem);
        uint256[] memory _minRedeemAmounts = new uint256[](2);
        pool.redeemProportion(amountToRedeem, _minRedeemAmounts);
        vm.stopPrank();

        assertEq(WETH.balanceOf(user2), token1Amount);
        assertEq(frxETH.balanceOf(user2), token2Amount);

        assertEq(spaToken.sharesOf(user2), 0);
        assertEq(spaToken.balanceOf(user2), 0);

        assertEq(WETH.balanceOf(address(pool)), 105e18 - token1Amount);
        assertEq(frxETH.balanceOf(address(pool)), 85e18 - token2Amount);

        assertIsCloseTo(pool.balances(0), 105e18 - token1Amount * precisions[0], 0);
        assertIsCloseTo(pool.balances(1), 85e18 - token2Amount * precisions[1], 0);

        assertEq(pool.totalSupply(), spaToken.totalSupply());
    }

    function test_redeemCorrectAmountToSingleToken() external {
        uint256[] memory mintAmounts = new uint256[](2);
        mintAmounts[0] = 105e18;
        mintAmounts[1] = 85e18;

        // uint256 totalAmount = mintAmounts[0] + mintAmounts[1];

        WETH.mint(user, 105e18);
        frxETH.mint(user, 85e18);

        vm.startPrank(user);
        WETH.approve(address(pool), 105e18);
        frxETH.approve(address(pool), 85e18);

        pool.mint(mintAmounts, 0);
        vm.stopPrank();

        (uint256 token1Amount,) = pool.getRedeemSingleAmount(25e18, 0);

        vm.prank(user);
        spaToken.transfer(user2, 25e18);

        assertEq(WETH.balanceOf(user2), 0);
        assertEq(frxETH.balanceOf(user2), 0);

        assertEq(WETH.balanceOf(address(pool)), 105e18);
        assertEq(frxETH.balanceOf(address(pool)), 85e18);

        assertEq(pool.balances(0), 105e18);
        assertEq(pool.balances(1), 85e18);

        assertEq(pool.totalSupply(), spaToken.totalSupply());

        uint256 redeemAmount = spaToken.balanceOf(user2);
        vm.startPrank(user2);
        spaToken.approve(address(pool), redeemAmount);
        pool.redeemSingle(redeemAmount, 0, 0);
        vm.stopPrank();

        assertEq(WETH.balanceOf(user2), token1Amount);
        assertEq(frxETH.balanceOf(user2), 0);
        assertEq(spaToken.sharesOf(user2), 0);

        assertEq(WETH.balanceOf(address(pool)), 105e18 - token1Amount);
        assertEq(frxETH.balanceOf(address(pool)), 85e18);
        assertIsCloseTo(pool.balances(0), 105e18 - token1Amount * precisions[0], 0);
        assertEq(pool.balances(1), 85e18);
        assertEq(pool.totalSupply(), spaToken.totalSupply());
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
        spaToken.transfer(user2, 25e18);

        uint256 balance = spaToken.balanceOf(user2);

        assertEq(WETH.balanceOf(user2), 0);
        assertEq(frxETH.balanceOf(user2), 0);
        assertEq(spaToken.balanceOf(user2), balance);

        assertEq(WETH.balanceOf(address(pool)), 105e18);
        assertEq(frxETH.balanceOf(address(pool)), 85e18);

        assertEq(pool.balances(0), 105e18);
        assertEq(pool.balances(1), 85e18);

        assertEq(pool.totalSupply(), spaToken.totalSupply());

        vm.startPrank(user2);
        spaToken.approve(address(pool), redeemAmount);
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
        assertEq(pool.totalSupply(), spaToken.totalSupply());
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
        (uint256[] memory tokenAmounts) = pool.getRedeemProportionAmount(redeemAmount);

        uint256 token1Amount = tokenAmounts[0];
        uint256 token2Amount = tokenAmounts[1];

        assertEq(token1Amount, 14_375_822_996_542_859_135);
        assertEq(token2Amount, 10_625_608_301_792_548_056);
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

        assertEq(exchangeAmount, 7.992_985_053_666_343_961e18);
        assertEq(feeAmount, 0.016_018_006_119_571_831e18);
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

        assertEq(pool.totalSupply(), 189.994_704_791_049_550_806e18);

        assertEq(pool.totalSupply(), spaToken.totalSupply());

        vm.prank(user2);
        pool.swap(1, 0, 8e18, 0);

        assertLt(WETH.balanceOf(user2), exchangeAmount);
    }

    function test_FeeAmount() external {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e18;
        amounts[1] = 50e18;

        WETH.mint(user, 100e18);
        frxETH.mint(user, 50e18);

        vm.startPrank(user);
        WETH.approve(address(pool), 100e18);
        frxETH.approve(address(pool), 50e18);
        vm.stopPrank();

        uint256[] memory initial = new uint256[](2);
        initial[0] = 1000e18;
        initial[1] = 1000e18;
        WETH.mint(address(this), 1000e18);
        frxETH.mint(address(this), 1000e18);
        WETH.approve(address(pool), 1000e18);
        frxETH.approve(address(pool), 1000e18);
        pool.mint(initial, 0);

        (uint256 mintAmount, uint256 feeAmount) = pool.getMintAmount(amounts);

        assertNotEq(feeAmount, 0, "feeAmount should not return 0");
    }

    function test_BurnValue_With_Losing_Shares() public {
        // two users, user and user2, enter as liquidity providers.
        uint256 liquidity = 100e18;
        WETH.mint(user, liquidity);
        frxETH.mint(user, liquidity);
        WETH.mint(user2, liquidity);
        frxETH.mint(user2, liquidity);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = liquidity;
        amounts[1] = liquidity;

        vm.startPrank(user);
        WETH.approve(address(pool), liquidity);
        frxETH.approve(address(pool), liquidity);
        pool.mint(amounts, 0);
        vm.stopPrank();

        vm.startPrank(user2);
        WETH.approve(address(pool), liquidity);
        frxETH.approve(address(pool), liquidity);
        pool.mint(amounts, 0);
        vm.stopPrank();

        // we create a profit balance (totalSupply > totalShares) via donation.
        uint256 donation = 100e18;
        WETH.mint(owner, donation);
        vm.prank(owner);
        WETH.transfer(address(pool), donation);
        pool.rebase();

        assertTrue(
            spaToken.totalSupply() > spaToken.totalShares(),
            "Condition totalSupply > totalShares must be met for attack."
        );

        uint256 user2_Shares_before = spaToken.sharesOf(user2);
        uint256 user_Balance_before = spaToken.balanceOf(user);
        uint256 totalSupply_before = spaToken.totalSupply();

        // attack: User `user2` calls burnShares(1) in a loop to destroy the value.
        uint256 iterations = 100;
        vm.startPrank(user2);
        for (uint256 i = 0; i < iterations; i++) {
            spaToken.burnShares(1);
        }
        vm.stopPrank();

        // check
        uint256 user2_Shares_after = spaToken.sharesOf(user2);
        uint256 user_Balance_after = spaToken.balanceOf(user);
        uint256 totalSupply_after = spaToken.totalSupply();

        // user2 shares are dropped
        assertGt(user2_Shares_before, user2_Shares_after, "User2's shares should have decreased");

        // total supply decreased by the amount that user2 burned
        assertEq(
            totalSupply_after,
            totalSupply_before - iterations,
            "TotalSupply should have decreased by number of iterations"
        );

        assertGt(user_Balance_after, user_Balance_before, "User's balance should have increased");
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

        ERC1967Proxy proxy = new ERC1967Proxy(address(new SPAToken()), new bytes(0));
        SPAToken _spaToken = SPAToken(address(proxy));

        uint256[] memory _fees = new uint256[](3);
        _fees[0] = 0;
        _fees[1] = 0;
        _fees[2] = 0;

        uint256[] memory _precisions = new uint256[](2);
        _precisions[0] = 1;
        _precisions[1] = 1;

        bytes memory data = abi.encodeCall(
            SelfPeggingAsset.initialize,
            (_tokens, _precisions, _fees, 0, _spaToken, A, exchangeRateProviders, address(0), 0, owner)
        );
        proxy = new ERC1967Proxy(address(new SelfPeggingAsset()), data);
        SelfPeggingAsset _pool = SelfPeggingAsset(address(proxy));

        _spaToken.initialize("SPA Token", "TSPA", 5e8, owner, address(_pool));

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
        assertIsCloseTo(wstETHBalance, 1e18, 0.000_05 ether);

        // Set buffer percentage to 5%
        vm.prank(owner);
        _spaToken.setBuffer(0.05e10);
        vm.stopPrank();

        // Add yield
        rETHExchangeRateProvider.newRate(2e18);
        _pool.rebase();

        assertIsCloseTo(_spaToken.bufferAmount(), 5e18, 0.05 ether);
        assertEq(_spaToken.bufferBadDebt(), 0);

        // Drop the exchange rate by 1% so that the pool is in loss and buffer can cover the loss
        rETHExchangeRateProvider.newRate(1.98e18);
        _pool.rebase();

        assertIsCloseTo(_spaToken.bufferAmount(), 3e18, 0.03 ether);
        assertIsCloseTo(_spaToken.bufferBadDebt(), 2e18, 0.02 ether);

        // Drop the exchange rate by 90% so that the pool is in loss and buffer can't cover the loss
        rETHExchangeRateProvider.newRate(0.2e18);
        vm.expectRevert(abi.encodeWithSignature("InsufficientBuffer()"));
        _pool.rebase();

        // Trigger negative rebase
        assertIsCloseTo(_spaToken.totalSupply(), 295e18, 0.9e18);
        vm.startPrank(owner);
        _pool.pause();
        _pool.distributeLoss();

        assertIsCloseTo(_spaToken.totalSupply(), 115e18, 1e18);

        // Recover bad debt
        assertNotEq(_spaToken.bufferBadDebt(), 0);
        rETHExchangeRateProvider.newRate(1e18);
        _pool.rebase();
        assertEq(_spaToken.bufferBadDebt(), 0);
    }

    function test_BadDebtClearedWithDonateD() external {
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

        ERC1967Proxy proxy = new ERC1967Proxy(address(new SPAToken()), new bytes(0));
        SPAToken _spaToken = SPAToken(address(proxy));

        uint256[] memory _fees = new uint256[](3);
        _fees[0] = 0;
        _fees[1] = 0;
        _fees[2] = 0;

        uint256[] memory _precisions = new uint256[](2);
        _precisions[0] = 1;
        _precisions[1] = 1;

        bytes memory data = abi.encodeCall(
            SelfPeggingAsset.initialize,
            (_tokens, _precisions, _fees, 0, _spaToken, A, exchangeRateProviders, address(0), 0, owner)
        );
        proxy = new ERC1967Proxy(address(new SelfPeggingAsset()), data);
        SelfPeggingAsset _pool = SelfPeggingAsset(address(proxy));

        _spaToken.initialize("SPA Token", "TSPA", 5e8, owner, address(_pool));

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e18;
        amounts[1] = 100e18;

        // Mint Liquidity
        rETH.mint(user, 500e18);
        wstETH.mint(user, 500e18);

        vm.startPrank(user);
        rETH.approve(address(_pool), 500e18);
        wstETH.approve(address(_pool), 500e18);

        _pool.mint(amounts, 0);
        vm.stopPrank();

        // Set buffer percentage to 5%
        vm.prank(owner);
        _spaToken.setBuffer(0.05e10);
        vm.stopPrank();

        // Add yield
        rETHExchangeRateProvider.newRate(2e18);
        _pool.rebase();

        // Drop the exchange rate by 1% so that the pool is in loss and buffer can cover the loss
        // A = 10;
        rETHExchangeRateProvider.newRate(1.98e18);
        _pool.rebase();
        uint256 bufferAmount = _spaToken.bufferAmount();
        uint256 bufferBadDebt = _spaToken.bufferBadDebt();
        assert(bufferBadDebt > 0);

        uint256[] memory donationAmounts = new uint256[](2);
        donationAmounts[0] = 10e18;
        donationAmounts[1] = 5e18;
        uint256 minDonationAmount = 14e18;

        vm.prank(user);
        _pool.donateD(donationAmounts, minDonationAmount);

        uint256 bufferAmountAfter = _spaToken.bufferAmount();
        uint256 bufferBadDebtAfter = _spaToken.bufferBadDebt();

        assert(bufferBadDebtAfter < bufferBadDebt);
        assert(bufferAmountAfter > bufferAmount);
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

        uint256 previewMint;
        (previewMint,) = pool.getMintAmount(amounts);
        uint256 minted = pool.mint(amounts, 0);
        assertEq(minted, previewMint);
        assertGt(200e18 - minted, 0);
        assertLt(200e18 - minted, 0.02e18); // ensure not inflated
    }

    function assertAlmostTheSame(uint256 num1, uint256 num2) internal pure {
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

    function assertInvariant(uint256 balance0, uint256 balance1, uint256 valueA, uint256 D) internal pure {
        // We only check n = 2 here
        uint256 left = (valueA * 4) * (balance0 + balance1) + D;
        uint256 denominator = balance0 * balance1 * 4;
        assert(denominator > 0);
        uint256 right = (valueA * 4) * D + (D ** 3) / denominator;

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
        uint256 initialBuffer = spaToken.bufferAmount();
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
        assertEq(spaToken.bufferAmount(), expectedBuffer);
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

        ERC1967Proxy proxy1 = new ERC1967Proxy(address(new SPAToken()), new bytes(0));
        SPAToken _spaToken1 = SPAToken(address(proxy1));

        ERC1967Proxy proxy2 = new ERC1967Proxy(address(new SPAToken()), new bytes(0));
        SPAToken _spaToken2 = SPAToken(address(proxy2));

        uint256[] memory _fees = new uint256[](3);
        _fees[0] = 0;
        _fees[1] = 0.000_01e10;
        _fees[2] = 0;

        uint256[] memory _precisions = new uint256[](2);
        _precisions[0] = 1;
        _precisions[1] = 1;

        bytes memory data = abi.encodeCall(
            SelfPeggingAsset.initialize,
            (_tokens1, _precisions, _fees, 0, _spaToken1, A, exchangeRateProviders1, address(0), 0, owner)
        );

        proxy1 = new ERC1967Proxy(address(new SelfPeggingAsset()), data);
        SelfPeggingAsset _pool1 = SelfPeggingAsset(address(proxy1));
        _spaToken1.initialize("SPA Token", "SPAT", 5e8, owner, address(_pool1));

        data = abi.encodeCall(
            SelfPeggingAsset.initialize,
            (_tokens2, _precisions, _fees, 0, _spaToken2, A, exchangeRateProviders2, address(0), 1e10, owner)
        );

        proxy2 = new ERC1967Proxy(address(new SelfPeggingAsset()), data);
        SelfPeggingAsset _pool2 = SelfPeggingAsset(address(proxy2));

        _spaToken2.initialize("SPA Token", "SPAT", 5e8, owner, address(_pool2));

        vm.prank(address(_pool1));
        _spaToken1.addBuffer(100e18, true);

        vm.prank(address(_pool2));
        _spaToken2.addBuffer(100e18, true);

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

        ERC1967Proxy proxy1 = new ERC1967Proxy(address(new SPAToken()), new bytes(0));
        SPAToken _spaToken1 = SPAToken(address(proxy1));

        ERC1967Proxy proxy2 = new ERC1967Proxy(address(new SPAToken()), new bytes(0));
        SPAToken _spaToken2 = SPAToken(address(proxy2));

        uint256[] memory _fees = new uint256[](3);
        _fees[0] = 0;
        _fees[1] = 0.000_01e10;
        _fees[2] = 0;

        uint256[] memory _precisions = new uint256[](2);
        _precisions[0] = 1;
        _precisions[1] = 1;

        bytes memory data = abi.encodeCall(
            SelfPeggingAsset.initialize,
            (_tokens1, _precisions, _fees, 0, _spaToken1, A, exchangeRateProviders1, address(0), 1e10, owner)
        );

        proxy1 = new ERC1967Proxy(address(new SelfPeggingAsset()), data);
        SelfPeggingAsset _pool1 = SelfPeggingAsset(address(proxy1));
        _spaToken1.initialize("SPA Token", "SPAT", 5e8, owner, address(_pool1));

        vm.prank(owner);
        _pool1.setRateChangeSkipPeriod(10 seconds);

        data = abi.encodeCall(
            SelfPeggingAsset.initialize,
            (_tokens2, _precisions, _fees, 0, _spaToken2, A, exchangeRateProviders2, address(0), 1e10, owner)
        );

        proxy2 = new ERC1967Proxy(address(new SelfPeggingAsset()), data);
        SelfPeggingAsset _pool2 = SelfPeggingAsset(address(proxy2));

        _spaToken2.initialize("SPA Token", "SPAT", 5e8, owner, address(_pool2));

        vm.prank(address(_pool1));
        _spaToken1.addBuffer(100e18, true);

        vm.prank(address(_pool2));
        _spaToken2.addBuffer(100e18, true);

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

        ERC1967Proxy proxy = new ERC1967Proxy(address(new SPAToken()), new bytes(0));
        SPAToken spaToken1 = SPAToken(address(proxy));

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

        uint256[] memory precisionsArray = new uint256[](2);
        precisionsArray[0] = 1;
        precisionsArray[1] = 1;

        bytes memory data = abi.encodeCall(
            SelfPeggingAsset.initialize,
            (tokens, precisionsArray, fees, 0, spaToken1, 100, providers, address(0), 1e10, owner)
        );

        proxy = new ERC1967Proxy(address(new SelfPeggingAsset()), data);
        SelfPeggingAsset spa = SelfPeggingAsset(address(proxy));
        spaToken1.initialize("SPA Token", "TSPA", 5e8, owner, address(spa));

        vm.startPrank(owner);
        spa.setRateChangeSkipPeriod(10 seconds);
        spa.setDecayPeriod(10 seconds);
        vm.stopPrank();

        vm.prank(address(spa));
        spaToken1.addBuffer(100e18, true);

        rETH.mint(user, 100e18);
        wstETH.mint(user, 100e18);

        vm.startPrank(user);
        rETH.approve(address(spa), 100e18);
        wstETH.approve(address(spa), 100e18);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e18;
        amounts[1] = 100e18;
        spa.mint(amounts, 0);
        vm.stopPrank();

        (, uint256 initFee) = spa.getRedeemSingleAmount(10e18, 0);
        console2.log("Initial fee:", initFee);

        // Change exchange rate
        provider0.setExchangeRate(0.9e18);
        (, uint256 volatilityFee) = spa.getRedeemSingleAmount(10e18, 0);
        console2.log("fee after volatility period:", volatilityFee);

        // during decay period
        vm.warp(block.timestamp + 9 seconds);
        (, uint256 beforeSkipFee) = spa.getRedeemSingleAmount(10e18, 0);
        console2.log("fee before skip period:", beforeSkipFee);

        // do an operation and fee spike
        vm.startPrank(user);
        spaToken1.approve(address(spa), 10e18);
        spa.redeemSingle(10e18, 0, 0);
        vm.stopPrank();

        (, uint256 postOpFeeSpike) = spa.getRedeemSingleAmount(10e18, 0);
        console2.log("Fee after operation:", postOpFeeSpike);

        bool feeSpikeAfterOp =
            (postOpFeeSpike <= beforeSkipFee * 995 / 1000) || (postOpFeeSpike >= beforeSkipFee * 1005 / 1000);

        // Change exchange rate further
        provider0.setExchangeRate(0.8e18);
        (, uint256 volatilityFee2) = spa.getRedeemSingleAmount(10e18, 0);
        console2.log("fee after volatility period:", volatilityFee2);

        // during decay period
        vm.warp(block.timestamp + 9 seconds);
        (, uint256 beforeSkipFee2) = spa.getRedeemSingleAmount(10e18, 0);
        console2.log("fee after skip period:", beforeSkipFee2);

        // skip past decay period
        vm.warp(block.timestamp + 1 hours);
        (, uint256 afterSkipFee) = spa.getRedeemSingleAmount(10e18, 0);
        console2.log("fee after skip period:", afterSkipFee);

        // do an operation and fee doesn't spike
        vm.startPrank(user);
        spaToken1.approve(address(spa), 10e18);
        spa.redeemSingle(10e18, 0, 0);
        vm.stopPrank();

        (, uint256 postOpFee) = spa.getRedeemSingleAmount(10e18, 0);
        console2.log("Fee after operation:", postOpFee);

        bool feeAfterOp = (postOpFee >= afterSkipFee * 995 / 1000) && (postOpFee <= afterSkipFee * 1005 / 1000);

        assertNotEq(volatilityFee, initFee, "fee changed during volatility");
        assertEq(feeSpikeAfterOp, true, "fee spike out of range after redeem");
        assertEq(beforeSkipFee2, volatilityFee2, "fee keep spiked before skip");
        assertLe(afterSkipFee, volatilityFee2, "fee stabilized after skip");
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

        ERC1967Proxy proxy1 = new ERC1967Proxy(address(new SPAToken()), new bytes(0));
        SPAToken spaToken1 = SPAToken(address(proxy1));

        ERC1967Proxy proxy2 = new ERC1967Proxy(address(new SPAToken()), new bytes(0));
        SPAToken spaToken2 = SPAToken(address(proxy2));

        uint256[] memory fees = new uint256[](3);
        fees[0] = 0;
        fees[1] = 0.000_01e10;
        fees[2] = 0;
        precisions[0] = 1;
        precisions[1] = 1;

        bytes memory data = abi.encodeCall(
            SelfPeggingAsset.initialize, (tokens1, precisions, fees, 0, spaToken1, A, providers1, address(0), 0, owner)
        );
        proxy1 = new ERC1967Proxy(address(new SelfPeggingAsset()), data);
        SelfPeggingAsset pool1 = SelfPeggingAsset(address(proxy1));
        spaToken1.initialize("SPA Token 1", "TSPA1", 5e8, owner, address(pool1));

        vm.prank(owner);
        pool1.setRateChangeSkipPeriod(100 days);

        data = abi.encodeCall(
            SelfPeggingAsset.initialize,
            (tokens2, precisions, fees, 0, spaToken2, A, providers2, address(0), exchangeRateFeeFactor, owner)
        );
        proxy2 = new ERC1967Proxy(address(new SelfPeggingAsset()), data);
        SelfPeggingAsset pool2 = SelfPeggingAsset(address(proxy2));
        spaToken2.initialize("SPA Token 2", "TSPA2", 5e8, owner, address(pool2));

        vm.prank(owner);
        pool2.setRateChangeSkipPeriod(100 days);

        uint256 bufferSize = initialLiquidity * 3;
        vm.prank(address(pool1));
        spaToken1.addBuffer(bufferSize, true);

        vm.prank(address(pool2));
        spaToken2.addBuffer(bufferSize, true);

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

    function test_ValuePrecisionLoss() external {
        MockExchangeRateProvider testToken1Rate = new MockExchangeRateProvider(1.9999e18, 18);
        MockExchangeRateProvider testToken2Rate = new MockExchangeRateProvider(1.9999e18, 18);

        MockToken token1 = new MockToken("token1", "token1", 6);
        MockToken token2 = new MockToken("token2", "token2", 6);

        address[] memory _tokens = new address[](2);
        _tokens[0] = address(token1);
        _tokens[1] = address(token2);

        IExchangeRateProvider[] memory exchangeRateProviders = new IExchangeRateProvider[](2);
        exchangeRateProviders[0] = IExchangeRateProvider(testToken1Rate);
        exchangeRateProviders[1] = IExchangeRateProvider(testToken2Rate);

        ERC1967Proxy proxy = new ERC1967Proxy(address(new SPAToken()), new bytes(0));
        SPAToken _spaToken = SPAToken(address(proxy));

        uint256[] memory _fees = new uint256[](3);
        _fees[0] = 0;
        _fees[1] = 0;
        _fees[2] = 0;

        uint256[] memory _precisions = new uint256[](2);
        _precisions[0] = 1e12;
        _precisions[1] = 1e12;

        bytes memory data = abi.encodeCall(
            SelfPeggingAsset.initialize,
            (_tokens, _precisions, _fees, 0, _spaToken, A, exchangeRateProviders, address(0), 0, owner)
        );
        proxy = new ERC1967Proxy(address(new SelfPeggingAsset()), data);
        SelfPeggingAsset _pool = SelfPeggingAsset(address(proxy));

        _spaToken.initialize("SPA Token", "TSPA", 5e8, owner, address(_pool));

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1e6;
        amounts[1] = 1e6;

        // Mint Liquidity
        token1.mint(user, 1e6);
        token2.mint(user, 1e6);

        vm.startPrank(user);
        token1.approve(address(_pool), 1e6);
        token2.approve(address(_pool), 1e6);

        _pool.mint(amounts, 0);
        vm.stopPrank();

        // swap 1 token1 to token2
        token1.mint(user2, 1e4);

        vm.startPrank(user2);
        token1.approve(address(_pool), 1e4);
        _pool.swap(0, 1, 1e4, 0);
        vm.stopPrank();

        // the swap above was called to trigger syncing the contract total supply after this we can estimate the current
        // contract value based on the current exchange rate and buffer
        uint256 value1 = token1.balanceOf(address(_pool));
        value1 = (value1 * 1.9999e18 * _precisions[0]) / (10 ** 18);
        uint256 value2 = token2.balanceOf(address(_pool));
        value2 = (value2 * 1.9999e18 * _precisions[1]) / (10 ** 18);
        // 1.9999e18 is exchange rate valuetoken2
        uint256 initialValuesBeforeRebase = value1 + value2;

        // Set buffer percentage to 5%
        vm.prank(owner);
        _spaToken.setBuffer(0.05e10);
        vm.stopPrank();
        // Add yield, new rate for token 1
        uint256 token1newRate = 2e18;
        testToken1Rate.newRate(token1newRate);

        // after setting new buffer and new exchange, an estimate of what rebase added value to contract would look like
        // is calculated below, rebase should correctly give a value close to this if precision mutiplication was
        // handled correctly, based on current supply value
        value1 = token1.balanceOf(address(_pool));
        value1 = (value1 * token1newRate * _precisions[0]) / (10 ** 18);
        value2 = token2.balanceOf(address(_pool));
        value2 = (value2 * 1.9999e18 * _precisions[1]) / (10 ** 18);

        uint256 correctEstimatedExpectedRebase = value1 + value2 - initialValuesBeforeRebase;

        uint256 actualRebase = _pool.rebase();

        // after fix, rebase value should be very close to the expected one
        assertApproxEqRel(actualRebase, correctEstimatedExpectedRebase, 1e14); // <0.01% deviation
    }

    function test_c322_RedeemSingleDynamicFee() external {
        uint256 minted = _mintInitialLiquidityRedeem();
        uint256 redeemAmount = minted / 2; // redeem half

        (uint256 previewUnderlying, uint256 previewFeeSpa) = pool.getRedeemSingleAmount(redeemAmount, 0);

        uint256 userWethBefore = WETH.balanceOf(user);
        uint256 userSpaBefore = spaToken.balanceOf(user);

        vm.startPrank(user);
        spaToken.approve(address(pool), redeemAmount);
        uint256 received = pool.redeemSingle(redeemAmount, 0, 0);
        vm.stopPrank();

        assertApproxEqRel(received, previewUnderlying, 0.01e18);
        uint256 userSpaAfter = spaToken.balanceOf(user);
        assertApproxEqRel(userSpaBefore - userSpaAfter, redeemAmount, 0.01e18);

        // 0.5%
        uint256 expectedFeeSpa = (redeemAmount * redeemFee) / feeDenominator;
        // 5% tolerance
        assertApproxEqRel(previewFeeSpa, expectedFeeSpa, 0.05e18);
        assertEq(WETH.balanceOf(user) - userWethBefore, received);
    }

    function test_c322_RedeemMultiDynamicFee() external {
        _mintInitialLiquidityRedeem();

        uint256[] memory desired = new uint256[](2);
        desired[0] = 10e18;
        desired[1] = 8e18;

        (uint256 previewSpa, uint256 previewFee) = pool.getRedeemMultiAmount(desired);

        uint256 spaBefore = spaToken.balanceOf(user);
        uint256 wethBefore = WETH.balanceOf(user);
        uint256 frxBefore = frxETH.balanceOf(user);

        vm.startPrank(user);
        spaToken.approve(address(pool), previewSpa);
        uint256[] memory received = pool.redeemMulti(desired, previewSpa);
        vm.stopPrank();

        uint256 spaAfter = spaToken.balanceOf(user);
        assertApproxEqRel(spaBefore - spaAfter, previewSpa, 0.01e18);

        assertEq(received[0], desired[0]);
        assertEq(received[1], desired[1]);
        assertEq(WETH.balanceOf(user) - wethBefore, desired[0]);
        assertEq(frxETH.balanceOf(user) - frxBefore, desired[1]);

        // 0.5%
        uint256 feePercent = (previewFee * feeDenominator) / previewSpa;
        assertGt(feePercent, 0);
        // proportionally balanced
        assertLt(feePercent, redeemFee / 10);
    }

    function test_c322_RedeemMultiFee_NonUnity_WithinBaseBounds() external {
        MockExchangeRateProvider p0 = new MockExchangeRateProvider(12e17, 18); // 1.2
        MockExchangeRateProvider p1 = new MockExchangeRateProvider(95e16, 18); // 0.95

        MockToken t0 = new MockToken("t0", "t0", 18);
        MockToken t1 = new MockToken("t1", "t1", 18);

        address[] memory _tokens = new address[](2);
        _tokens[0] = address(t0);
        _tokens[1] = address(t1);

        IExchangeRateProvider[] memory providers = new IExchangeRateProvider[](2);
        providers[0] = IExchangeRateProvider(p0);
        providers[1] = IExchangeRateProvider(p1);

        uint256[] memory _fees = new uint256[](3);
        _fees[0] = 0;
        _fees[1] = 0;
        _fees[2] = redeemFee;

        uint256[] memory _precisions = new uint256[](2);
        _precisions[0] = 1;
        _precisions[1] = 1;

        ERC1967Proxy proxy = new ERC1967Proxy(address(new SPAToken()), new bytes(0));
        SPAToken spt = SPAToken(address(proxy));
        bytes memory data = abi.encodeCall(
            SelfPeggingAsset.initialize, (_tokens, _precisions, _fees, 0, spt, A, providers, address(0), 0, owner)
        );
        proxy = new ERC1967Proxy(address(new SelfPeggingAsset()), data);
        SelfPeggingAsset poolU = SelfPeggingAsset(address(proxy));
        spt.initialize("SPA Token UM", "SPAUM", 0, owner, address(poolU));

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 120e18;
        amounts[1] = 80e18;
        t0.mint(user, amounts[0]);
        t1.mint(user, amounts[1]);
        vm.startPrank(user);
        t0.approve(address(poolU), amounts[0]);
        t1.approve(address(poolU), amounts[1]);
        poolU.mint(amounts, 0);
        vm.stopPrank();

        uint256[] memory desired = new uint256[](2);
        desired[0] = 10e18;
        desired[1] = 8e18;

        (uint256 previewSpa, uint256 previewFee) = poolU.getRedeemMultiAmount(desired);

        uint256 feePercent = (previewFee * feeDenominator) / previewSpa;
        assertGt(feePercent, 0);
        assertLt(feePercent, redeemFee / 10);
    }

    function test_c322_Fuzz_RedeemFee_InvarianceAcrossDecimals(
        uint256 ratePercent,
        uint8 erDecimals,
        uint256 amount0,
        uint256 amount1,
        uint256 redeemPct,
        uint8 idx
    )
        public
    {
        // Bound parameters
        ratePercent = bound(ratePercent, 80, 120);
        erDecimals = uint8(bound(erDecimals, 6, 18));
        amount0 = bound(amount0, 50e18, 200e18);
        amount1 = bound(amount1, 50e18, 200e18);
        redeemPct = bound(redeemPct, 10, 90);
        idx = uint8(bound(idx, 0, 1));

        // different rates within [80, 120]
        uint256 rate0Pct = ratePercent;
        uint256 rate1Pct = 200 - ratePercent;

        uint256 rate0_18 = rate0Pct * 1e18 / 100;
        uint256 rate1_18 = rate1Pct * 1e18 / 100;
        uint256 rate0_var = rate0Pct * (10 ** erDecimals) / 100;
        uint256 rate1_var = rate1Pct * (10 ** erDecimals) / 100;

        MockToken t0 = new MockToken("t0", "t0", 18);
        MockToken t1 = new MockToken("t1", "t1", 18);

        SelfPeggingAsset pool18;
        {
            address[] memory toks = new address[](2);
            toks[0] = address(t0);
            toks[1] = address(t1);
            IExchangeRateProvider[] memory prov = new IExchangeRateProvider[](2);
            prov[0] = IExchangeRateProvider(new MockExchangeRateProvider(rate0_18, 18));
            prov[1] = IExchangeRateProvider(new MockExchangeRateProvider(rate1_18, 18));
            uint256[] memory fees = new uint256[](3);
            fees[0] = 0;
            fees[1] = 0;
            fees[2] = redeemFee;
            uint256[] memory prec = new uint256[](2);
            prec[0] = 1;
            prec[1] = 1;
            ERC1967Proxy proxy = new ERC1967Proxy(address(new SPAToken()), new bytes(0));
            SPAToken spt = SPAToken(address(proxy));
            bytes memory data =
                abi.encodeCall(SelfPeggingAsset.initialize, (toks, prec, fees, 0, spt, A, prov, address(0), 0, owner));
            proxy = new ERC1967Proxy(address(new SelfPeggingAsset()), data);
            pool18 = SelfPeggingAsset(address(proxy));
            spt.initialize("SPA18", "SPA18", 0, owner, address(pool18));
        }

        SelfPeggingAsset poolVar;
        {
            address[] memory toks = new address[](2);
            toks[0] = address(t0);
            toks[1] = address(t1);
            IExchangeRateProvider[] memory prov = new IExchangeRateProvider[](2);
            prov[0] = IExchangeRateProvider(new MockExchangeRateProvider(rate0_var, erDecimals));
            prov[1] = IExchangeRateProvider(new MockExchangeRateProvider(rate1_var, erDecimals));
            uint256[] memory fees = new uint256[](3);
            fees[0] = 0;
            fees[1] = 0;
            fees[2] = redeemFee;
            uint256[] memory prec = new uint256[](2);
            prec[0] = 1;
            prec[1] = 1;
            ERC1967Proxy proxy = new ERC1967Proxy(address(new SPAToken()), new bytes(0));
            SPAToken spt = SPAToken(address(proxy));
            bytes memory data =
                abi.encodeCall(SelfPeggingAsset.initialize, (toks, prec, fees, 0, spt, A, prov, address(0), 0, owner));
            proxy = new ERC1967Proxy(address(new SelfPeggingAsset()), data);
            poolVar = SelfPeggingAsset(address(proxy));
            spt.initialize("SPAV", "SPAV", 0, owner, address(poolVar));
        }

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount0;
        amounts[1] = amount1;
        t0.mint(user, amount0 * 2);
        t1.mint(user, amount1 * 2);
        vm.startPrank(user);
        t0.approve(address(pool18), amount0);
        t1.approve(address(pool18), amount1);
        uint256 spa18 = pool18.mint(amounts, 0);
        t0.approve(address(poolVar), amount0);
        t1.approve(address(poolVar), amount1);
        uint256 spaVar = poolVar.mint(amounts, 0);
        vm.stopPrank();

        uint256 redeem18 = spa18 * redeemPct / 100;
        uint256 redeemVar = spaVar * redeemPct / 100;

        (uint256 feePct18, uint256 feePctVar) = (uint256(0), uint256(0));

        if (idx == 0) {
            (uint256 out18, uint256 fee18) = pool18.getRedeemSingleAmount(redeem18, 0);
            feePct18 = (fee18 * 1e18) / ((out18 * rate0_18) / 1e18 + fee18);
            (uint256 outV, uint256 feeV) = poolVar.getRedeemSingleAmount(redeemVar, 0);
            feePctVar = (feeV * 1e18) / ((outV * rate0_var) / (10 ** erDecimals) + feeV);
        } else {
            (uint256 out18, uint256 fee18) = pool18.getRedeemSingleAmount(redeem18, 1);
            feePct18 = (fee18 * 1e18) / ((out18 * rate1_18) / 1e18 + fee18);
            (uint256 outV, uint256 feeV) = poolVar.getRedeemSingleAmount(redeemVar, 1);
            feePctVar = (feeV * 1e18) / ((outV * rate1_var) / (10 ** erDecimals) + feeV);
        }

        uint256 baseScaled = (redeemFee * 1e18) / feeDenominator;
        assertApproxEqRel(feePct18, baseScaled, 0.05e18);
        assertApproxEqRel(feePct18, feePctVar, 0.05e18);
    }

    // Helper to mint initial liquidity
    function _mintInitialLiquidityRedeem() internal returns (uint256 mintedSpa) {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 105e18;
        amounts[1] = 85e18;

        WETH.mint(user, amounts[0]);
        frxETH.mint(user, amounts[1]);

        vm.startPrank(user);
        WETH.approve(address(pool), amounts[0]);
        frxETH.approve(address(pool), amounts[1]);
        mintedSpa = pool.mint(amounts, 0);
        vm.stopPrank();
    }

    function test_MintFeeReportingMatchesPrePostDifference() external {
        uint256[] memory initial = new uint256[](2);
        initial[0] = 100e18;
        initial[1] = 100e18;

        WETH.mint(user, initial[0]);
        frxETH.mint(user, initial[1]);

        vm.startPrank(user);
        WETH.approve(address(pool), initial[0]);
        frxETH.approve(address(pool), initial[1]);
        pool.mint(initial, 0);
        vm.stopPrank();

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 30e18;
        amounts[1] = 70e18;
        (uint256 mintWithFee, uint256 feeReported) = pool.getMintAmount(amounts);
        assertGt(feeReported, 0);

        // disable to get pre-fee mint amount
        vm.prank(owner);
        pool.setMintFee(0);
        (uint256 mintNoFee, uint256 feeZero) = pool.getMintAmount(amounts);
        assertEq(feeZero, 0);

        // restore fee
        vm.prank(owner);
        pool.setMintFee(mintFee);

        WETH.mint(user, amounts[0]);
        frxETH.mint(user, amounts[1]);
        vm.startPrank(user);
        WETH.approve(address(pool), amounts[0]);
        frxETH.approve(address(pool), amounts[1]);
        uint256 mintedActual = pool.mint(amounts, 0);
        vm.stopPrank();

        // 1. actual minted matches fee preview
        assertEq(mintedActual, mintWithFee);
        // 2. reported fee matches actual
        uint256 actualFee = mintNoFee - mintedActual;
        assertApproxEqAbs(feeReported, actualFee, 1);
        assertGt(actualFee, 0);
        assertLt(actualFee, mintNoFee);
    }
}
