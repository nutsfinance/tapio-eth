// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { stdJson } from "forge-std/StdJson.sol";
import { console } from "forge-std/console.sol";

import { Deploy } from "script/Deploy.sol";
import { Pool } from "script/Pool.sol";
import { MockToken } from "../src/mock/MockToken.sol";
import { SelfPeggingAsset } from "../src/SelfPeggingAsset.sol";
import { MockExchangeRateProvider } from "../src/mock/MockExchangeRateProvider.sol";

contract Testnet is Deploy, Pool {
    function init() internal {
        if (vm.envUint("HEX_PRIV_KEY") == 0) revert("No private key found");
        deployerPrivateKey = vm.envUint("HEX_PRIV_KEY");
        GOVERNOR = vm.addr(deployerPrivateKey);
        DEPLOYER = vm.addr(deployerPrivateKey);
    }

    function run() public payable {
        init();
        loadConfig();

        vm.startBroadcast(deployerPrivateKey);
        uint256 chainId = getChainId();
        string memory networkName = getNetworkName(chainId);
        string memory path = string.concat("./broadcast/", networkName, ".json");

        deployBeacons();
        deployFactory(networkName);
        deployZap();

        if (chainId == 57_054) {
            // sonic testnet
            address wS = 0x98e6a95a4B225b60456FC5dEDde3E4b8B7655C6B;
            address stS = 0x6A074e2158e9C0f7A2e738f4919DC42316d153B0;
            address wOS = 0xa22a772520aaaaCEaD463593871C34e6A4422c83;

            MockExchangeRateProvider wSToS = new MockExchangeRateProvider(1e18, 18);
            MockExchangeRateProvider stSToS = new MockExchangeRateProvider(1.01558e18, 18);
            MockExchangeRateProvider OSToS = new MockExchangeRateProvider(1.004739e18, 18);

            uint256 amount = 10_000e18;
            uint256 amountToMint = 100e18;

            MockToken(wS).mint(DEPLOYER, amount);
            MockToken(stS).mint(DEPLOYER, amount);
            MockToken(wOS).mint(DEPLOYER, amount);

            (
                address wSstSSPAToken,
                address wSstSPool,
                address wSstSWSPAToken,
                address wSstSRampAController,
                address wSstSKeeper
            ) = createMockExchangeRatePool(address(wS), address(stS), address(wSToS), address(stSToS));

            initialMint(address(wS), address(stS), amountToMint, amountToMint, SelfPeggingAsset(wSstSPool));

            (
                address wSwOSSPAToken,
                address wSwOSPool,
                address wSwOSWSPAToken,
                address wSwOSRampAController,
                address wSwOSKeeper
            ) = createMockExchangeRatePool(address(wS), address(wOS), address(wSToS), address(OSToS));
            initialMint(address(wS), address(wOS), amountToMint, amountToMint, SelfPeggingAsset(wSwOSPool));

            vm.writeJson(vm.serializeAddress("contracts", "Zap", zap), path);
            vm.writeJson(vm.serializeAddress("contracts", "Factory", address(factory)), path);
            vm.writeJson(
                vm.serializeAddress("contracts", "FactoryImplementation", address(factoryImplementation)), path
            );
            vm.writeJson(vm.serializeAddress("contracts", "SelfPeggingAssetBeacon", selfPeggingAssetBeacon), path);
            vm.writeJson(vm.serializeAddress("contracts", "SPATokenBeacon", spaTokenBeacon), path);
            vm.writeJson(vm.serializeAddress("contracts", "WSPATokenBeacon", wspaTokenBeacon), path);
            vm.writeJson(vm.serializeAddress("contracts", "RampAControllerBeacon", rampAControllerBeacon), path);
            vm.writeJson(vm.serializeAddress("contracts", "KeeperImplementation", keeperImplementation), path);
            vm.writeJson(vm.serializeAddress("contracts", "wS", address(wS)), path);
            vm.writeJson(vm.serializeAddress("contracts", "stS", address(stS)), path);
            vm.writeJson(vm.serializeAddress("contracts", "wOS", address(wOS)), path);
            vm.writeJson(vm.serializeAddress("contracts", "wSstSPool", address(wSstSPool)), path);
            vm.writeJson(vm.serializeAddress("contracts", "wSstSPoolSPAToken", wSstSSPAToken), path);
            vm.writeJson(vm.serializeAddress("contracts", "wSstSPoolWSPAToken", wSstSWSPAToken), path);
            vm.writeJson(vm.serializeAddress("contracts", "wSstSRampAController", wSstSRampAController), path);
            vm.writeJson(vm.serializeAddress("contracts", "wSstSKeeper", wSstSKeeper), path);
            vm.writeJson(vm.serializeAddress("contracts", "wSwOSPool", address(wSwOSPool)), path);
            vm.writeJson(vm.serializeAddress("contracts", "wSwOSPoolSPAToken", wSwOSSPAToken), path);
            vm.writeJson(vm.serializeAddress("contracts", "wSwOSPoolWSPAToken", wSwOSWSPAToken), path);
            vm.writeJson(vm.serializeAddress("contracts", "wSwOSRampAController", wSwOSRampAController), path);
            vm.writeJson(vm.serializeAddress("contracts", "wSwOSKeeper", wSwOSKeeper), path);
        }

        vm.stopBroadcast();
    }
}
