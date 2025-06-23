// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import { MockToken } from "../src/mock/MockToken.sol";
import { MaliciousSPA } from "./utils/MaliciousSPA.sol";
import { Zap } from "../src/periphery/Zap.sol";
import { RampAController } from "../src/periphery/RampAController.sol";
import { SelfPeggingAsset } from "../src/SelfPeggingAsset.sol";
import { WSPAToken } from "../src/WSPAToken.sol";
import { ConstantExchangeRateProvider } from "../src/misc/ConstantExchangeRateProvider.sol";
import { IExchangeRateProvider } from "../src/interfaces/IExchangeRateProvider.sol";
import { SPAToken } from "../src/SPAToken.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ZapTest is Test {
    using Math for uint256;

    Zap public zap;
    SelfPeggingAsset public spa;
    MaliciousSPA public maliciousSPA;
    SPAToken public spaToken;
    WSPAToken public wspaToken;
    RampAController public rampAController;

    address public governance;
    address public admin;
    address public user1;
    address public user2;
    address public targetToken;

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

        ERC1967Proxy proxy = new ERC1967Proxy(address(new SPAToken()), new bytes(0));

        spaToken = SPAToken(address(proxy));

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

        bytes memory data = abi.encodeCall(RampAController.initialize, (100, 30 minutes, governance));
        proxy = new ERC1967Proxy(address(new RampAController()), data);
        rampAController = RampAController(address(proxy));

        data = abi.encodeWithSelector(
            SelfPeggingAsset.initialize.selector,
            tokens,
            precisions,
            fees,
            0,
            spaToken,
            100,
            providers,
            address(rampAController)
        );
        proxy = new ERC1967Proxy(address(new SelfPeggingAsset()), data);

        spa = SelfPeggingAsset(address(proxy));
        spaToken.initialize("Tapio ETH", "TapETH", 5e8, governance, address(spa));

        vm.stopPrank();

        vm.startPrank(admin);

        data = abi.encodeCall(WSPAToken.initialize, (spaToken));
        proxy = new ERC1967Proxy(address(new WSPAToken()), data);

        wspaToken = WSPAToken(address(proxy));

        zap = new Zap();
        targetToken = address(token1);
        maliciousSPA = new MaliciousSPA(targetToken, tokens);

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

        uint256 initialWlpBalance = wspaToken.balanceOf(user1);
        uint256 initialToken1Balance = token1.balanceOf(user1);
        uint256 initialToken2Balance = token2.balanceOf(user1);

        uint256 wlpAmount = zap.zapIn(address(spa), address(wspaToken), user1, MIN_AMOUNT, amounts);

        assertGt(wlpAmount, 0, "No wLP tokens received");
        assertEq(wspaToken.balanceOf(user1) - initialWlpBalance, wlpAmount, "Incorrect wSPA token amount");

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

        spaToken.approve(address(wspaToken), lpAmount / 5);
        uint256 wlpAmount = wspaToken.deposit(lpAmount / 5, user1);
        vm.stopPrank();

        vm.startPrank(user1);

        uint256[] memory minAmountsOut = new uint256[](2);
        minAmountsOut[0] = 1;
        minAmountsOut[1] = 1;

        uint256 initialWlpBalance = wspaToken.balanceOf(user1);
        uint256 initialToken1Balance = token1.balanceOf(user1);
        uint256 initialToken2Balance = token2.balanceOf(user1);

        wspaToken.approve(address(zap), wlpAmount);

        uint256[] memory result = zap.zapOut(address(spa), address(wspaToken), user1, wlpAmount, minAmountsOut, true);

        assertGt(result.length, 0, "No results returned");
        assertGt(result[0], 0, "No token1 received");
        assertGt(result[1], 0, "No token2 received");
        assertEq(wspaToken.balanceOf(user1), initialWlpBalance - wlpAmount, "WLP tokens not burned correctly");
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

        spaToken.approve(address(wspaToken), lpAmount / 3);
        uint256 wlpAmount = wspaToken.deposit(lpAmount / 3, user1);
        vm.stopPrank();

        vm.startPrank(user1);

        uint256[] memory amountsOut = new uint256[](2);
        amountsOut[0] = ADD_LIQUIDITY_AMOUNT / 2;
        amountsOut[1] = ADD_LIQUIDITY_AMOUNT / 4 / 10 ** 12;

        uint256 initialWlpBalance = wspaToken.balanceOf(user1);
        uint256 initialToken1Balance = token1.balanceOf(user1);
        uint256 initialToken2Balance = token2.balanceOf(user1);

        wspaToken.approve(address(zap), wlpAmount);

        uint256[] memory result = zap.zapOut(address(spa), address(wspaToken), user1, wlpAmount, amountsOut, false);

        assertGt(result.length, 0, "No results returned");
        assertGt(result[0], 0, "No token1 received");
        assertGt(result[1], 0, "No token2 received");

        assertEq(wspaToken.balanceOf(user1), initialWlpBalance - wlpAmount, "WSPA tokens not burned correctly");
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

        spaToken.approve(address(wspaToken), lpAmount / 10);
        uint256 wlpAmount = wspaToken.deposit(lpAmount / 10, user1);
        vm.stopPrank();

        vm.startPrank(user1);

        uint256 tokenIndex = 0;
        uint256 minAmountOut = 1;

        uint256 initialWlpBalance = wspaToken.balanceOf(user1);
        uint256 initialToken1Balance = token1.balanceOf(user1);

        wspaToken.approve(address(zap), wlpAmount);

        uint256 redeemedAmount =
            zap.zapOutSingle(address(spa), address(wspaToken), user1, wlpAmount, tokenIndex, minAmountOut);

        assertGt(redeemedAmount, 0, "No tokens received from redemption");
        assertEq(wspaToken.balanceOf(user1), initialWlpBalance - wlpAmount, "WSPA tokens not burned correctly");
        assertEq(token1.balanceOf(user1), initialToken1Balance + redeemedAmount, "Token1 not received correctly");

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
        zap.zapIn(address(0), address(wspaToken), user1, MIN_AMOUNT, amounts);

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

        vm.expectRevert(abi.encodeWithSignature("CallFailed()"));
        zap.zapIn(address(wspaToken), address(wspaToken), user1, MIN_AMOUNT, amounts);

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

        vm.expectRevert(abi.encodeWithSignature("CallFailed()"));
        zap.zapIn(address(spa), address(token1), user1, MIN_AMOUNT, amounts);

        vm.stopPrank();
    }

    function testZapIn_CrossPoolMismatch() public {
        ERC1967Proxy proxy = new ERC1967Proxy(address(new SPAToken()), new bytes(0));
        SPAToken secondSPAToken = SPAToken(address(proxy));

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

        bytes memory data = abi.encodeCall(RampAController.initialize, (100, 30 minutes, governance));
        proxy = new ERC1967Proxy(address(new RampAController()), data);
        RampAController secondRampAController = RampAController(address(proxy));

        data = abi.encodeWithSelector(
            SelfPeggingAsset.initialize.selector,
            tokens,
            precisions,
            fees,
            0,
            secondSPAToken,
            100,
            providers,
            address(secondRampAController)
        );
        proxy = new ERC1967Proxy(address(new SelfPeggingAsset()), data);
        SelfPeggingAsset secondSpa = SelfPeggingAsset(address(proxy));
        secondSPAToken.initialize("Second LP Token", "LP2", 5e8, governance, address(secondSpa));

        vm.stopPrank();
        vm.startPrank(admin);

        data = abi.encodeCall(WSPAToken.initialize, (secondSPAToken));
        proxy = new ERC1967Proxy(address(new WSPAToken()), data);
        WSPAToken secondWSPAToken = WSPAToken(address(proxy));

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

        vm.expectRevert(abi.encodeWithSignature("InsufficientAllowance(uint256,uint256)", 0, 2e22));
        zap.zapIn(address(spa), address(secondWSPAToken), user1, MIN_AMOUNT, amounts);

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

        spaToken.approve(address(wspaToken), lpAmount / 5);
        uint256 wlpAmount = wspaToken.deposit(lpAmount / 5, user1);
        vm.stopPrank();

        vm.startPrank(user1);

        uint256[] memory minAmountsOut = new uint256[](2);
        minAmountsOut[0] = 1;
        minAmountsOut[1] = 1;

        wspaToken.approve(address(zap), wlpAmount);

        vm.expectRevert(Zap.ZeroAmount.selector);
        zap.zapOut(address(spa), address(wspaToken), user1, 0, minAmountsOut, true);

        uint256[] memory wrongAmountsOut = new uint256[](1);
        wrongAmountsOut[0] = 1;

        vm.expectRevert(Zap.InvalidParameters.selector);
        zap.zapOut(address(spa), address(wspaToken), user1, wlpAmount, wrongAmountsOut, true);

        vm.stopPrank();
    }

    function testZapInApprovalExploit() public {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e18;
        amounts[1] = 100e18;

        address attacker = makeAddr("attacker");

        deal(address(token1), attacker, amounts[0]);
        deal(address(token2), attacker, amounts[1]);

        deal(targetToken, attacker, amounts[0]);

        vm.startPrank(attacker);
        MockToken(targetToken).approve(address(zap), type(uint256).max);
        MockToken(token1).approve(address(zap), type(uint256).max);
        MockToken(token2).approve(address(zap), type(uint256).max);
        zap.zapIn(address(maliciousSPA), address(maliciousSPA), attacker, 0, amounts);
        vm.stopPrank();

        assertEq(
            MockToken(targetToken).allowance(address(zap), address(maliciousSPA)),
            0,
            "Exploit successful: Zap contract approved attacker for target token"
        );
    }
}
