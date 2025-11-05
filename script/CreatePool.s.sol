// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { stdJson } from "forge-std/StdJson.sol";
import { console2 } from "forge-std/console2.sol";
import { ChainConfig } from "./base/ChainConfig.sol";
import { PoolDeployer } from "./base/PoolDeployer.sol";
import { SelfPeggingAssetFactory } from "../src/SelfPeggingAssetFactory.sol";

/**
 * @title CreatePool
 * @notice Deploy new pools to existing Tapio deployment
 * @dev Loads existing deployment and adds new pools from config
 */
contract CreatePool is ChainConfig, PoolDeployer {
    using stdJson for string;

    struct DeploymentData {
        address Factory;
        address SelfPeggingAssetBeacon;
        address SPATokenBeacon;
        address WSPATokenBeacon;
        address RampAControllerBeacon;
        address Zap;
    }

    mapping(string => bool) existingPools;
    uint256 deployerPrivateKey;
    address DEPLOYER;

    function run() public payable {
        deployerPrivateKey = vm.envUint("DEV_PROD_KEY");
        DEPLOYER = vm.addr(deployerPrivateKey);

        uint256 chainId = block.chainid;
        string memory networkName = getNetworkName(chainId);

        console2.log("====================================");
        console2.log("Adding Pools to Existing Deployment");
        console2.log("====================================");
        console2.log("Chain ID:", chainId);
        console2.log("Network:", networkName);
        console2.log("Deployer:", DEPLOYER);

        // Load existing deployment
        console2.log("\n--- Loading Existing Deployment ---");
        loadExistingDeployment(networkName);

        // Load pool configurations
        console2.log("\n--- Loading Pool Configs ---");
        loadChainConfig(networkName, "mainnet");
        loadPoolConfigs(networkName, "mainnet");

        // Filter out existing pools
        console2.log("\n--- Filtering New Pools ---");
        filterNewPools();

        if (pools.length == 0) {
            console2.log("No new pools to deploy!");
            return;
        }

        // Deploy new pools
        vm.startBroadcast(deployerPrivateKey);

        console2.log("\n--- Deploying New Pools ---");
        deployPools();

        vm.stopBroadcast();

        // Update deployment artifacts
        console2.log("\n--- Updating Artifacts ---");
        updateDeploymentArtifacts(networkName);

        console2.log("\n====================================");
        console2.log("Pool Deployment Complete!");
        console2.log("====================================");
    }

    function loadExistingDeployment(string memory networkName) internal {
        string memory path = string.concat("./broadcast/", networkName, ".json");

        if (!vm.isFile(path)) {
            revert(string.concat("No existing deployment found at: ", path));
        }

        string memory json = vm.readFile(path);

        // Load core contracts
        address factoryAddr = json.readAddress(".Factory");
        poolFactory = SelfPeggingAssetFactory(factoryAddr);

        console2.log("  Factory:", address(poolFactory));

        // Load existing pool names from all contract keys ending with "Pool"
        // Deploy.s.sol saves pools as: {poolName}Pool, {poolName}SPAToken, etc.
        // Artifacts are saved at root level, so we parse keys from root
        string[] memory keys = vm.parseJsonKeys(json, ".");
        uint256 existingCount = 0;

        for (uint256 i = 0; i < keys.length; i++) {
            string memory key = keys[i];

            // Check if key ends with "Pool" and is not a beacon
            if (endsWith(key, "Pool") && !equals(key, "SelfPeggingAssetBeacon")) {
                // Extract pool name by removing "Pool" suffix
                string memory poolName = substring(key, 0, bytes(key).length - 4);
                existingPools[poolName] = true;
                existingCount++;
                console2.log("  Existing pool:", poolName);
            }
        }

        if (existingCount == 0) {
            console2.log("  No existing pools found");
        }
    }

    /**
     * @notice Check if string ends with suffix
     */
    function endsWith(string memory str, string memory suffix) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory suffixBytes = bytes(suffix);

        if (strBytes.length < suffixBytes.length) {
            return false;
        }

        uint256 offset = strBytes.length - suffixBytes.length;
        for (uint256 i = 0; i < suffixBytes.length; i++) {
            if (strBytes[offset + i] != suffixBytes[i]) {
                return false;
            }
        }

        return true;
    }

    function equals(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }

    function substring(string memory str, uint256 start, uint256 end) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(end - start);

        for (uint256 i = start; i < end; i++) {
            result[i - start] = strBytes[i];
        }

        return string(result);
    }

    /**
     * @notice Filter out pools that already exist
     */
    function filterNewPools() internal {
        PoolConfig[] memory allPools = new PoolConfig[](pools.length);
        uint256 newPoolCount = 0;

        for (uint256 i = 0; i < pools.length; i++) {
            if (!existingPools[pools[i].name]) {
                allPools[newPoolCount] = pools[i];
                newPoolCount++;
                console2.log("  New pool to deploy:", pools[i].name);
            } else {
                console2.log("  Skipping existing pool:", pools[i].name);
            }
        }

        delete pools;
        for (uint256 i = 0; i < newPoolCount; i++) {
            pools.push(allPools[i]);
        }

        console2.log("  Total new pools:", newPoolCount);
    }

    /**
     * @notice Update deployment artifacts with new pools
     */
    function updateDeploymentArtifacts(string memory networkName) internal {
        string memory path = string.concat("./broadcast/", networkName, ".json");

        // Read existing JSON to preserve all data
        string memory existingJson = vm.readFile(path);
        string[] memory existingKeys = vm.parseJsonKeys(existingJson, ".");

        // Build complete JSON with existing + new data
        string memory objectKey = "deployment";
        string memory finalJson;

        // First, serialize all existing data
        for (uint256 i = 0; i < existingKeys.length; i++) {
            string memory key = existingKeys[i];
            address value = existingJson.readAddress(string.concat(".", key));
            finalJson = vm.serializeAddress(objectKey, key, value);
        }

        // Add new oracles
        for (uint256 i = 0; i < deployedOracles.length; i++) {
            DeployedOracle memory oracle = getDeployedOracle(i);
            finalJson = vm.serializeAddress(objectKey, oracle.name, oracle.oracle);
        }

        // Add new pools (all components)
        for (uint256 i = 0; i < deployedPools.length; i++) {
            DeployedPool memory pool = getDeployedPool(i);
            string memory prefix = string.concat(pool.name);

            finalJson = vm.serializeAddress(objectKey, string.concat(prefix, "Pool"), pool.selfPeggingAsset);
            finalJson = vm.serializeAddress(objectKey, string.concat(prefix, "SPAToken"), pool.poolToken);
            finalJson = vm.serializeAddress(objectKey, string.concat(prefix, "WSPAToken"), pool.wrappedPoolToken);
            finalJson = vm.serializeAddress(objectKey, string.concat(prefix, "RampAController"), pool.rampAController);
            finalJson =
                vm.serializeAddress(objectKey, string.concat(prefix, "ParameterRegistry"), pool.parameterRegistry);
            finalJson = vm.serializeAddress(objectKey, string.concat(prefix, "Keeper"), pool.keeper);
        }

        // Write complete JSON once at the end
        vm.writeJson(finalJson, path);

        console2.log("  Updated artifacts at:", path);
    }
}
