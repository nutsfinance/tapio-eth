// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { console } from "forge-std/console.sol";

import { SelfPeggingAssetFactory } from "../src/SelfPeggingAssetFactory.sol";
import { MockToken } from "../src/mock/MockToken.sol";
import { MockERC4626Token } from "../src/mock/MockERC4626Token.sol";
import { MockOracle } from "../src/mock/MockOracle.sol";
import { SelfPeggingAsset } from "../src/SelfPeggingAsset.sol";
import { LPToken } from "../src/LPToken.sol";
import { WLPToken } from "../src/WLPToken.sol";
import { RampAController } from "../src/periphery/RampAController.sol";
import { Keeper } from "../src/periphery/Keeper.sol";
import { ParameterRegistry } from "../src/periphery/ParameterRegistry.sol";

import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "../src/misc/ConstantExchangeRateProvider.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract FactoryTest is Test {
    SelfPeggingAssetFactory internal factory;
    address governor = address(0x01);
    address initialMinter = address(0x02);

    function setUp() public virtual {
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
                governor,
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
        ERC1967Proxy proxy = new ERC1967Proxy(address(new SelfPeggingAssetFactory()), data);
        factory = SelfPeggingAssetFactory(address(proxy));
    }

    function test_CreatePoolConstantExchangeRate() external {
        MockToken tokenA = new MockToken("test 1", "T1", 18);
        MockToken tokenB = new MockToken("test 2", "T2", 18);

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

        vm.recordLogs();
        factory.createPool(arg);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 eventSig = keccak256("PoolCreated(address,address,address,address,address,address)");

        address decodedPoolToken;
        address decodedSelfPeggingAsset;
        address decodedWrappedPoolToken;
        address decodedRampAController;
        address decodedKeeper;
        address decodedParameterRegistry;

        for (uint256 i = 0; i < entries.length; i++) {
            Vm.Log memory log = entries[i];

            if (log.topics[0] == eventSig) {
                (
                    decodedPoolToken,
                    decodedSelfPeggingAsset,
                    decodedWrappedPoolToken,
                    decodedRampAController,
                    decodedKeeper,
                    decodedParameterRegistry
                ) = abi.decode(log.data, (address, address, address, address, address, address));
            }
        }

        SelfPeggingAsset selfPeggingAsset = SelfPeggingAsset(decodedSelfPeggingAsset);
        LPToken poolToken = LPToken(decodedPoolToken);
        WLPToken wrappedPoolToken = WLPToken(decodedWrappedPoolToken);

        vm.startPrank(initialMinter);
        tokenA.mint(initialMinter, 100e18);
        tokenB.mint(initialMinter, 100e18);

        tokenA.approve(address(selfPeggingAsset), 100e18);
        tokenB.approve(address(selfPeggingAsset), 100e18);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e18;
        amounts[1] = 100e18;

        vm.warp(block.timestamp + 1000);

        selfPeggingAsset.mint(amounts, 0);

        assertEq(poolToken.balanceOf(initialMinter), 200e18 - 1000 wei);
        assertNotEq(address(wrappedPoolToken), address(0));
    }

    function test_CreatePoolERC4626ExchangeRate() external {
        MockERC4626Token vaultTokenA = new MockERC4626Token();
        MockERC4626Token vaultTokenB = new MockERC4626Token();

        MockToken tokenA = new MockToken("test 1", "T1", 18);
        MockToken tokenB = new MockToken("test 2", "T2", 18);

        vaultTokenA.initialize(tokenA);
        vaultTokenB.initialize(tokenB);

        SelfPeggingAssetFactory.CreatePoolArgument memory arg = SelfPeggingAssetFactory.CreatePoolArgument({
            tokenA: address(vaultTokenA),
            tokenB: address(vaultTokenB),
            tokenAType: SelfPeggingAssetFactory.TokenType.ERC4626,
            tokenAOracle: address(0),
            tokenARateFunctionSig: new bytes(0),
            tokenADecimalsFunctionSig: new bytes(0),
            tokenBType: SelfPeggingAssetFactory.TokenType.ERC4626,
            tokenBOracle: address(0),
            tokenBRateFunctionSig: new bytes(0),
            tokenBDecimalsFunctionSig: new bytes(0)
        });

        vm.recordLogs();

        factory.createPool(arg);

        Vm.Log[] memory entries = vm.getRecordedLogs();

        (address decodedPoolToken, address decodedSelfPeggingAsset, address decodedWrappedPoolToken,,,) =
            _decodePoolCreatedEvent(entries);
        SelfPeggingAsset selfPeggingAsset = SelfPeggingAsset(decodedSelfPeggingAsset);
        LPToken poolToken = LPToken(decodedPoolToken);
        WLPToken wrappedPoolToken = WLPToken(decodedWrappedPoolToken);

        vm.startPrank(initialMinter);
        tokenA.mint(initialMinter, 100e18);
        tokenB.mint(initialMinter, 100e18);

        tokenA.approve(address(vaultTokenA), 100e18);
        tokenB.approve(address(vaultTokenB), 100e18);

        vaultTokenA.deposit(100e18, initialMinter);
        vaultTokenB.deposit(100e18, initialMinter);

        vaultTokenA.approve(address(selfPeggingAsset), 100e18);
        vaultTokenB.approve(address(selfPeggingAsset), 100e18);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e18;
        amounts[1] = 100e18;

        vm.warp(block.timestamp + 1000);

        selfPeggingAsset.mint(amounts, 0);

        assertEq(poolToken.balanceOf(initialMinter), 200e18 - 1000 wei);
        assertNotEq(address(wrappedPoolToken), address(0));
    }

    function test_CreatePoolOracleExchangeRate() external {
        MockToken tokenA = new MockToken("test 1", "T1", 18);
        MockToken tokenB = new MockToken("test 2", "T2", 18);

        MockOracle oracle = new MockOracle();

        SelfPeggingAssetFactory.CreatePoolArgument memory arg = SelfPeggingAssetFactory.CreatePoolArgument({
            tokenA: address(tokenA),
            tokenB: address(tokenB),
            tokenAType: SelfPeggingAssetFactory.TokenType.Oracle,
            tokenAOracle: address(oracle),
            tokenARateFunctionSig: abi.encodePacked(MockOracle.rate.selector),
            tokenADecimalsFunctionSig: abi.encodePacked(MockOracle.decimals.selector),
            tokenBType: SelfPeggingAssetFactory.TokenType.Oracle,
            tokenBOracle: address(oracle),
            tokenBRateFunctionSig: abi.encodePacked(MockOracle.rate.selector),
            tokenBDecimalsFunctionSig: abi.encodePacked(MockOracle.decimals.selector)
        });

        vm.recordLogs();
        factory.createPool(arg);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        (address decodedPoolToken, address decodedSelfPeggingAsset, address decodedWrappedPoolToken,,,) =
            _decodePoolCreatedEvent(entries);

        SelfPeggingAsset selfPeggingAsset = SelfPeggingAsset(decodedSelfPeggingAsset);
        LPToken poolToken = LPToken(decodedPoolToken);
        WLPToken wrappedPoolToken = WLPToken(decodedWrappedPoolToken);

        vm.startPrank(initialMinter);
        tokenA.mint(initialMinter, 100e18);
        tokenB.mint(initialMinter, 100e18);

        tokenA.approve(address(selfPeggingAsset), 100e18);
        tokenB.approve(address(selfPeggingAsset), 100e18);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e18;
        amounts[1] = 100e18;

        vm.warp(block.timestamp + 1000);

        selfPeggingAsset.mint(amounts, 0);

        assertEq(poolToken.balanceOf(initialMinter), 200e18 - 1000 wei);
        assertNotEq(address(wrappedPoolToken), address(0));
    }

    function test_disableDirectInitialisation() external {
        SelfPeggingAssetFactory factory = new SelfPeggingAssetFactory();
        ConstantExchangeRateProvider exchangeRateProvider = new ConstantExchangeRateProvider();

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        factory.initialize(
            governor,
            governor,
            0,
            0,
            0,
            0,
            100,
            30 minutes,
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(exchangeRateProvider),
            0,
            0
        );

        SelfPeggingAsset selfPeggingAsset = new SelfPeggingAsset();
        address[] memory _tokens;
        uint256[] memory _precisions;
        uint256[] memory _fees;
        IExchangeRateProvider[] memory _exchangeRateProviders;
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        selfPeggingAsset.initialize(
            _tokens, _precisions, _fees, 0, LPToken(address(0)), 0, _exchangeRateProviders, address(0), 0, governor
        );

        LPToken lpToken = new LPToken();
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        lpToken.initialize("", "", 0, address(0), address(0));

        WLPToken wlpToken = new WLPToken();
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        wlpToken.initialize(LPToken(address(0)));

        RampAController rampAController = new RampAController();
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        rampAController.initialize(30 minutes, 0, governor);
    }

    function _decodePoolCreatedEvent(Vm.Log[] memory entries)
        internal
        pure
        returns (address, address, address, address, address, address)
    {
        bytes32 eventSig = keccak256("PoolCreated(address,address,address,address,address,address)");
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == eventSig) {
                return abi.decode(entries[i].data, (address, address, address, address, address, address));
            }
        }
        revert("PoolCreated event not found");
    }
}
