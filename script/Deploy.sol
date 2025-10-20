// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { console } from "forge-std/console.sol";
import { SelfPeggingAsset } from "../src/SelfPeggingAsset.sol";
import { SPAToken } from "../src/SPAToken.sol";
import { WSPAToken } from "../src/WSPAToken.sol";
import { SelfPeggingAssetFactory } from "../src/SelfPeggingAssetFactory.sol";
import { Config } from "script/Config.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/misc/ConstantExchangeRateProvider.sol";
import { Zap } from "../src/periphery/Zap.sol";
import { RampAController } from "../src/periphery/RampAController.sol";
import { Keeper } from "../src/periphery/Keeper.sol";
import { CreateXDeployer } from "./CreateXDeployer.sol";

contract Deploy is Config, CreateXDeployer {
    function deployBeacons() internal {
        console.log("---------------");
        console.log("deploy-beacon-logs");
        console.log("---------------");

        bytes32 salt = keccak256("SelfPeggingAsset");
        bytes memory initCode = type(SelfPeggingAsset).creationCode;
        selfPeggingAssetImplentation = deployCreate2(salt, initCode);

        salt = keccak256("SPAToken");
        initCode = type(SPAToken).creationCode;
        lpTokenImplentation = deployCreate2(salt, initCode);

        salt = keccak256("WSPAToken");
        initCode = type(WSPAToken).creationCode;
        wlpTokenImplentation = deployCreate2(salt, initCode);

        salt = keccak256("RampAController");
        initCode = type(RampAController).creationCode;
        rampAControllerImplentation = deployCreate2(salt, initCode);

        salt = keccak256("Keeper");
        initCode = type(Keeper).creationCode;
        keeperImplementation = deployCreate2(salt, initCode);

        salt = keccak256("UpgradeableBeacon");
        initCode = abi.encodePacked(
            type(UpgradeableBeacon).creationCode, abi.encode(selfPeggingAssetImplentation, GOVERNOR)
        );
        selfPeggingAssetBeacon = deployCreate2(salt, initCode);

        salt = keccak256("UpgradeableBeacon");
        initCode = abi.encodePacked(type(UpgradeableBeacon).creationCode, abi.encode(lpTokenImplentation, GOVERNOR));
        lpTokenBeacon = deployCreate2(salt, initCode);

        salt = keccak256("UpgradeableBeacon");
        initCode = abi.encodePacked(type(UpgradeableBeacon).creationCode, abi.encode(wlpTokenImplentation, GOVERNOR));
        wlpTokenBeacon = deployCreate2(salt, initCode);

        salt = keccak256("UpgradeableBeacon");
        initCode =
            abi.encodePacked(type(UpgradeableBeacon).creationCode, abi.encode(rampAControllerImplentation, GOVERNOR));
        rampAControllerBeacon = deployCreate2(salt, initCode);
    }

    function deployFactory() internal {
        console.log("---------------");
        console.log("deploy-factory-logs");
        console.log("---------------");

        bytes32 salt = keccak256("ConstantExchangeRateProvider");
        bytes memory initCode = type(ConstantExchangeRateProvider).creationCode;
        address constantExchangeRateProvider = deployCreate2(salt, initCode);

        bytes memory data = abi.encodeCall(
            SelfPeggingAssetFactory.initialize,
            SelfPeggingAssetFactory.InitializeArgument(
                GOVERNOR,
                GOVERNOR,
                0,
                5_000_000,
                0,
                10_000_000_000,
                100,
                30 minutes,
                selfPeggingAssetBeacon,
                lpTokenBeacon,
                wlpTokenBeacon,
                rampAControllerBeacon,
                keeperImplementation,
                constantExchangeRateProvider,
                0,
                1_000_000_000
            )
        );

        salt = keccak256("SelfPeggingAssetFactory");
        initCode = type(SelfPeggingAssetFactory).creationCode;
        factoryImplementation = deployCreate2(salt, initCode);

        salt = keccak256("FactoryProxy");
        initCode = abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(factoryImplementation, data));

        factory = SelfPeggingAssetFactory(deployCreate2(salt, initCode));
        factory.transferOwnership(GOVERNOR);

        console.log("Factory Proxy: %s", address(factory));
    }

    function deployZap() internal {
        console.log("---------------");
        console.log("deploy-zap-logs");
        console.log("---------------");

        bytes32 salt = keccak256("Zap");
        bytes memory initCode = type(Zap).creationCode;
        zap = deployCreate2(salt, initCode);

        console.log("Zap: %s", zap);
    }
}
