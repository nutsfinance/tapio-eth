// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { stdJson } from "forge-std/StdJson.sol";
import { console2 } from "forge-std/console2.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { CoreDeployer } from "./base/CoreDeployer.sol";
import { SelfPeggingAsset } from "../src/SelfPeggingAsset.sol";
import { SPAToken } from "../src/SPAToken.sol";
import { WSPAToken } from "../src/WSPAToken.sol";
import { RampAController } from "../src/periphery/RampAController.sol";
import { Keeper } from "../src/periphery/Keeper.sol";
import { SelfPeggingAssetFactory } from "../src/SelfPeggingAssetFactory.sol";

/**
 * @title Upgrade
 * @notice Selectively upgrade implementation contracts for existing deployment
 * @dev Deploys new implementations and updates beacons or UUPS proxies based on flags
 *
 * 1. Set upgrade flags below to enable/disable
 * 2. Run: forge script script/Upgrade.s.sol:Upgrade --rpc-url <network> --broadcast
 * 3. Only contracts with `true` flags will be upgraded
 */
contract Upgrade is CoreDeployer {
    using stdJson for string;

    bool constant UPGRADE_FACTORY = true;
    bool constant UPGRADE_SELF_PEGGING_ASSET = false;
    bool constant UPGRADE_SPA_TOKEN = false;
    bool constant UPGRADE_WSPA_TOKEN = false;
    bool constant UPGRADE_RAMP_A_CONTROLLER = false;
    bool constant UPGRADE_KEEPER = false; // pool names below if true

    /// @dev If UPGRADE_KEEPER is true, list pool names (e.g., ["usdcUsdt", "wethWsteth"])
    string[] poolsToUpgradeKeeper = ["usdcUsdt"];

    struct JSONData {
        address Factory;
        address SelfPeggingAssetBeacon;
        address SPATokenBeacon;
        address WSPATokenBeacon;
        address RampAControllerBeacon;
    }

    function run() public payable {
        deployerPrivateKey = vm.envUint("DEV_PROD_KEY");
        DEPLOYER = vm.addr(deployerPrivateKey);

        uint256 chainId = block.chainid;
        string memory networkName = getNetworkName(chainId);

        console2.log("====================================");
        console2.log("Upgrading Tapio Protocol");
        console2.log("====================================");
        console2.log("Chain ID:", chainId);
        console2.log("Network:", networkName);
        console2.log("Deployer:", DEPLOYER);

        loadSaltIdentifiers();

        vm.startBroadcast(deployerPrivateKey);

        string memory path = string.concat("./broadcast/", networkName, ".json");

        string memory json = vm.readFile(path);
        bytes memory data = vm.parseJson(json);

        JSONData memory jsonData = abi.decode(data, (JSONData));

        factory = SelfPeggingAssetFactory(jsonData.Factory);
        selfPeggingAssetBeacon = jsonData.SelfPeggingAssetBeacon;
        spaTokenBeacon = jsonData.SPATokenBeacon;
        wspaTokenBeacon = jsonData.WSPATokenBeacon;
        rampAControllerBeacon = jsonData.RampAControllerBeacon;

        console2.log("\n--- Upgrade plan");

        uint256 upgradeCount = 0;
        address factoryImpl;
        if (UPGRADE_FACTORY) {
            bytes32 salt = generateSalt(DEPLOYER, saltIds["FactoryImplementation"]);
            console2.log("  Factory: UUPS with salt", saltIds["FactoryImplementation"]);
            bytes memory initCode = type(SelfPeggingAssetFactory).creationCode;
            factoryImpl = deployCreate3(salt, initCode, "Factory Implementation");
            upgradeCount++;
        }

        address selfPeggingAssetImpl;
        if (UPGRADE_SELF_PEGGING_ASSET) {
            bytes32 salt = generateSalt(DEPLOYER, saltIds["SelfPeggingAsset"]);
            console2.log("  SelfPeggingAsset: Beacon with salt", saltIds["SelfPeggingAsset"]);
            bytes memory initCode = type(SelfPeggingAsset).creationCode;
            selfPeggingAssetImpl = deployCreate3(salt, initCode, "SelfPeggingAsset Implementation");
            upgradeCount++;
        }

        address spaTokenImpl;
        if (UPGRADE_SPA_TOKEN) {
            bytes32 salt = generateSalt(DEPLOYER, saltIds["SPAToken"]);
            console2.log("  SPAToken: Beacon with salt", saltIds["SPAToken"]);
            bytes memory initCode = type(SPAToken).creationCode;
            spaTokenImpl = deployCreate3(salt, initCode, "SPAToken Implementation");
            upgradeCount++;
        }

        address wspaTokenImpl;
        if (UPGRADE_WSPA_TOKEN) {
            bytes32 salt = generateSalt(DEPLOYER, saltIds["WSPAToken"]);
            console2.log("  WSPAToken: Beacon with salt", saltIds["WSPAToken"]);
            bytes memory initCode = type(WSPAToken).creationCode;
            wspaTokenImpl = deployCreate3(salt, initCode, "WSPAToken Implementation");
            upgradeCount++;
        }

        address rampAControllerImpl;
        if (UPGRADE_RAMP_A_CONTROLLER) {
            bytes32 salt = generateSalt(DEPLOYER, saltIds["RampAController"]);
            console2.log("  RampAController: Beacon with salt", saltIds["RampAController"]);
            bytes memory initCode = type(RampAController).creationCode;
            rampAControllerImpl = deployCreate3(salt, initCode, "RampAController Implementation");
            upgradeCount++;
        }

        address keeperImpl;
        if (UPGRADE_KEEPER) {
            bytes32 salt = generateSalt(DEPLOYER, saltIds["Keeper"]);
            console2.log("  Keeper: UUPS with salt", saltIds["Keeper"]);
            bytes memory initCode = type(Keeper).creationCode;
            keeperImpl = deployCreate3(salt, initCode, "Keeper Implementation");
            upgradeCount++;
        }

        console2.log("\n--- Upgrading contracts ---");

        if (UPGRADE_FACTORY) {
            UUPSUpgradeable(address(factory)).upgradeToAndCall(factoryImpl, "");
            console2.log("  [UUPS] Factory contract upgraded");
        }

        if (UPGRADE_SELF_PEGGING_ASSET) {
            UpgradeableBeacon(selfPeggingAssetBeacon).upgradeTo(selfPeggingAssetImpl);
            console2.log("  [Beacon] SelfPeggingAsset contract upgraded");
        }

        if (UPGRADE_SPA_TOKEN) {
            UpgradeableBeacon(spaTokenBeacon).upgradeTo(spaTokenImpl);
            console2.log("  [Beacon] SPAToken contract upgraded");
        }

        if (UPGRADE_WSPA_TOKEN) {
            UpgradeableBeacon(wspaTokenBeacon).upgradeTo(wspaTokenImpl);
            console2.log("  [Beacon] WSPAToken contract upgraded");
        }

        if (UPGRADE_RAMP_A_CONTROLLER) {
            UpgradeableBeacon(rampAControllerBeacon).upgradeTo(rampAControllerImpl);
            console2.log("  [Beacon] RampAController contract upgraded");
        }

        if (UPGRADE_KEEPER) {
            console2.log("  [UUPS] Upgrading Keepers for pools:");
            for (uint256 i = 0; i < poolsToUpgradeKeeper.length; i++) {
                string memory poolName = poolsToUpgradeKeeper[i];
                string memory keeperKey = string.concat(poolName, "Keeper");
                address keeperProxy = json.readAddress(string.concat(".", keeperKey));

                UUPSUpgradeable(keeperProxy).upgradeToAndCall(keeperImpl, "");
                console2.log("    -", poolName, "Keeper contract upgraded");
            }
        }

        console2.log("\nTotal contracts upgraded:", upgradeCount);

        vm.stopBroadcast();
    }
}
