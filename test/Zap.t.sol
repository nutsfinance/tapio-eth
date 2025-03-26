// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import { MockToken } from "../src/mock/MockToken.sol";
import { Zap } from "../src/periphery/Zap.sol";
import { RampAController } from "../src/periphery/RampAController.sol";
import { SelfPeggingAsset } from "../src/SelfPeggingAsset.sol";
import { WLPToken } from "../src/WLPToken.sol";
import { ConstantExchangeRateProvider } from "../src/misc/ConstantExchangeRateProvider.sol";
import { IExchangeRateProvider } from "../src/interfaces/IExchangeRateProvider.sol";
import { LPToken } from "../src/LPToken.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ZapTest is Test {
    using Math for uint256;

    Zap public zap;
    SelfPeggingAsset public spa;
    LPToken public lpToken;
    WLPToken public wlpToken;
    RampAController public rampAController;

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

        bytes memory data = abi.encodeCall(LPToken.initialize, ("Tapio ETH", "TapETH"));
        ERC1967Proxy proxy = new ERC1967Proxy(address(new LPToken()), data);

        lpToken = LPToken(address(proxy));
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

        data = abi.encodeCall(RampAController.initialize, (100, 30 minutes));
        proxy = new ERC1967Proxy(address(new RampAController()), data);
        rampAController = RampAController(address(proxy));

        data = abi.encodeWithSelector(
            SelfPeggingAsset.initialize.selector,
            tokens,
            precisions,
            fees,
            0,
            lpToken,
            100,
            providers,
            address(rampAController)
        );
        proxy = new ERC1967Proxy(address(new SelfPeggingAsset()), data);

        spa = SelfPeggingAsset(address(proxy));

        vm.stopPrank();

        vm.prank(governance);
        lpToken.addPool(address(spa));

        vm.startPrank(admin);

        data = abi.encodeCall(WLPToken.initialize, (lpToken));
        proxy = new ERC1967Proxy(address(new WLPToken()), data);

        wlpToken = WLPToken(address(proxy));

        zap = new Zap();

        token1.mint(user1, INITIAL_BALANCE);
        token2.mint(user1, INITIAL_BALANCE);
        token1.mint(user2, INITIAL_BALANCE);
        token2.mint(user2, INITIAL_BALANCE);

        vm.stopPrank();
    }

    function testInitialize() public view {
        // No state variables to check in the new design
        // Contract exists and can be called with dynamic parameters
        assert(address(zap) != address(0));
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

        uint256 wlpAmount = zap.zapIn(address(spa), address(wlpToken), user1, MIN_AMOUNT, amounts);

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

        uint256[] memory result = zap.zapOut(address(spa), address(wlpToken), user1, wlpAmount, minAmountsOut, true);

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

        uint256[] memory result = zap.zapOut(address(spa), address(wlpToken), user1, wlpAmount, amountsOut, false);

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

        uint256 redeemedAmount =
            zap.zapOutSingle(address(spa), address(wlpToken), user1, wlpAmount, tokenIndex, minAmountOut);

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

    function testZapIn_ZeroSpaAddress() public {
        token1.mint(user1, ADD_LIQUIDITY_AMOUNT);
        token2.mint(user1, ADD_LIQUIDITY_AMOUNT / 10 ** 12);

        vm.startPrank(user1);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = ADD_LIQUIDITY_AMOUNT;
        amounts[1] = ADD_LIQUIDITY_AMOUNT / 10 ** 12;

        token1.approve(address(zap), amounts[0]);
        token2.approve(address(zap), amounts[1]);

        vm.expectRevert(Zap.InvalidParameters.selector);
        zap.zapIn(address(0), address(wlpToken), user1, MIN_AMOUNT, amounts);

        vm.stopPrank();
    }

    function testZapIn_ZeroWlpAddress() public {
        token1.mint(user1, ADD_LIQUIDITY_AMOUNT);
        token2.mint(user1, ADD_LIQUIDITY_AMOUNT / 10 ** 12);

        vm.startPrank(user1);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = ADD_LIQUIDITY_AMOUNT;
        amounts[1] = ADD_LIQUIDITY_AMOUNT / 10 ** 12;

        token1.approve(address(zap), amounts[0]);
        token2.approve(address(zap), amounts[1]);

        vm.expectRevert(Zap.InvalidParameters.selector);
        zap.zapIn(address(spa), address(0), user1, MIN_AMOUNT, amounts);

        vm.stopPrank();
    }

    function testZapIn_IncorrectSpaAddress() public {
        token1.mint(user1, ADD_LIQUIDITY_AMOUNT);
        token2.mint(user1, ADD_LIQUIDITY_AMOUNT / 10 ** 12);

        vm.startPrank(user1);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = ADD_LIQUIDITY_AMOUNT;
        amounts[1] = ADD_LIQUIDITY_AMOUNT / 10 ** 12;

        token1.approve(address(zap), amounts[0]);
        token2.approve(address(zap), amounts[1]);

        vm.expectRevert();
        zap.zapIn(address(wlpToken), address(wlpToken), user1, MIN_AMOUNT, amounts);

        vm.stopPrank();
    }

    function testZapIn_CorrectSpaIncorrectWlp() public {
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

        vm.expectRevert();
        zap.zapIn(address(spa), address(token1), user1, MIN_AMOUNT, amounts);

        vm.stopPrank();
    }

    function testZapIn_CrossPoolMismatch() public {
        bytes memory data = abi.encodeCall(LPToken.initialize, ("Second LP Token", "LP2"));
        ERC1967Proxy proxy = new ERC1967Proxy(address(new LPToken()), data);
        LPToken secondLpToken = LPToken(address(proxy));
        secondLpToken.transferOwnership(governance);

        vm.startPrank(admin);

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

        data = abi.encodeCall(RampAController.initialize, (100, 30 minutes));
        proxy = new ERC1967Proxy(address(new RampAController()), data);
        RampAController secondRampAController = RampAController(address(proxy));

        data = abi.encodeWithSelector(
            SelfPeggingAsset.initialize.selector, tokens, precisions, fees, 0, secondLpToken, 100, providers, address(secondRampAController)
        );
        proxy = new ERC1967Proxy(address(new SelfPeggingAsset()), data);
        SelfPeggingAsset secondSpa = SelfPeggingAsset(address(proxy));

        vm.stopPrank();

        vm.prank(governance);
        secondLpToken.addPool(address(secondSpa));

        vm.startPrank(admin);

        data = abi.encodeCall(WLPToken.initialize, (secondLpToken));
        proxy = new ERC1967Proxy(address(new WLPToken()), data);
        WLPToken secondWlpToken = WLPToken(address(proxy));

        token1.mint(admin, ADD_LIQUIDITY_AMOUNT * 4);
        token2.mint(admin, ADD_LIQUIDITY_AMOUNT * 4 / 10 ** 12);
        vm.stopPrank();

        token1.mint(user1, ADD_LIQUIDITY_AMOUNT);
        token2.mint(user1, ADD_LIQUIDITY_AMOUNT / 10 ** 12);

        vm.startPrank(admin);
        uint256 firstPoolAmount = ADD_LIQUIDITY_AMOUNT;
        token1.approve(address(spa), firstPoolAmount);
        token2.approve(address(spa), firstPoolAmount / 10 ** 12);

        uint256[] memory initialAmountsFirstPool = new uint256[](2);
        initialAmountsFirstPool[0] = firstPoolAmount;
        initialAmountsFirstPool[1] = firstPoolAmount / 10 ** 12;

        spa.mint(initialAmountsFirstPool, 1);
        vm.stopPrank();

        vm.startPrank(admin);
        uint256 secondPoolAmount = ADD_LIQUIDITY_AMOUNT;
        token1.approve(address(secondSpa), secondPoolAmount);
        token2.approve(address(secondSpa), secondPoolAmount / 10 ** 12);

        uint256[] memory initialAmountsSecondPool = new uint256[](2);
        initialAmountsSecondPool[0] = secondPoolAmount;
        initialAmountsSecondPool[1] = secondPoolAmount / 10 ** 12;

        secondSpa.mint(initialAmountsSecondPool, 1);
        vm.stopPrank();

        vm.startPrank(user1);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = ADD_LIQUIDITY_AMOUNT;
        amounts[1] = ADD_LIQUIDITY_AMOUNT / 10 ** 12;

        token1.approve(address(zap), amounts[0]);
        token2.approve(address(zap), amounts[1]);

        vm.expectRevert();
        zap.zapIn(address(spa), address(secondWlpToken), user1, MIN_AMOUNT, amounts);

        vm.stopPrank();
    }

    function testZapOut_InvalidParameters() public {
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

        wlpToken.approve(address(zap), wlpAmount);

        vm.expectRevert(Zap.ZeroAmount.selector);
        zap.zapOut(address(spa), address(wlpToken), user1, 0, minAmountsOut, true);

        uint256[] memory wrongAmountsOut = new uint256[](1);
        wrongAmountsOut[0] = 1;

        vm.expectRevert(Zap.InvalidParameters.selector);
        zap.zapOut(address(spa), address(wlpToken), user1, wlpAmount, wrongAmountsOut, true);

        vm.stopPrank();
    }
}
