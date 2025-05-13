// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { stdJson } from "forge-std/StdJson.sol";
import { console } from "forge-std/console.sol";

import { Deploy } from "script/Deploy.sol";
import { Setup } from "script/Setup.sol";
import { Pool } from "script/Pool.sol";
import { SelfPeggingAssetFactory } from "../src/SelfPeggingAssetFactory.sol";
import { SelfPeggingAsset } from "../src/SelfPeggingAsset.sol";
import { MockToken } from "../src/mock/MockToken.sol";
import {RampAController} from "../src/periphery/RampAController.sol";
import {KeeperController} from "../src/periphery/KeeperController.sol";
import {IRampAController} from "../src/interfaces/IRampAController.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract AddKeeper is Deploy, Setup, Pool {
    function init() internal {
        if (vm.envUint("HEX_PRIV_KEY") == 0) revert("No private key found");
        deployerPrivateKey = vm.envUint("HEX_PRIV_KEY");
        DEPLOYER = vm.addr(deployerPrivateKey);
    }

    function run() public payable {
        init();
        loadConfig();

        vm.startBroadcast(deployerPrivateKey);

        address keeperController=0x53C29D2BE54Fa9648395b0A1Cc543AAB93A4Be2F;
        address keeperAddress=0xbD29556A41C10deb19072c558E147C6B4b384eed;

        KeeperController(keeperController).setKeeper(keeperAddress, true);
 
        vm.stopBroadcast();


    }
}
