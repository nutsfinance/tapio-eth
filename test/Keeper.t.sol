// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Vm } from "forge-std/Vm.sol";
import { Test, console2 } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { SelfPeggingAssetFactory } from "../src/SelfPeggingAssetFactory.sol";
import { MockToken } from "../src/mock/MockToken.sol";
import { SelfPeggingAsset } from "../src/SelfPeggingAsset.sol";
import { LPToken } from "../src/LPToken.sol";
import { WLPToken } from "../src/WLPToken.sol";
import { ParameterRegistry, IParameterRegistry } from "../src/periphery/ParameterRegistry.sol";
import { Keeper } from "../src/periphery/Keeper.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "../src/misc/ConstantExchangeRateProvider.sol";
import "../src/mock/MockExchangeRateProvider.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { RampAController } from "../src/periphery/RampAController.sol";

contract KeeperFuzzTest is Test {
    // Define test accounts
    address governor = address(1);
    address curator = address(2);
    address guardian = address(3);
    address owner = address(4);

    SelfPeggingAssetFactory factory;

    // Contracts
    ParameterRegistry parameterRegistry;
    RampAController rampAController;
    SelfPeggingAsset spa;
    LPToken lpToken;
    WLPToken wlpToken;
    Keeper keeper;

    uint256 constant DENOMINATOR = 1e10;

    function setUp() public {
        MockToken tokenA = new MockToken("test 1", "T1", 18);
        MockToken tokenB = new MockToken("test 2", "T2", 18);

        address selfPeggingAssetImplentation = address(new SelfPeggingAsset());
        address lpTokenImplentation = address(new LPToken());
        address wlpTokenImplentation = address(new WLPToken());
        address rampAControllerImplentation = address(new RampAController());
        address keeperImplementation = address(new Keeper());
        UpgradeableBeacon beacon = new UpgradeableBeacon(selfPeggingAssetImplentation, governor);
        address selfPeggingAssetBeacon = address(beacon);

        beacon = new UpgradeableBeacon(lpTokenImplentation, governor);
        address lpTokenBeacon = address(beacon);

        beacon = new UpgradeableBeacon(wlpTokenImplentation, governor);
        address wlpTokenBeacon = address(beacon);

        beacon = new UpgradeableBeacon(rampAControllerImplentation, governor);
        address rampAControllerBeacon = address(beacon);

        bytes memory data = abi.encodeCall(
            SelfPeggingAssetFactory.initialize,
            (
                owner,
                governor,
                0,
                0,
                0,
                0,
                100,
                30 minutes,
                selfPeggingAssetBeacon,
                lpTokenBeacon,
                wlpTokenBeacon,
                rampAControllerBeacon,
                keeperImplementation,
                address(new ConstantExchangeRateProvider()),
                0,
                0
            )
        );

        SelfPeggingAssetFactory.CreatePoolArgument memory arg = SelfPeggingAssetFactory.CreatePoolArgument({
            tokenA: address(tokenA),
            tokenB: address(tokenB),
            tokenAType: SelfPeggingAssetFactory.TokenType.Standard,
            tokenAOracle: address(0),
            tokenARateFunctionSig: new bytes(0),
            tokenADecimalsFunctionSig: new bytes(0),
            tokenBType: SelfPeggingAssetFactory.TokenType.Standard,
            tokenBOracle: address(0),
            tokenBRateFunctionSig: new bytes(0),
            tokenBDecimalsFunctionSig: new bytes(0)
        });

        vm.startPrank(owner);

        ERC1967Proxy proxy = new ERC1967Proxy(address(new SelfPeggingAssetFactory()), data);
        factory = SelfPeggingAssetFactory(address(proxy));

        (wlpToken, keeper, parameterRegistry) = factory.createPool(arg);

        lpToken = LPToken(wlpToken.asset());
        spa = SelfPeggingAsset(lpToken.pool());
        rampAController = RampAController(address(spa.rampAController()));

        keeper.grantRole(keeper.GOVERNOR_ROLE(), governor);
        vm.stopPrank();
        vm.startPrank(governor);

        keeper.grantRole(keeper.CURATOR_ROLE(), governor);
        keeper.grantRole(keeper.GUARDIAN_ROLE(), governor);
        vm.stopPrank();
    }

    function testParamFuzz(
        uint8 paramType,
        uint256 min,
        uint256 max,
        uint64 maxDecreasePct,
        uint64 maxIncreasePct,
        uint256 oldValue,
        uint256 newValue
    )
        public
    {
        paramType = uint8(bound(paramType, 0, 11));

        IParameterRegistry.ParamKey paramKey = getParamKey(paramType);
        // inputs based on parameter type
        if (paramType == 0 || paramType == 1 || paramType == 2 || paramType == 5) {
            vm.assume(oldValue < DENOMINATOR);
            vm.assume(newValue < DENOMINATOR);
            vm.assume(max <= DENOMINATOR);
            vm.assume(min <= max);
        } else if (paramType == 3) {
            oldValue = bound(oldValue, DENOMINATOR, 1e18);
            newValue = bound(newValue, DENOMINATOR, 1e18);
            max = bound(max, DENOMINATOR, 1e18);
            min = bound(min, DENOMINATOR, max);
        } else if (paramType == 4) {
            vm.assume(oldValue <= 1e18);
            vm.assume(newValue <= 1e18);
            vm.assume(max <= 1e18);
            vm.assume(min <= max);
        } else if (paramType == 6 || paramType == 7 || paramType == 11) {
            vm.assume(oldValue <= 365 days);
            vm.assume(newValue <= 365 days);
            vm.assume(max <= 365 days);
            min = bound(min, 0, max);
        } else if (paramType == 8 || paramType == 9) {
            vm.assume(oldValue <= 1_000_000_000e18); //1 billion margin
            vm.assume(newValue <= 1_000_000_000e18); //1 billion margin
            vm.assume(max <= type(uint256).max);
            min = bound(min, 0, max);
        } else if (paramType == 10) {
            uint256 curretnA = rampAController.getA();
            oldValue = bound(oldValue, curretnA / 10, curretnA * 10); // defult -90% and +900% is allowed
            newValue = bound(newValue, 1, 1e6);
            vm.assume(max <= 1e6);
            vm.assume(min <= max);
        }
        if (paramType == 10) {
            maxDecreasePct = uint64(bound(maxDecreasePct, 1, type(uint64).max));
            maxIncreasePct = uint64(bound(maxIncreasePct, 1, type(uint64).max));
        } else {
            vm.assume(maxDecreasePct <= DENOMINATOR);
            vm.assume(maxIncreasePct <= DENOMINATOR);
        }

        checkParameterBounds(paramType, paramKey, min, max, maxDecreasePct, maxIncreasePct, oldValue, newValue);
    }

    // function to check parameter bounds
    function checkParameterBounds(
        uint8 paramType,
        IParameterRegistry.ParamKey paramKey,
        uint256 min,
        uint256 max,
        uint64 maxDecreasePct,
        uint64 maxIncreasePct,
        uint256 oldValue,
        uint256 newValue
    )
        internal
    {
        vm.startPrank(governor);
        // Set boundaries
        IParameterRegistry.Bounds memory bounds = IParameterRegistry.Bounds({
            min: min,
            max: max,
            maxDecreasePct: maxDecreasePct,
            maxIncreasePct: maxIncreasePct
        });

        // Initial Value
        setValue(paramType, oldValue);
        parameterRegistry.setBounds(paramKey, bounds);

        // Get current value
        uint256 currentValue = getCurrentValue(paramType);
        assertEq(currentValue, oldValue, "Values did not set");

        // logic for A when curA <= 2
        bool allowed;
        if (paramType == 10 && currentValue <= 2) {
            uint256 maxMultiplier = 11 - currentValue;
            allowed = newValue <= currentValue * maxMultiplier;
        } else {
            bool inAbsoluteBounds = (min == 0 || newValue >= min) && (max == 0 || newValue <= max);

            bool inRelativeBounds = true;
            if (currentValue != 0 && (maxDecreasePct != 0 || maxIncreasePct != 0)) {
                if (newValue < currentValue) {
                    uint256 decreasePct = ((currentValue - newValue) * DENOMINATOR) / currentValue;
                    inRelativeBounds = decreasePct <= maxDecreasePct;
                } else if (newValue > currentValue) {
                    uint256 increasePct = ((newValue - currentValue) * DENOMINATOR) / currentValue;
                    inRelativeBounds = increasePct <= maxIncreasePct;
                }
            }
            allowed = inAbsoluteBounds && inRelativeBounds;
        }
        if (paramType == 10) {
            uint256 endTime = block.timestamp + 2 hours;
            if (allowed) {
                keeper.rampA(newValue, endTime);
            } else {
                vm.expectRevert();
                keeper.rampA(newValue, endTime);
            }
        } else {
            if (allowed) {
                setValue(paramType, newValue);
                assertEq(getCurrentValue(paramType), newValue, "Parameter should be updated to newValue");
            } else {
                vm.expectRevert();
                setValue(paramType, newValue);
            }
        }
        vm.stopPrank();
    }

    // Helper to get parameter key
    function getParamKey(uint8 paramType) internal pure returns (IParameterRegistry.ParamKey) {
        if (paramType == 0) return IParameterRegistry.ParamKey.SwapFee;
        if (paramType == 1) return IParameterRegistry.ParamKey.MintFee;
        if (paramType == 2) return IParameterRegistry.ParamKey.RedeemFee;
        if (paramType == 3) return IParameterRegistry.ParamKey.OffPeg;
        if (paramType == 4) return IParameterRegistry.ParamKey.ExchangeRateFee;
        if (paramType == 5) return IParameterRegistry.ParamKey.BufferPercent;
        if (paramType == 6) return IParameterRegistry.ParamKey.DecayPeriod;
        if (paramType == 7) return IParameterRegistry.ParamKey.RateChangeSkipPeriod;
        if (paramType == 8) return IParameterRegistry.ParamKey.FeeErrorMargin;
        if (paramType == 9) return IParameterRegistry.ParamKey.YieldErrorMargin;
        if (paramType == 10) return IParameterRegistry.ParamKey.A;
        if (paramType == 11) return IParameterRegistry.ParamKey.MinRampTime;
        revert("Invalid ParamType");
    }

    // Helper to set a value
    function setValue(uint8 paramType, uint256 value) internal {
        if (paramType == 0) {
            keeper.setSwapFee(value);
        } else if (paramType == 1) {
            keeper.setMintFee(value);
        } else if (paramType == 2) {
            keeper.setRedeemFee(value);
        } else if (paramType == 3) {
            keeper.setOffPegFeeMultiplier(value);
        } else if (paramType == 4) {
            keeper.setExchangeRateFeeFactor(value);
        } else if (paramType == 5) {
            keeper.setBufferPercent(value);
        } else if (paramType == 6) {
            keeper.setDecayPeriod(value);
        } else if (paramType == 7) {
            keeper.setRateChangeSkipPeriod(value);
        } else if (paramType == 8) {
            keeper.updateFeeErrorMargin(value);
        } else if (paramType == 9) {
            keeper.updateYieldErrorMargin(value);
        } else if (paramType == 10) {
            keeper.rampA(value, block.timestamp + 30 minutes);
            skip(1 hours);
        } else if (paramType == 11) {
            keeper.setMinRampTime(value);
        }
    }

    // Helper to get current value
    function getCurrentValue(uint8 paramType) internal view returns (uint256) {
        if (paramType == 0) return spa.swapFee();
        if (paramType == 1) return spa.mintFee();
        if (paramType == 2) return spa.redeemFee();
        if (paramType == 3) return spa.offPegFeeMultiplier();
        if (paramType == 4) return spa.exchangeRateFeeFactor();
        if (paramType == 5) return lpToken.bufferPercent();
        if (paramType == 6) return spa.decayPeriod();
        if (paramType == 7) return spa.rateChangeSkipPeriod();
        if (paramType == 8) return spa.feeErrorMargin();
        if (paramType == 9) return spa.yieldErrorMargin();
        if (paramType == 10) return rampAController.getA();
        if (paramType == 11) return rampAController.minRampTime();
        revert("Invalid ParamType");
    }
}
