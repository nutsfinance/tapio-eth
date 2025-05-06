// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { stdJson } from "forge-std/StdJson.sol";
import { console } from "forge-std/console.sol";

import { Deploy } from "script/Deploy.sol";
import { Pool } from "script/Pool.sol";
import { SelfPeggingAssetFactory } from "../src/SelfPeggingAssetFactory.sol";
import { SelfPeggingAsset } from "../src/SelfPeggingAsset.sol";
import { MockToken } from "../src/mock/MockToken.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { SelfPeggingAsset } from "../src/SelfPeggingAsset.sol";
import { LPToken } from "../src/LPToken.sol";
import { WLPToken } from "../src/WLPToken.sol";
import { SelfPeggingAssetFactory } from "../src/SelfPeggingAssetFactory.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract Upgrade is Deploy, Pool {
    struct JSONData {
        address Factory;
        address LPTokenBeacon;
        address SelfPeggingAssetBeacon;
        address WLPTokenBeacon;
        address Zap;
    }

    function init() internal {
        if (vm.envUint("HEX_PRIV_KEY") == 0) revert("No private key found");
        deployerPrivateKey = vm.envUint("HEX_PRIV_KEY");
        DEPLOYER = vm.addr(deployerPrivateKey);
    }

    function run() public payable {
        init();
        loadConfig();

        vm.startBroadcast(deployerPrivateKey);

        string memory root = vm.projectRoot();
        string memory path;
        string memory networkName = getNetworkName(getChainId());
        path = string.concat(root, "/broadcast/", networkName, ".json");

        string memory json = vm.readFile(path);
        bytes memory data = vm.parseJson(json);

        JSONData memory jsonData = abi.decode(data, (JSONData));

        factory = SelfPeggingAssetFactory(jsonData.Factory);
        selfPeggingAssetBeacon = jsonData.SelfPeggingAssetBeacon;
        lpTokenBeacon = jsonData.LPTokenBeacon;
        wlpTokenBeacon = jsonData.WLPTokenBeacon;

        // Upgrade
        LPToken lpTokenImpl = new LPToken();
        WLPToken wlpTokenImpl = new WLPToken();
        SelfPeggingAsset selfPeggingAssetImpl = new SelfPeggingAsset();
        SelfPeggingAssetFactory factoryImpl = SelfPeggingAssetFactory(factory);

        UpgradeableBeacon(lpTokenBeacon).upgradeTo(address(lpTokenImpl));
        UpgradeableBeacon(wlpTokenBeacon).upgradeTo(address(wlpTokenImpl));
        UpgradeableBeacon(selfPeggingAssetBeacon).upgradeTo(address(selfPeggingAssetImpl));
        factory.upgradeToAndCall(address(factoryImpl), bytes(""));

        vm.stopBroadcast();
    }
}
