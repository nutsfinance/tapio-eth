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
    using stdJson for string;

    mapping(string => string) internal saltIds;

    function loadSaltIdentifiers() internal {
        string memory saltPath = "script/configs/salts.json";
        string memory saltJson = vm.readFile(saltPath);

        // implementations
        saltIds["SelfPeggingAsset"] = saltJson.readString(".contracts.implementations.SelfPeggingAsset");
        saltIds["SPAToken"] = saltJson.readString(".contracts.implementations.SPAToken");
        saltIds["WSPAToken"] = saltJson.readString(".contracts.implementations.WSPAToken");
        saltIds["RampAController"] = saltJson.readString(".contracts.implementations.RampAController");
        saltIds["Keeper"] = saltJson.readString(".contracts.implementations.Keeper");

        // beacons
        saltIds["SelfPeggingAssetBeacon"] = saltJson.readString(".contracts.beacons.SelfPeggingAssetBeacon");
        saltIds["SPATokenBeacon"] = saltJson.readString(".contracts.beacons.SPATokenBeacon");
        saltIds["WSPATokenBeacon"] = saltJson.readString(".contracts.beacons.WSPATokenBeacon");
        saltIds["RampAControllerBeacon"] = saltJson.readString(".contracts.beacons.RampAControllerBeacon");

        // factory
        saltIds["FactoryImplementation"] = saltJson.readString(".contracts.factory.FactoryImplementation");
        saltIds["FactoryProxy"] = saltJson.readString(".contracts.factory.FactoryProxy");

        // periphery
        saltIds["ConstantExchangeRateProvider"] =
            saltJson.readString(".contracts.periphery.ConstantExchangeRateProvider");
        saltIds["Zap"] = saltJson.readString(".contracts.periphery.Zap");
    }

    function deployBeacons() internal {
        bytes32 salt;
        bytes memory initCode;

        // 1. SelfPeggingAsset Implementation
        salt = generateSalt(DEPLOYER, saltIds["SelfPeggingAsset"]);
        initCode = type(SelfPeggingAsset).creationCode;
        selfPeggingAssetImplementation = deployCreate3(salt, initCode, "SelfPeggingAsset Implementation");

        // 2. SPAToken Implementation
        salt = generateSalt(DEPLOYER, saltIds["SPAToken"]);
        initCode = type(SPAToken).creationCode;
        spaTokenImplementation = deployCreate3(salt, initCode, "SPAToken Implementation");

        // 3. WSPAToken Implementation
        salt = generateSalt(DEPLOYER, saltIds["WSPAToken"]);
        initCode = type(WSPAToken).creationCode;
        wspaTokenImplementation = deployCreate3(salt, initCode, "WSPAToken Implementation");

        // 4. RampAController Implementation
        salt = generateSalt(DEPLOYER, saltIds["RampAController"]);
        initCode = type(RampAController).creationCode;
        rampAControllerImplementation = deployCreate3(salt, initCode, "RampAController Implementation");

        // 5. Keeper Implementation
        salt = generateSalt(DEPLOYER, saltIds["Keeper"]);
        initCode = type(Keeper).creationCode;
        keeperImplementation = deployCreate3(salt, initCode, "Keeper Implementation");

        // Deploy beacons using CREATE3 (with unique salts!)

        // 6. SelfPeggingAsset Beacon
        salt = generateSalt(DEPLOYER, saltIds["SelfPeggingAssetBeacon"]);
        initCode = abi.encodePacked(
            type(UpgradeableBeacon).creationCode, abi.encode(selfPeggingAssetImplementation, GOVERNOR)
        );
        selfPeggingAssetBeacon = deployCreate3(salt, initCode, "SelfPeggingAsset Beacon");

        // 7. SPAToken Beacon
        salt = generateSalt(DEPLOYER, saltIds["SPATokenBeacon"]);
        initCode = abi.encodePacked(type(UpgradeableBeacon).creationCode, abi.encode(spaTokenImplementation, GOVERNOR));
        spaTokenBeacon = deployCreate3(salt, initCode, "SPAToken Beacon");

        // 8. WSPAToken Beacon
        salt = generateSalt(DEPLOYER, saltIds["WSPATokenBeacon"]);
        initCode = abi.encodePacked(type(UpgradeableBeacon).creationCode, abi.encode(wspaTokenImplementation, GOVERNOR));
        wspaTokenBeacon = deployCreate3(salt, initCode, "WSPAToken Beacon");

        // 9. RampAController Beacon
        salt = generateSalt(DEPLOYER, saltIds["RampAControllerBeacon"]);
        initCode = abi.encodePacked(
            type(UpgradeableBeacon).creationCode, abi.encode(rampAControllerImplementation, GOVERNOR)
        );
        rampAControllerBeacon = deployCreate3(salt, initCode, "RampAController Beacon");
    }

    function deployFactory() internal {
        bytes32 salt;
        bytes memory initCode;

        // 10. ConstantExchangeRateProvider
        salt = generateSalt(DEPLOYER, saltIds["ConstantExchangeRateProvider"]);
        initCode = type(ConstantExchangeRateProvider).creationCode;
        address constantExchangeRateProvider = deployCreate3(salt, initCode, "ConstantExchangeRateProvider");

        // Prepare factory initialization data
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
                spaTokenBeacon,
                wspaTokenBeacon,
                rampAControllerBeacon,
                keeperImplementation,
                constantExchangeRateProvider,
                0,
                1_000_000_000
            )
        );

        // 11. Factory Implementation
        salt = generateSalt(DEPLOYER, saltIds["FactoryImplementation"]);
        initCode = type(SelfPeggingAssetFactory).creationCode;
        factoryImplementation = deployCreate3(salt, initCode, "Factory Implementation");

        // 12. Factory Proxy
        salt = generateSalt(DEPLOYER, saltIds["FactoryProxy"]);
        initCode = abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(factoryImplementation, data));
        address factoryProxy = deployCreate3(salt, initCode, "Factory Proxy");

        factory = SelfPeggingAssetFactory(factoryProxy);
        factory.transferOwnership(GOVERNOR);
    }

    function deployZap() internal {
        // 13. Zap
        bytes32 salt = generateSalt(DEPLOYER, saltIds["Zap"]);
        bytes memory initCode = type(Zap).creationCode;
        zap = deployCreate3(salt, initCode, "Zap");
    }
}
