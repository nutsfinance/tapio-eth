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
import {RampAController} from "../src/periphery/RampAController.sol";
import {KeeperController} from "../src/periphery/KeeperController.sol";
import {IRampAController} from "../src/interfaces/IRampAController.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract Testnet is Deploy, Setup, Pool {
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
        lpTokenBeacon = jsonData.LPTokenBeacon;
        wlpTokenBeacon = jsonData.WLPTokenBeacon;
        usdc = jsonData.USDC;
        usdt = jsonData.USDT;

        console.log("usdc", usdc);
        console.log("usdt", usdt);

        (, address selfPeggingAsset,) = createStandardPool();
        console.log("selfPeggingAsset", selfPeggingAsset);

        address rampAController = address(SelfPeggingAsset(selfPeggingAsset).rampAController());
        console.log("rampAController : ", rampAController);
        
        uint256 amount = 10 ether;

        MockToken(usdc).mint(DEPLOYER, amount);
        MockToken(usdt).mint(DEPLOYER, amount);

        initialMint(amount, amount, SelfPeggingAsset(selfPeggingAsset));

        address keeperController=address(RampAController(rampAController).keeperController());

        console.log("keeperController", keeperController );
        KeeperController(keeperController).setRampAController(rampAController);
        KeeperController(keeperController).setSpa(address(selfPeggingAsset));        
        KeeperController(keeperController).setSwapFeeCap(20,10000);

        KeeperController(keeperController).setRampAController(rampAController);
        KeeperController(keeperController).setSpa(address(selfPeggingAsset));

        vm.stopBroadcast();


    }
}
