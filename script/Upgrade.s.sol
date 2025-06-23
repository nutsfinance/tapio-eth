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
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { SelfPeggingAsset } from "../src/SelfPeggingAsset.sol";
import { SPAToken } from "../src/SPAToken.sol";
import { WSPAToken } from "../src/WSPAToken.sol";
import { SelfPeggingAssetFactory } from "../src/SelfPeggingAssetFactory.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract Upgrade is Deploy, Setup, Pool {
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
        spaTokenBeacon = jsonData.SPATokenBeacon;
        wspaTokenBeacon = jsonData.WSPATokenBeacon;

        // Upgrade
        SPAToken spaTokenImpl = new SPAToken();
        WSPAToken wspaTokenImpl = new WSPAToken();
        SelfPeggingAsset selfPeggingAssetImpl = new SelfPeggingAsset();
        SelfPeggingAssetFactory factoryImpl = SelfPeggingAssetFactory(factory);

        UpgradeableBeacon(spaTokenBeacon).upgradeTo(address(spaTokenImpl));
        UpgradeableBeacon(wspaTokenBeacon).upgradeTo(address(wspaTokenImpl));
        UpgradeableBeacon(selfPeggingAssetBeacon).upgradeTo(address(selfPeggingAssetImpl));
        factory.upgradeToAndCall(address(factoryImpl), bytes(""));

        vm.stopBroadcast();
    }
}
