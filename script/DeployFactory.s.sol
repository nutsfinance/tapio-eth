// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console2 } from "forge-std/console2.sol";
import { CoreDeployer } from "./base/CoreDeployer.sol";
import { PoolDeployer } from "./base/PoolDeployer.sol";

/**
 * @title DeployFactory
 * @notice Main script for deploying Tapio protocol factory
 * @dev Configuration-driven deployment using JSON configs
 */
contract DeployFactory is CoreDeployer, PoolDeployer {
    constructor() CoreDeployer() { }

    function run() public payable {
        string memory chain = vm.envString("CHAIN");
        uint256 chainId = vm.envUint("CHAIN_ID");
        string memory version = vm.envString("VERSION");
        bool dryRun = vm.envBool("DRY_RUN");
        address safeAddress = vm.envOr("SAFE_ADDRESS", address(0));
        bool useSafe = safeAddress != address(0);

        string memory baseDir = getBaseDir(dryRun);

        setUp();
        vm.createSelectFork(vm.envString(rpcs[chainId]));

        console2.log("====================================");
        console2.log("Deploying Tapio Factory");
        console2.log("====================================");
        console2.log("Chain ID:", chainId);
        console2.log("Network:", chain);
        console2.log("Deployer:", DEPLOYER);

        // load configs
        loadConfig(chain, version);
        verifyCreateX();
        loadSaltIdentifiers();

        // load factory defaults
        FactoryDefaults memory factoryDefaults = loadFactoryDefaults(chain, version);

        if (useSafe) {
            } else {
            // deploy
            vm.startBroadcast(deployerPrivateKey);
            console2.log("\n--- Core protocol ---");
            deployBeacons();
            deployFactory(factoryDefaults);
            deployZap();
        }
        vm.stopBroadcast();

        // save artifacts
        console2.log("\n--- Saving artifacts ---");
        saveFactoryArtifacts(chain, version, dryRun);
    }

    /**
     * @notice Save deployment artifacts to JSON files
     * @dev Creates 2 files: <network>.json (proxies/beacons) and <network>.impl.json (implementations)
     */
    function saveFactoryArtifacts(string memory chain, string memory version, bool dryRun) internal {
        string memory path = dryRun
            ? string.concat("./deployments/", version, "/dryRun/", chain, ".json")
            : string.concat("./deployments/", version, "/", chain, ".json");
        string memory pathImpl = dryRun
            ? string.concat("./deployments/", version, "/dryRun/", chain, ".impl.json")
            : string.concat("./deployments/", version, "/", chain, ".impl.json");

        // core infrastructure
        vm.writeJson(vm.serializeAddress("contracts", "Factory", address(factory)), path);
        vm.writeJson(vm.serializeAddress("contracts", "Zap", zap), path);
        vm.writeJson(vm.serializeAddress("contracts", "SelfPeggingAssetBeacon", selfPeggingAssetBeacon), path);
        vm.writeJson(vm.serializeAddress("contracts", "SPATokenBeacon", spaTokenBeacon), path);
        vm.writeJson(vm.serializeAddress("contracts", "WSPATokenBeacon", wspaTokenBeacon), path);
        vm.writeJson(vm.serializeAddress("contracts", "RampAControllerBeacon", rampAControllerBeacon), path);

        // implementations
        string memory implJson = "impl";
        vm.serializeAddress(implJson, "Factory", factoryImplementation);
        vm.serializeAddress(implJson, "SelfPeggingAsset", selfPeggingAssetImplementation);
        vm.serializeAddress(implJson, "SPAToken", spaTokenImplementation);
        vm.serializeAddress(implJson, "WSPAToken", wspaTokenImplementation);
        vm.serializeAddress(implJson, "RampAController", rampAControllerImplementation);
        string memory finalImpl = vm.serializeAddress(implJson, "Keeper", keeperImplementation);
        vm.writeJson(finalImpl, pathImpl);

        console2.log("  Artifacts saved to:", path);
        console2.log("  Implementations to:", pathImpl);
    }
}
