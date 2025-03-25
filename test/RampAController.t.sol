// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../src/periphery/RampAController.sol";
import "../src/interfaces/IRampAController.sol";
import "../src/SelfPeggingAsset.sol";
import "../src/interfaces/ILPToken.sol";
import "../src/LPToken.sol";
import "../src/mock/MockExchangeRateProvider.sol";
import "../src/mock/MockToken.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract RampAControllerTest is Test {
    RampAController public controller;
    SelfPeggingAsset public spa;
    LPToken public lpToken;
    MockExchangeRateProvider[] public providers;

    uint256 public constant INITIAL_A = 200;
    uint256 public constant MIN_RAMP_TIME = 30 minutes;
    address public owner;
    address[] public tokens;
    uint256[] public precisions;
    uint256[] public fees;
    uint256 public offPegFeeMultiplier;

    function setUp() public {
        owner = address(this);
        vm.startPrank(owner);

        MockToken token1 = new MockToken("Token 1", "TK1", 18);
        MockToken token2 = new MockToken("Token 2", "TK2", 18);

        tokens = new address[](2);
        tokens[0] = address(token1);
        tokens[1] = address(token2);

        precisions = new uint256[](2);
        precisions[0] = 1;
        precisions[1] = 1;

        fees = new uint256[](3);
        fees[0] = 1e8; // 0.01%
        fees[1] = 1e8;
        fees[2] = 1e8;

        offPegFeeMultiplier = 5e10; // 5x

        providers = new MockExchangeRateProvider[](2);
        providers[0] = new MockExchangeRateProvider(1e18, 18); // 1:1
        providers[1] = new MockExchangeRateProvider(1e18, 18);

        IExchangeRateProvider[] memory providerArray = new IExchangeRateProvider[](2);
        providerArray[0] = providers[0];
        providerArray[1] = providers[1];

        bytes memory lpTokenData = abi.encodeCall(LPToken.initialize, ("LP Token", "TLP"));
        ERC1967Proxy lpTokenProxy = new ERC1967Proxy(address(new LPToken()), lpTokenData);
        lpToken = LPToken(address(lpTokenProxy));

        bytes memory spaData = abi.encodeCall(
            SelfPeggingAsset.initialize,
            (tokens, precisions, fees, offPegFeeMultiplier, lpToken, INITIAL_A, providerArray)
        );
        ERC1967Proxy spaProxy = new ERC1967Proxy(address(new SelfPeggingAsset()), spaData);
        spa = SelfPeggingAsset(address(spaProxy));

        lpToken.addPool(address(spa));

        controller = new RampAController();
        controller.initialize(address(spa), INITIAL_A, MIN_RAMP_TIME);

        spa.setRampAController(address(controller));

        vm.stopPrank();
    }

    function testInitialValues() public view {
        assertEq(controller.initialA(), INITIAL_A);
        assertEq(controller.futureA(), INITIAL_A);
        assertEq(controller.isRamping(), false);
        assertEq(controller.getA(), INITIAL_A);
    }

    function testRampA() public {
        uint256 newA = 220;
        uint256 endTime = block.timestamp + 1 hours;

        controller.rampA(newA, endTime);
        assertEq(controller.isRamping(), true);
        assertEq(controller.initialA(), INITIAL_A);
        assertEq(controller.futureA(), newA);
        assertEq(controller.getA(), INITIAL_A);

        vm.warp(block.timestamp + 30 minutes);
        uint256 expectedA = INITIAL_A + (newA - INITIAL_A) / 2;
        assertApproxEqAbs(controller.getA(), expectedA, 1);

        vm.warp(endTime);
        assertEq(controller.getA(), newA);
        assertEq(controller.isRamping(), false);
    }

    function testStopRamp() public {
        uint256 newA = 220;
        uint256 endTime = block.timestamp + 1 hours;

        controller.rampA(newA, endTime);

        vm.warp(block.timestamp + 15 minutes);
        uint256 currentA = controller.getA();
        controller.stopRamp();
        assertEq(controller.isRamping(), false);
        assertEq(controller.getA(), currentA);

        vm.warp(block.timestamp + 15 minutes);
        assertEq(controller.getA(), currentA);
    }

    function testRampAValidations() public {
        vm.expectRevert(RampAController.InvalidFutureTime.selector);
        controller.rampA(300, block.timestamp - 1);

        vm.expectRevert(RampAController.AOutOfBounds.selector);
        controller.rampA(0, block.timestamp + 1 hours);

        vm.expectRevert(RampAController.InsufficientRampTime.selector);
        controller.rampA(300, block.timestamp + 1 minutes);

        vm.expectRevert(RampAController.ExcessiveAChange.selector);
        controller.rampA(INITIAL_A * 2, block.timestamp + 1 hours);

        vm.expectRevert(RampAController.ExcessiveAChange.selector);
        controller.rampA(INITIAL_A * 6 / 10, block.timestamp + 1 hours);
    }

    function testSPAIntegration() public {
        assertEq(spa.getCurrentA(), INITIAL_A);

        uint256 newA = 220;
        uint256 endTime = block.timestamp + 1 hours;
        controller.rampA(newA, endTime);

        vm.warp(block.timestamp + 30 minutes);

        uint256 expectedA = INITIAL_A + (newA - INITIAL_A) / 2;
        assertApproxEqAbs(spa.getCurrentA(), expectedA, 1);
    }

    function testMintWithRampingA() public {
        MockToken(tokens[0]).mint(address(this), 1000e18);
        MockToken(tokens[1]).mint(address(this), 1000e18);

        uint256[] memory initialAmounts = new uint256[](2);
        initialAmounts[0] = 100e18;
        initialAmounts[1] = 100e18;

        MockToken(tokens[0]).approve(address(spa), type(uint256).max);
        MockToken(tokens[1]).approve(address(spa), type(uint256).max);

        spa.mint(initialAmounts, 0);

        uint256 initialTotalSupplyValue = spa.totalSupply();

        uint256 newA = 220;
        uint256 endTime = block.timestamp + 1 hours;
        controller.rampA(newA, endTime);

        vm.warp(block.timestamp + 30 minutes);
        uint256[] memory additionalAmounts = new uint256[](2);
        additionalAmounts[0] = 10e18;
        additionalAmounts[1] = 10e18;
        uint256 mintAmount = spa.mint(additionalAmounts, 0);
        uint256 finalTotalSupply = spa.totalSupply();

        assertGe(finalTotalSupply, initialTotalSupplyValue + mintAmount);
    }

    function testRedeemWithRampingA() public {
        MockToken(tokens[0]).mint(address(this), 1000e18);
        MockToken(tokens[1]).mint(address(this), 1000e18);

        uint256[] memory initialAmounts = new uint256[](2);
        initialAmounts[0] = 100e18;
        initialAmounts[1] = 100e18;

        MockToken(tokens[0]).approve(address(spa), type(uint256).max);
        MockToken(tokens[1]).approve(address(spa), type(uint256).max);

        uint256 lpAmount = spa.mint(initialAmounts, 0);
        uint256 newA = 150;
        uint256 endTime = block.timestamp + 1 hours;
        controller.rampA(newA, endTime);

        vm.warp(block.timestamp + 30 minutes);
        uint256[] memory minAmounts = new uint256[](2);
        minAmounts[0] = 0;
        minAmounts[1] = 0;
        lpToken.approve(address(spa), lpAmount / 2);
        spa.redeemProportion(lpAmount / 2, minAmounts);
        uint256 finalTotalSupply = spa.totalSupply();

        assertGe(finalTotalSupply, 0);
    }

    function testSwapWithRampingA() public {
        MockToken(tokens[0]).mint(address(this), 1000e18);
        MockToken(tokens[1]).mint(address(this), 1000e18);

        uint256[] memory initialAmounts = new uint256[](2);
        initialAmounts[0] = 100e18;
        initialAmounts[1] = 100e18;

        MockToken(tokens[0]).approve(address(spa), type(uint256).max);
        MockToken(tokens[1]).approve(address(spa), type(uint256).max);

        spa.mint(initialAmounts, 0);
        uint256 newA = 220;
        uint256 endTime = block.timestamp + 1 hours;
        controller.rampA(newA, endTime);

        vm.warp(block.timestamp + 30 minutes);
        uint256 preSwapTotalSupply = spa.totalSupply();
        uint256 swapAmount = 10e18;
        MockToken(tokens[0]).mint(address(this), swapAmount);
        spa.swap(0, 1, swapAmount, 0);
        uint256 postSwapTotalSupply = spa.totalSupply();

        assertTrue(postSwapTotalSupply != preSwapTotalSupply);
    }

    function testSyncTotalSupplyDuringLargeARampUp() public {
        MockToken(tokens[0]).mint(address(this), 1000e18);
        MockToken(tokens[1]).mint(address(this), 1000e18);

        uint256[] memory initialAmounts = new uint256[](2);
        initialAmounts[0] = 100e18;
        initialAmounts[1] = 100e18;

        MockToken(tokens[0]).approve(address(spa), type(uint256).max);
        MockToken(tokens[1]).approve(address(spa), type(uint256).max);

        spa.mint(initialAmounts, 0);
        uint256 initialTotalSupplyValue = spa.totalSupply();
        uint256 newA = 220;
        uint256 endTime = block.timestamp + 1 hours;
        controller.rampA(newA, endTime);

        vm.warp(endTime);
        uint256[] memory smallAmounts = new uint256[](2);
        smallAmounts[0] = 1e18;
        smallAmounts[1] = 1e18;
        spa.mint(smallAmounts, 0);
        uint256 finalTotalSupply = spa.totalSupply();

        assertGt(finalTotalSupply, initialTotalSupplyValue);
    }

    function testSyncTotalSupplyDuringLargeARampDown() public {
        MockToken(tokens[0]).mint(address(this), 1000e18);
        MockToken(tokens[1]).mint(address(this), 1000e18);

        uint256[] memory initialAmounts = new uint256[](2);
        initialAmounts[0] = 100e18;
        initialAmounts[1] = 100e18;

        MockToken(tokens[0]).approve(address(spa), type(uint256).max);
        MockToken(tokens[1]).approve(address(spa), type(uint256).max);

        spa.mint(initialAmounts, 0);
        uint256 newA = 180;
        uint256 endTime = block.timestamp + 1 hours;
        controller.rampA(newA, endTime);

        vm.warp(endTime);
        uint256 swapAmount = 10e18;
        MockToken(tokens[0]).mint(address(this), swapAmount);
        spa.swap(0, 1, swapAmount, 0);
        uint256 finalTotalSupply = spa.totalSupply();
        assertGt(finalTotalSupply, 0);
    }
}
