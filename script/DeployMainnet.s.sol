// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console2 } from "forge-std/console2.sol";
import { CoreDeployer } from "./base/CoreDeployer.sol";
import { PoolDeployer } from "./base/PoolDeployer.sol";

/**
 * @title DeployMainnet
 * @notice Main script for deploying Tapio protocol + pools on any EVM chain
 * @dev Configuration-driven deployment using JSON configs
 */
contract DeployMainnet is CoreDeployer, PoolDeployer {
    function run() public payable {
        deployerPrivateKey = vm.envUint("DEV_PROD_KEY");
        DEPLOYER = vm.addr(deployerPrivateKey);
        GOVERNOR = vm.addr(deployerPrivateKey);

        uint256 chainId = block.chainid;
        string memory networkName = getNetworkName(chainId);

        console2.log("====================================");
        console2.log("Deploying Tapio v1.0.2 (audited)");
        console2.log("====================================");
        console2.log("Chain ID:", chainId);
        console2.log("Network:", networkName);
        console2.log("Deployer:", DEPLOYER);

        // load configs
        loadChainConfig(networkName, "mainnet");
        loadPoolConfigs(networkName, "mainnet");
        verifyCreateX();
        loadSaltIdentifiers();

        // deploy
        vm.startBroadcast(deployerPrivateKey);

        console2.log("\n--- Core protocol ---");
        deployBeacons();

        // load factory defaults
        FactoryDefaults memory factoryDefaults = loadFactoryDefaults();
        deployFactory(factoryDefaults);

        deployZap();

        console2.log("\n--- Pools ---");
        setPoolFactory(factory);
        deployPools();

        console2.log("\n--- Initial minting (if configured) ---");
        _runInitialMints();

        vm.stopBroadcast();

        // save artifacts
        console2.log("\n--- Saving artifacts ---");
        saveDeploymentArtifacts(networkName);
    }

    /**
     * @notice Save deployment artifacts to JSON files
     * @dev Creates 2 files: <network>.json (proxies/beacons) and <network>.impl.json (implementations)
     */
    function saveDeploymentArtifacts(string memory networkName) internal {
        string memory path = string.concat("./broadcast/", networkName, ".json");
        string memory pathImpl = string.concat("./broadcast/", networkName, ".impl.json");

        // core infrastructure
        vm.writeJson(vm.serializeAddress("contracts", "Factory", address(factory)), path);
        vm.writeJson(vm.serializeAddress("contracts", "Zap", zap), path);
        vm.writeJson(vm.serializeAddress("contracts", "SelfPeggingAssetBeacon", selfPeggingAssetBeacon), path);
        vm.writeJson(vm.serializeAddress("contracts", "SPATokenBeacon", spaTokenBeacon), path);
        vm.writeJson(vm.serializeAddress("contracts", "WSPATokenBeacon", wspaTokenBeacon), path);
        vm.writeJson(vm.serializeAddress("contracts", "RampAControllerBeacon", rampAControllerBeacon), path);

        // oracles (deployed per-pool for Oracle token types)
        for (uint256 i = 0; i < deployedOracles.length; i++) {
            DeployedOracle memory oracle = getDeployedOracle(i);
            vm.writeJson(vm.serializeAddress("contracts", oracle.name, oracle.oracle), path);
        }

        // pools
        for (uint256 i = 0; i < deployedPools.length; i++) {
            DeployedPool memory pool = getDeployedPool(i);
            string memory prefix = string.concat(pool.name);

            vm.writeJson(vm.serializeAddress("contracts", string.concat(prefix, "Pool"), pool.selfPeggingAsset), path);
            vm.writeJson(vm.serializeAddress("contracts", string.concat(prefix, "SPAToken"), pool.poolToken), path);
            vm.writeJson(
                vm.serializeAddress("contracts", string.concat(prefix, "WSPAToken"), pool.wrappedPoolToken), path
            );
            vm.writeJson(
                vm.serializeAddress("contracts", string.concat(prefix, "RampAController"), pool.rampAController), path
            );
            vm.writeJson(
                vm.serializeAddress("contracts", string.concat(prefix, "ParameterRegistry"), pool.parameterRegistry),
                path
            );
            vm.writeJson(vm.serializeAddress("contracts", string.concat(prefix, "Keeper"), pool.keeper), path);
        }

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
