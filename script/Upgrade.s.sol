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
import { SPAToken } from "../src/SPAToken.sol";
import { WSPAToken } from "../src/WSPAToken.sol";
import { SelfPeggingAssetFactory } from "../src/SelfPeggingAssetFactory.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract Upgrade is Deploy, Pool {
    struct JSONData {
        address Factory;
        address SPATokenBeacon;
        address SelfPeggingAssetBeacon;
        address WSPATokenBeacon;
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
        loadSaltIdentifiers();

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
        bytes32 salt = generateSalt(DEPLOYER, saltIds["SPAToken"]);
        bytes memory initCode = type(SPAToken).creationCode;
        SPAToken lpTokenImpl = SPAToken((deployCreate3(salt, initCode, "SPAToken Implementation")));

        salt = generateSalt(DEPLOYER, saltIds["WSPAToken"]);
        initCode = type(WSPAToken).creationCode;
        WSPAToken wlpTokenImpl = WSPAToken((deployCreate3(salt, initCode, "WSPAToken Implementation")));

        salt = generateSalt(DEPLOYER, saltIds["SelfPeggingAsset"]);
        initCode = type(SelfPeggingAsset).creationCode;
        SelfPeggingAsset selfPeggingAssetImpl = SelfPeggingAsset((deployCreate3(salt, initCode, "SelfPeggingAsset Implementation")));

        SelfPeggingAssetFactory factoryImpl = SelfPeggingAssetFactory(factory);

        UpgradeableBeacon(spaTokenBeacon).upgradeTo(address(lpTokenImpl));
        UpgradeableBeacon(wspaTokenBeacon).upgradeTo(address(wlpTokenImpl));
        UpgradeableBeacon(selfPeggingAssetBeacon).upgradeTo(address(selfPeggingAssetImpl));
        factory.upgradeToAndCall(address(factoryImpl), bytes(""));

        vm.stopBroadcast();
    }
}
