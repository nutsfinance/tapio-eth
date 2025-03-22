// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import { MockToken } from "../src/mock/MockToken.sol";
import { Zap } from "../src/periphery/Zap.sol";
import { SelfPeggingAsset } from "../src/SelfPeggingAsset.sol";
import { WLPToken } from "../src/WLPToken.sol";
import { ConstantExchangeRateProvider } from "../src/misc/ConstantExchangeRateProvider.sol";
import { IExchangeRateProvider } from "../src/interfaces/IExchangeRateProvider.sol";
import { LPToken } from "../src/LPToken.sol";

contract ZapTest is Test {
    using Math for uint256;

    Zap public zap;
    SelfPeggingAsset public spa;
    LPToken public lpToken;
    WLPToken public wlpToken;

    address public governance;
    address public admin;
    address public user1;
    address public user2;

    MockToken public token1;
    MockToken public token2;
    address[] public tokens;
    uint256 public constant INITIAL_BALANCE = 1_000_000 ether;
    uint256 public constant ADD_LIQUIDITY_AMOUNT = 10_000 ether;
    uint256 public constant MINT_AMOUNT = 5000 ether;
    uint256 public constant MIN_AMOUNT = 1 ether;

    event ZapIn(address indexed user, uint256 wlpAmount, uint256[] inputAmounts);
    event ZapOut(address indexed user, uint256 wlpAmount, uint256[] outputAmounts, bool proportional);

    function setUp() public {
        governance = vm.addr(1);
        admin = vm.addr(2);
        user1 = vm.addr(3);
        user2 = vm.addr(4);

        vm.startPrank(admin);

        token1 = new MockToken("Token 1", "t1", 18);
        token2 = new MockToken("Token 2", "t2", 6);

        tokens = new address[](2);
        tokens[0] = address(token1);
        tokens[1] = address(token2);

        lpToken = new LPToken();
        lpToken.initialize("Tapio LP Token", "tLP");
        lpToken.transferOwnership(governance);

        IExchangeRateProvider[] memory providers = new IExchangeRateProvider[](2);
        providers[0] = new ConstantExchangeRateProvider();
        providers[1] = new ConstantExchangeRateProvider();

        uint256[] memory precisions = new uint256[](2);
        precisions[0] = 10 ** 0;
        precisions[1] = 10 ** 12;

        uint256[] memory fees = new uint256[](3);
        fees[0] = 0;
        fees[1] = 0;
        fees[2] = 0;

        spa = new SelfPeggingAsset();
        spa.initialize(tokens, precisions, fees, 0, lpToken, 100, providers);

        vm.stopPrank();

        vm.prank(governance);
        lpToken.addPool(address(spa));

        vm.startPrank(admin);

        wlpToken = new WLPToken();
        wlpToken.initialize(lpToken);

        zap = new Zap(address(spa), address(wlpToken));

        token1.mint(user1, INITIAL_BALANCE);
        token2.mint(user1, INITIAL_BALANCE);
        token1.mint(user2, INITIAL_BALANCE);
        token2.mint(user2, INITIAL_BALANCE);

        vm.stopPrank();
    }

    function testInitialize() public view {
        assertEq(address(zap.spa()), address(spa));
        assertEq(address(zap.wlp()), address(wlpToken));
    }

    function testZapIn() public {
        token1.mint(user1, ADD_LIQUIDITY_AMOUNT);
        token2.mint(user1, ADD_LIQUIDITY_AMOUNT / 10 ** 12);

        vm.startPrank(admin);
        token1.mint(admin, ADD_LIQUIDITY_AMOUNT);
        token2.mint(admin, ADD_LIQUIDITY_AMOUNT / 10 ** 12);
        token1.approve(address(spa), ADD_LIQUIDITY_AMOUNT);
        token2.approve(address(spa), ADD_LIQUIDITY_AMOUNT / 10 ** 12);

        uint256[] memory initialAmounts = new uint256[](2);
        initialAmounts[0] = ADD_LIQUIDITY_AMOUNT;
        initialAmounts[1] = ADD_LIQUIDITY_AMOUNT / 10 ** 12;

        spa.mint(initialAmounts, 1);
        vm.stopPrank();

        vm.startPrank(user1);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = ADD_LIQUIDITY_AMOUNT;
        amounts[1] = ADD_LIQUIDITY_AMOUNT / 10 ** 12;

        token1.approve(address(zap), amounts[0]);
        token2.approve(address(zap), amounts[1]);

        uint256 initialWlpBalance = wlpToken.balanceOf(user1);
        uint256 initialToken1Balance = token1.balanceOf(user1);
        uint256 initialToken2Balance = token2.balanceOf(user1);

        uint256 wlpAmount = zap.zapIn(amounts, MIN_AMOUNT, user1);

        assertGt(wlpAmount, 0, "No wLP tokens received");
        assertEq(wlpToken.balanceOf(user1) - initialWlpBalance, wlpAmount, "Incorrect wLP token amount");

        assertEq(token1.balanceOf(user1), initialToken1Balance - amounts[0], "Token1 wasn't properly used");
        assertEq(token2.balanceOf(user1), initialToken2Balance - amounts[1], "Token2 wasn't properly used");

        vm.stopPrank();
    }

    function testZapOut_Proportional() public {
        vm.startPrank(admin);
        token1.mint(admin, ADD_LIQUIDITY_AMOUNT * 10);
        token2.mint(admin, ADD_LIQUIDITY_AMOUNT * 10 / 10 ** 12);
        token1.approve(address(spa), ADD_LIQUIDITY_AMOUNT * 10);
        token2.approve(address(spa), ADD_LIQUIDITY_AMOUNT * 10 / 10 ** 12);

        uint256[] memory initialAmounts = new uint256[](2);
        initialAmounts[0] = ADD_LIQUIDITY_AMOUNT * 10;
        initialAmounts[1] = ADD_LIQUIDITY_AMOUNT * 10 / 10 ** 12;

        uint256 lpAmount = spa.mint(initialAmounts, 1);
        token1.mint(address(spa), ADD_LIQUIDITY_AMOUNT);
        token2.mint(address(spa), ADD_LIQUIDITY_AMOUNT / 10 ** 12);

        lpToken.approve(address(wlpToken), lpAmount / 5);
        uint256 wlpAmount = wlpToken.deposit(lpAmount / 5, user1);
        vm.stopPrank();

        vm.startPrank(user1);

        uint256[] memory minAmountsOut = new uint256[](2);
        minAmountsOut[0] = 1;
        minAmountsOut[1] = 1;

        uint256 initialWlpBalance = wlpToken.balanceOf(user1);
        uint256 initialToken1Balance = token1.balanceOf(user1);
        uint256 initialToken2Balance = token2.balanceOf(user1);

        wlpToken.approve(address(zap), wlpAmount);

        uint256[] memory result = zap.zapOut(wlpAmount, minAmountsOut, user1, true);

        assertGt(result.length, 0, "No results returned");
        assertGt(result[0], 0, "No token1 received");
        assertGt(result[1], 0, "No token2 received");
        assertEq(wlpToken.balanceOf(user1), initialWlpBalance - wlpAmount, "WLP tokens not burned correctly");
        assertEq(token1.balanceOf(user1), initialToken1Balance + result[0], "Token1 not received correctly");
        assertEq(token2.balanceOf(user1), initialToken2Balance + result[1], "Token2 not received correctly");

        vm.stopPrank();
    }

    function testZapOut_Multi() public {
        vm.startPrank(admin);
        token1.mint(admin, ADD_LIQUIDITY_AMOUNT * 15);
        token2.mint(admin, ADD_LIQUIDITY_AMOUNT * 15 / 10 ** 12);
        token1.approve(address(spa), ADD_LIQUIDITY_AMOUNT * 15);
        token2.approve(address(spa), ADD_LIQUIDITY_AMOUNT * 15 / 10 ** 12);

        uint256[] memory initialAmounts = new uint256[](2);
        initialAmounts[0] = ADD_LIQUIDITY_AMOUNT * 15;
        initialAmounts[1] = ADD_LIQUIDITY_AMOUNT * 15 / 10 ** 12;

        uint256 lpAmount = spa.mint(initialAmounts, 1);

        token1.mint(address(spa), ADD_LIQUIDITY_AMOUNT * 2);
        token2.mint(address(spa), ADD_LIQUIDITY_AMOUNT * 2 / 10 ** 12);

        lpToken.approve(address(wlpToken), lpAmount / 3);
        uint256 wlpAmount = wlpToken.deposit(lpAmount / 3, user1);
        vm.stopPrank();

        vm.startPrank(user1);

        uint256[] memory amountsOut = new uint256[](2);
        amountsOut[0] = ADD_LIQUIDITY_AMOUNT / 2;
        amountsOut[1] = ADD_LIQUIDITY_AMOUNT / 4 / 10 ** 12;

        uint256 initialWlpBalance = wlpToken.balanceOf(user1);
        uint256 initialToken1Balance = token1.balanceOf(user1);
        uint256 initialToken2Balance = token2.balanceOf(user1);

        wlpToken.approve(address(zap), wlpAmount);
        wlpToken.approve(address(zap), wlpAmount);

        uint256[] memory result = zap.zapOut(wlpAmount, amountsOut, user1, false);

        assertGt(result.length, 0, "No results returned");
        assertGt(result[0], 0, "No token1 received");
        assertGt(result[1], 0, "No token2 received");

        assertEq(wlpToken.balanceOf(user1), initialWlpBalance - wlpAmount, "WLP tokens not burned correctly");
        assertEq(token1.balanceOf(user1), initialToken1Balance + result[0], "Token1 not received correctly");
        assertEq(token2.balanceOf(user1), initialToken2Balance + result[1], "Token2 not received correctly");

        vm.stopPrank();
    }

    function testZapOutSingle() public {
        vm.startPrank(admin);
        token1.mint(admin, ADD_LIQUIDITY_AMOUNT * 10);
        token2.mint(admin, ADD_LIQUIDITY_AMOUNT * 10 / 10 ** 12);
        token1.approve(address(spa), ADD_LIQUIDITY_AMOUNT * 10);
        token2.approve(address(spa), ADD_LIQUIDITY_AMOUNT * 10 / 10 ** 12);

        uint256[] memory initialAmounts = new uint256[](2);
        initialAmounts[0] = ADD_LIQUIDITY_AMOUNT * 10;
        initialAmounts[1] = ADD_LIQUIDITY_AMOUNT * 10 / 10 ** 12;

        uint256 lpAmount = spa.mint(initialAmounts, 1);

        token1.mint(address(spa), ADD_LIQUIDITY_AMOUNT);
        token2.mint(address(spa), ADD_LIQUIDITY_AMOUNT / 10 ** 12);

        lpToken.approve(address(wlpToken), lpAmount / 10);
        uint256 wlpAmount = wlpToken.deposit(lpAmount / 10, user1);
        vm.stopPrank();

        vm.startPrank(user1);

        uint256 tokenIndex = 0;
        uint256 minAmountOut = 1;

        uint256 initialWlpBalance = wlpToken.balanceOf(user1);
        uint256 initialToken1Balance = token1.balanceOf(user1);

        wlpToken.approve(address(zap), wlpAmount);

        uint256 redeemedAmount = zap.zapOutSingle(wlpAmount, tokenIndex, minAmountOut, user1);

        assertGt(redeemedAmount, 0, "No tokens received from redemption");
        assertEq(wlpToken.balanceOf(user1), initialWlpBalance - wlpAmount, "WLP tokens not burned correctly");
        assertEq(token1.balanceOf(user1), initialToken1Balance + redeemedAmount, "Token1 not received correctly");

        vm.stopPrank();
    }

    function testRecoverERC20() public {
        uint256 recoveryAmount = 100 ether;
        vm.startPrank(user1);
        token1.mint(address(zap), recoveryAmount);
        vm.stopPrank();

        vm.prank(user1);
        vm.expectRevert();
        zap.recoverERC20(address(token1), recoveryAmount, user1);
        vm.startPrank(admin);

        uint256 initialAdminBalance = token1.balanceOf(admin);

        zap.recoverERC20(address(token1), recoveryAmount, admin);

        assertEq(token1.balanceOf(admin), initialAdminBalance + recoveryAmount, "Tokens not recovered correctly");
        vm.stopPrank();
    }
}
