// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { SelfPeggingAssetFactory } from "../src/SelfPeggingAssetFactory.sol";

contract Config is Script {
    bool testnet = vm.envBool("TESTNET");

    uint256 deployerPrivateKey;

    address GOVERNOR;
    address DEPLOYER;

    address usdc;
    address usdt;

    SelfPeggingAssetFactory factory;
    address selfPeggingAssetBeacon;
    address spaTokenBeacon;
    address wspaTokenBeacon;
    address rampAControllerBeacon;
    address keeperImplementation;
    address parameterRegistryBeacon;
    address zap;

    struct JSONData {
        address Factory;
        address SPATokenBeacon;
        address SelfPeggingAssetBeacon;
        address USDC;
        address USDT;
        address WSPATokenBeacon;
        address Zap;
    }

    function loadConfig() internal view {
        if (!testnet) {
            // POPULATE ADDRESSES BASED ON CHAIN ID
            // usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
            // usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        }
    }

    function getNetworkName(uint256 chainId) internal pure returns (string memory) {
        if (chainId == 84_532) return "basesepolia";
        else if (chainId == 421_614) return "arbitrumsepolia";
        else if (chainId == 11_155_420) return "opsepolia";
        else if (chainId == 10_143) return "monadtestnet";
        else if (chainId == 80_069) return "bera-bepolia";
        else if (chainId == 998) return "hyper-testnet";
        else if (chainId == 42_161) return "arbitrum";
        else if (chainId == 5) return "base";
        else if (chainId == 10) return "optimism";
        else revert("Invalid chain ID");
    }

    function getChainId() public view returns (uint256) {
        uint256 chainId = block.chainid;
        return chainId;
    }
}
