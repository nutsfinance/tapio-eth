// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Vm } from "forge-std/Vm.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { console } from "forge-std/console.sol";
import { Config } from "script/Config.sol";
import { SelfPeggingAssetFactory } from "../src/SelfPeggingAssetFactory.sol";
import { SelfPeggingAsset } from "../src/SelfPeggingAsset.sol";
import { MockToken } from "../src/mock/MockToken.sol";
import {KeeperController} from "../src/periphery/KeeperController.sol";

contract Pool is Config {
    function createStandardPool() internal returns (address, address, address) {
        console.log("---------------");
        console.log("create-pool-logs");
        console.log("---------------");
        

        KeeperController _keeperController = new KeeperController(DEPLOYER,address(factory));
        // add support for array of Keepers from env
        _keeperController.setKeeper(vm.envAddress("INITIAL_KEEPER"), true);        
        keeperController = address(_keeperController);

        SelfPeggingAssetFactory.CreatePoolArgument memory arg = SelfPeggingAssetFactory.CreatePoolArgument({
            tokenA: usdc,
            tokenB: usdt,
            tokenAType: SelfPeggingAssetFactory.TokenType.Standard,
            tokenAOracle: address(0),
            tokenARateFunctionSig: "",
            tokenADecimalsFunctionSig: "",
            tokenBType: SelfPeggingAssetFactory.TokenType.Standard,
            tokenBOracle: address(0),
            tokenBRateFunctionSig: "",
            tokenBDecimalsFunctionSig: "",
            keeperController: keeperController
        });

        vm.recordLogs();
        factory.createPool(arg);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 eventSig = keccak256("PoolCreated(address,address,address,address)");

        address decodedPoolToken;
        address decodedSelfPeggingAsset;
        address decodedWrappedPoolToken;

        for (uint256 i = 0; i < entries.length; i++) {
            Vm.Log memory log = entries[i];
            // console.log("log topic");
            // console.logBytes32( log.topics[0]);

            if (log.topics[0] == eventSig) {
                console.log("pool created event detected");
                (decodedPoolToken, decodedSelfPeggingAsset, decodedWrappedPoolToken,) =
                    abi.decode(log.data, (address, address, address,address));
            }
        }

        return (decodedPoolToken, decodedSelfPeggingAsset, decodedWrappedPoolToken);
    }

    function initialMint(uint256 usdcAmount, uint256 usdtAmount, SelfPeggingAsset selfPeggingAsset) internal {
        console.log("---------------");
        console.log("initial-mint-logs");
        console.log("---------------");

        MockToken(usdc).approve(address(selfPeggingAsset), usdcAmount);
        MockToken(usdt).approve(address(selfPeggingAsset), usdtAmount);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = usdcAmount;
        amounts[1] = usdtAmount;

        selfPeggingAsset.mint(amounts, 0);
    }
}
