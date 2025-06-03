// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { console } from "forge-std/console.sol";
import { SelfPeggingAsset } from "../src/SelfPeggingAsset.sol";
import { LPToken } from "../src/LPToken.sol";
import { WLPToken } from "../src/WLPToken.sol";
import { SelfPeggingAssetFactory } from "../src/SelfPeggingAssetFactory.sol";
import { Config } from "script/Config.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/misc/ConstantExchangeRateProvider.sol";
import { Zap } from "../src/periphery/Zap.sol";
import { Keeper } from "../src/periphery/Keeper.sol";

import { RampAController } from "../src/periphery/RampAController.sol";

contract Deploy is Config {
    function deployBeacons() internal {
        console.log("---------------");
        console.log("deploy-beacon-logs");
        console.log("---------------");

        address selfPeggingAssetImplentation = address(new SelfPeggingAsset());
        address lpTokenImplentation = address(new LPToken());
        address wlpTokenImplentation = address(new WLPToken());
        address rampAControllerImplentation = address(new RampAController());
        keeperImplementation = address(new Keeper());

        UpgradeableBeacon beacon = new UpgradeableBeacon(selfPeggingAssetImplentation, GOVERNOR);
        selfPeggingAssetBeacon = address(beacon);

        beacon = new UpgradeableBeacon(lpTokenImplentation, GOVERNOR);
        lpTokenBeacon = address(beacon);

        beacon = new UpgradeableBeacon(wlpTokenImplentation, GOVERNOR);
        wlpTokenBeacon = address(beacon);

        beacon = new UpgradeableBeacon(rampAControllerImplentation, GOVERNOR);
        rampAControllerBeacon = address(beacon);
    }

    function deployFactory() internal {
        console.log("---------------");
        console.log("deploy-factory-logs");
        console.log("---------------");

        bytes memory data = abi.encodeCall(
            SelfPeggingAssetFactory.initialize,
            (
                GOVERNOR,
                GOVERNOR,
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
        factory.transferOwnership(GOVERNOR);
    }

    function deployZap() internal {
        console.log("---------------");
        console.log("deploy-zap-logs");
        console.log("---------------");

        zap = address(new Zap());
    }
}
