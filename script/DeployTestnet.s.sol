// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console2 } from "forge-std/console2.sol";
import { CoreDeployer } from "./base/CoreDeployer.sol";
import { PoolDeployer } from "./base/PoolDeployer.sol";

contract DeployTestnet is CoreDeployer, PoolDeployer {
    function run() public payable {
        deployerPrivateKey = vm.envUint("DEV_PROD_KEY");
        GOVERNOR = vm.addr(deployerPrivateKey);
        DEPLOYER = vm.addr(deployerPrivateKey);

        uint256 chainId = block.chainid;
        string memory networkName = getNetworkName(chainId);

        console2.log("====================================");
        console2.log("Deploying Tapio Protocol (Testnet)");
        console2.log("====================================");
        console2.log("Chain ID:", chainId);
        console2.log("Network:", networkName);
        console2.log("Deployer:", DEPLOYER);

        // configs
        loadChainConfig(networkName, "testnet");
        loadPoolConfigs(networkName, "testnet");
        verifyCreateX();
        loadSaltIdentifiers();

        vm.startBroadcast(deployerPrivateKey);

        console2.log("\n--- Core Infrastructure ---");
        deployBeacons();

        FactoryDefaults memory factoryDefaults = loadFactoryDefaults();
        deployFactory(factoryDefaults);

        deployZap();

        console2.log("\n--- Pools ---");
        setPoolFactory(factory);
        deployPools();

        vm.stopBroadcast();

        console2.log("\n--- Saving Artifacts ---");
        saveDeploymentArtifacts(networkName);
    }

    function getNetworkName(uint256 chainId) internal pure override returns (string memory) {
        if (chainId == 11_155_111) return "sepolia";
        if (chainId == 84_532) return "base-sepolia";
        if (chainId == 421_614) return "arbitrum-sepolia";
        if (chainId == 11_155_420) return "optimism-sepolia";
        revert("Unsupported testnet chain ID");
    }

    function saveDeploymentArtifacts(string memory networkName) internal {
        string memory path = string.concat("./broadcast/testnet-", networkName, ".json");
        string memory pathImpl = string.concat("./broadcast/testnet-", networkName, ".impl.json");

        // Core infrastructure
        vm.writeJson(vm.serializeAddress("contracts", "Factory", address(factory)), path);
        vm.writeJson(vm.serializeAddress("contracts", "Zap", zap), path);
        vm.writeJson(vm.serializeAddress("contracts", "SelfPeggingAssetBeacon", selfPeggingAssetBeacon), path);
        vm.writeJson(vm.serializeAddress("contracts", "SPATokenBeacon", spaTokenBeacon), path);
        vm.writeJson(vm.serializeAddress("contracts", "WSPATokenBeacon", wspaTokenBeacon), path);
        vm.writeJson(vm.serializeAddress("contracts", "RampAControllerBeacon", rampAControllerBeacon), path);

        // Pools (all components)
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

        // === Implementation file (implementation contracts only) ===

        string memory implJson = "impl";
        vm.serializeAddress(implJson, "Factory", factoryImplementation);
        vm.serializeAddress(implJson, "SelfPeggingAsset", selfPeggingAssetImplementation);
        vm.serializeAddress(implJson, "SPAToken", spaTokenImplementation);
        vm.serializeAddress(implJson, "WSPAToken", wspaTokenImplementation);
        vm.serializeAddress(implJson, "RampAController", rampAControllerImplementation);
        string memory finalImpl = vm.serializeAddress(implJson, "Keeper", keeperImplementation);
        vm.writeJson(finalImpl, pathImpl);

        console2.log("  Artifacts saved to:", path);
        console2.log("  Implementation artifacts saved to:", pathImpl);
    }
}
