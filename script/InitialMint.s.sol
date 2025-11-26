// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SelfPeggingAsset } from "../src/SelfPeggingAsset.sol";
import { ChainConfig } from "./base/ChainConfig.sol";

contract InitialMintScript is Script, ChainConfig {
    using stdJson for string;

    function run() external {
        deployerPrivateKey = vm.envUint("DEV_PROD_KEY");
        DEPLOYER = vm.addr(deployerPrivateKey);

        uint256 chainId = block.chainid;
        string memory networkName = getNetworkName(chainId);

        // load configs so pools[] is populated
        loadChainConfig(networkName, "mainnet");
        loadPoolConfigs(networkName, "mainnet");

        // read broadcast file written by DeployMainnet
        string memory broadcastPath = string.concat("./broadcast/", networkName, ".json");
        require(vm.exists(broadcastPath), "Broadcast file not found; deploy first");

        string memory broadcastJson = vm.readFile(broadcastPath);

        console2.log("Starting initial mint script on", networkName);

        vm.startBroadcast(deployerPrivateKey);

        for (uint256 i = 0; i < getPoolCount(); i++) {
            PoolConfig memory p = getPool(i);

            if (!p.enabled) continue;
            if (!p.initialMint.enabled) continue;

            console2.log("\n--- Initial mint for pool:", p.name);

            // Resolve deployed SelfPeggingAsset address from broadcast file
            string memory poolKey = string.concat(".", p.name, "Pool");
            address spaAddr = broadcastJson.readAddress(poolKey);
            require(spaAddr != address(0), "SPA address not found in broadcast");
            require(SelfPeggingAsset(spaAddr).totalSupply() == 0, "Already initialized");

            address tokenA = SelfPeggingAsset(spaAddr).tokens(0);
            address tokenB = SelfPeggingAsset(spaAddr).tokens(1);

            console2.log(" SPA:", spaAddr);
            console2.log(" tokenA:", tokenA, " amount:", p.initialMint.amountTokenA);
            console2.log(" tokenB:", tokenB, " amount:", p.initialMint.amountTokenB);

            // Approve tokens to SPA
            if (p.initialMint.amountTokenA > 0) {
                IERC20(tokenA).approve(spaAddr, p.initialMint.amountTokenA);
            }
            if (p.initialMint.amountTokenB > 0) {
                IERC20(tokenB).approve(spaAddr, p.initialMint.amountTokenB);
            }

            uint256[] memory _amounts = new uint256[](2);
            _amounts[0] = p.initialMint.amountTokenA;
            _amounts[1] = p.initialMint.amountTokenB;

            // Execute mint (deployer must hold those tokens beforehand)
            SelfPeggingAsset(spaAddr).mint(_amounts, 0);

            console2.log("  Mint executed for", p.name);
        }

        vm.stopBroadcast();
    }
}
