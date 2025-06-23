// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { console } from "forge-std/console.sol";

import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { SelfPeggingAssetFactory } from "../src/SelfPeggingAssetFactory.sol";
import { MockToken } from "../src/mock/MockToken.sol";
import { SelfPeggingAsset } from "../src/SelfPeggingAsset.sol";
import { SPAToken } from "../src/SPAToken.sol";
import { WSPAToken } from "../src/WSPAToken.sol";
import { RampAController } from "../src/periphery/RampAController.sol";
import { Keeper } from "../src/periphery/Keeper.sol";
import { ParameterRegistry } from "../src/periphery/ParameterRegistry.sol";
import { IParameterRegistry } from "../src/interfaces/IParameterRegistry.sol";
import { ConstantExchangeRateProvider } from "../src/misc/ConstantExchangeRateProvider.sol";

/*
 * 1. Correct role assignment on pool creation via factory
 * 2. AC on keeper + parameter registry
 * 3. Permission transfer flow (pause / unpause)
 * 4. Upgradeability (UUPS + Beacon)
 */
contract GovernanceTest is Test {
    address internal protocolOwner = address(0xA0); // Protocol and beacon owner
    address internal governor = address(0xB0);
    address internal curator = address(0xC0);
    address internal guardian = address(0xD0);

    SelfPeggingAssetFactory internal factory;
    SelfPeggingAsset internal spa;
    SPAToken internal spaToken;
    WSPAToken internal wspaToken;
    RampAController internal rampAController;
    Keeper internal keeper;
    ParameterRegistry internal parameterRegistry;
    UpgradeableBeacon internal spaBeacon;
    MockToken tokenA;
    MockToken tokenB;

    function setUp() public {
        tokenA = new MockToken("test 1", "T1", 18);
        tokenB = new MockToken("test 2", "T2", 18);

        address selfPeggingAssetImplentation = address(new SelfPeggingAsset());
        address spaTokenImplentation = address(new SPAToken());
        address wspaTokenImplentation = address(new WSPAToken());
        address rampAControllerImplentation = address(new RampAController());
        address keeperImplementation = address(new Keeper());
        UpgradeableBeacon beacon = new UpgradeableBeacon(selfPeggingAssetImplentation, protocolOwner);
        spaBeacon = beacon;
        address selfPeggingAssetBeacon = address(beacon);

        beacon = new UpgradeableBeacon(spaTokenImplentation, governor);
        address spaTokenBeacon = address(beacon);

        beacon = new UpgradeableBeacon(wspaTokenImplentation, governor);
        address wspaTokenBeacon = address(beacon);

        beacon = new UpgradeableBeacon(rampAControllerImplentation, governor);
        address rampAControllerBeacon = address(beacon);

        SelfPeggingAssetFactory.InitializeArgument memory args = SelfPeggingAssetFactory.InitializeArgument(
            protocolOwner,
            governor,
            0,
            0,
            0,
            0,
            100,
            30 minutes,
            selfPeggingAssetBeacon,
            spaTokenBeacon,
            wspaTokenBeacon,
            rampAControllerBeacon,
            keeperImplementation,
            address(new ConstantExchangeRateProvider()),
            0,
            0
        );

        bytes memory data = abi.encodeCall(SelfPeggingAssetFactory.initialize, args);

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

        vm.startPrank(protocolOwner);

        ERC1967Proxy proxy = new ERC1967Proxy(address(new SelfPeggingAssetFactory()), data);
        factory = SelfPeggingAssetFactory(address(proxy));

        (wspaToken, keeper, parameterRegistry) = factory.createPool(arg);

        spaToken = SPAToken(wspaToken.asset());
        spa = SelfPeggingAsset(spaToken.pool());
        rampAController = RampAController(address(spa.rampAController()));

        keeper.grantRole(keeper.GOVERNOR_ROLE(), governor);
        vm.stopPrank();

        // set up roles
        vm.startPrank(governor);
        keeper.grantRole(keeper.CURATOR_ROLE(), curator);
        keeper.grantRole(keeper.GUARDIAN_ROLE(), guardian);
        keeper.revokeRole(keeper.CURATOR_ROLE(), governor);
        vm.stopPrank();
    }

    function _decodePoolCreatedEvent(Vm.Log[] memory entries)
        internal
        pure
        returns (address, address, address, address, address, address)
    {
        bytes32 sig = keccak256("PoolCreated(address,address,address,address,address,address)");
        for (uint256 i; i < entries.length; i++) {
            if (entries[i].topics[0] == sig) {
                return abi.decode(entries[i].data, (address, address, address, address, address, address));
            }
        }
        revert("event not found");
    }

    function test_roleAssignmentOnCreation() external view {
        assertTrue(keeper.hasRole(keeper.PROTOCOL_OWNER_ROLE(), protocolOwner));
        assertTrue(keeper.hasRole(keeper.GOVERNOR_ROLE(), governor));
        assertTrue(keeper.hasRole(keeper.CURATOR_ROLE(), curator));
        assertTrue(keeper.hasRole(keeper.GUARDIAN_ROLE(), guardian));
        assertFalse(keeper.hasRole(keeper.CURATOR_ROLE(), governor));
        assertEq(keeper.getRoleAdmin(keeper.CURATOR_ROLE()), keeper.GOVERNOR_ROLE());
        assertEq(keeper.getRoleAdmin(keeper.GUARDIAN_ROLE()), keeper.GOVERNOR_ROLE());
        assertEq(keeper.getRoleAdmin(keeper.GOVERNOR_ROLE()), keeper.PROTOCOL_OWNER_ROLE());
    }

    function test_onlyCurator_canRampA() external {
        uint256 newA = 110;
        uint256 endTime = block.timestamp + 1 days;

        bytes32 curatorRole = keeper.CURATOR_ROLE();
        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", governor, curatorRole)
        );
        vm.prank(governor);
        keeper.rampA(newA, endTime);

        vm.prank(curator);
        keeper.rampA(newA, endTime);
    }

    function test_onlyGovernor_canSetTreasury() external {
        bytes32 governorRole = keeper.GOVERNOR_ROLE();
        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", curator, governorRole)
        );
        vm.prank(curator);
        keeper.setTreasury(curator);

        vm.prank(governor);
        keeper.setTreasury(curator);
    }

    function test_onlyGovernor_canWithdrawAdminFee() external {
        _createBuffer(100e18);

        bytes32 governorRole = keeper.GOVERNOR_ROLE();
        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", curator, governorRole)
        );
        vm.prank(curator);
        keeper.withdrawAdminFee(10e18);

        vm.prank(governor);
        keeper.withdrawAdminFee(10e18);
    }

    function test_onlyGovernor_canSetSwapFee() external {
        uint256 newFee = 1e7;

        bytes32 governorRole = keeper.GOVERNOR_ROLE();
        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", curator, governorRole)
        );
        vm.prank(curator);
        keeper.setSwapFee(newFee);

        vm.prank(governor);
        keeper.setSwapFee(newFee);
    }

    function test_onlyGuardian_canPause_and_owner_canUnpause() external {
        // pause
        vm.prank(guardian);
        keeper.pause();
        assertTrue(spa.paused());

        // unpause by non-owner
        bytes32 protocolOwnerRole = keeper.PROTOCOL_OWNER_ROLE();
        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", governor, protocolOwnerRole)
        );
        vm.prank(governor);
        keeper.unpause();

        // unpause by owner
        vm.prank(protocolOwner);
        keeper.unpause();
        assertTrue(!spa.paused());
    }

    function test_onlyGuardian_canCancelRamp() external {
        uint256 newA = 110;
        uint256 endTime = block.timestamp + 1 days;
        vm.prank(curator);
        keeper.rampA(newA, endTime);

        // random (non-guardian) cannot cancel ramp
        address randomAddr = address(0xCAFE);
        bytes32 guardianRole = keeper.GUARDIAN_ROLE();
        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", randomAddr, guardianRole)
        );
        vm.prank(randomAddr);
        keeper.cancelRamp();

        // guardian can cancel
        vm.prank(guardian);
        keeper.cancelRamp();
    }

    function test_parameterRegistry_onlyOwner() external {
        IParameterRegistry.Bounds memory b =
            IParameterRegistry.Bounds({ max: 1e8, min: 0, maxDecreasePct: 0, maxIncreasePct: 1e10 });

        // non owner (governor)
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", curator));
        vm.prank(curator);
        parameterRegistry.setBounds(IParameterRegistry.ParamKey.SwapFee, b);

        // owner (governor)
        vm.prank(governor);
        parameterRegistry.setBounds(IParameterRegistry.ParamKey.SwapFee, b);
    }

    function test_keeperUpgrade_byProtocolOwner() external {
        // current impl
        bytes32 slot = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
        address oldImpl = address(uint160(uint256(vm.load(address(keeper), slot))));
        address newImpl = address(new Keeper());

        // unauthorized
        bytes32 protocolOwnerRole = keeper.PROTOCOL_OWNER_ROLE();
        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", governor, protocolOwnerRole)
        );
        vm.prank(governor);
        UUPSUpgradeable(address(keeper)).upgradeToAndCall(newImpl, "");

        // authorized – protocol owner
        vm.prank(protocolOwner);
        UUPSUpgradeable(address(keeper)).upgradeToAndCall(newImpl, "");
        address afterImpl = address(uint160(uint256(vm.load(address(keeper), slot))));
        assertEq(afterImpl, newImpl);
        assertTrue(afterImpl != oldImpl);
    }

    function test_beaconUpgrade_byProtocolOwner() external {
        address oldImpl = spaBeacon.implementation();
        address newImpl = address(new SelfPeggingAsset());

        // fail from guardian
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", guardian));
        vm.prank(guardian);
        spaBeacon.upgradeTo(newImpl);

        vm.prank(protocolOwner);
        spaBeacon.upgradeTo(newImpl);
        assertEq(spaBeacon.implementation(), newImpl);
        assertTrue(oldImpl != newImpl);
    }

    // Helper for buffer creation
    function _createBuffer(uint256 amount) internal {
        tokenA.mint(protocolOwner, amount);
        tokenB.mint(protocolOwner, amount);

        uint256[] memory _amounts = new uint256[](2);
        _amounts[0] = amount;
        _amounts[1] = amount;

        vm.startPrank(protocolOwner);
        tokenA.approve(address(spa), type(uint256).max);
        tokenB.approve(address(spa), type(uint256).max);
        spa.donateD(_amounts, 0);
        vm.stopPrank();
    }
}
