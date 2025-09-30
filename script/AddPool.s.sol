// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { stdJson } from "forge-std/StdJson.sol";
import { console2 } from "forge-std/console2.sol";

import { Deploy } from "script/Deploy.sol";
import { Pool } from "script/Pool.sol";
import { MockToken } from "../src/mock/MockToken.sol";
import { SelfPeggingAsset } from "../src/SelfPeggingAsset.sol";
import { ChainlinkOracleProvider } from "../src/misc/ChainlinkOracleProvider.sol";
import "@chainlink/contracts/shared/interfaces/AggregatorV3Interface.sol";
import { SelfPeggingAssetFactory } from "../src/SelfPeggingAssetFactory.sol";
import { ChainlinkCompositeOracleProvider } from "../src/misc/ChainlinkCompositeOracleProvider.sol";
import { MockExchangeRateProvider } from "../src/mock/MockExchangeRateProvider.sol";

contract AddPool is Deploy, Pool {
    struct JSONData {
        address Factory;
        address LPTokenBeacon;
        address SelfPeggingAssetBeacon;
        address WETHwstETHPool;
        address WETHwstETHPoolLPToken;
        address WETHwstETHPoolWLPToken;
        address WLPTokenBeacon;
        address Zap;
        address wstETHweETHPool;
        address wstETHweETHPoolLPToken;
        address wstETHweETHPoolWLPToken;
    }

    struct JSONDataTestnet {
        address Factory;
        address LPTokenBeacon;
        address SelfPeggingAssetBeacon;
        address USDC;
        address USDT;
        address WLPTokenBeacon;
        address Zap;
    }

    function init() internal {
        if (vm.envUint("HEX_PRIV_KEY") == 0) revert("No private key found");
        deployerPrivateKey = vm.envUint("HEX_PRIV_KEY");
        DEPLOYER = vm.addr(deployerPrivateKey);
    }

    function run() public payable {
        init();
        loadConfig();

        vm.startBroadcast(deployerPrivateKey);

        uint256 chainId = getChainId();
        string memory networkName = getNetworkName(chainId);
        string memory path = string.concat("./broadcast/", networkName, ".json");

        string memory json = vm.readFile(path);
        bytes memory data = vm.parseJson(json);

        if (chainId == 8453) {
            JSONData memory jsonData = abi.decode(data, (JSONData));

            factory = SelfPeggingAssetFactory(jsonData.Factory);
            selfPeggingAssetBeacon = jsonData.SelfPeggingAssetBeacon;
            lpTokenBeacon = jsonData.LPTokenBeacon;
            wlpTokenBeacon = jsonData.WLPTokenBeacon;
            zap = jsonData.Zap;

            address wstETHTostETHFeed = 0xB88BAc61a4Ca37C43a3725912B1f472c9A5bc061;
            address weETHToETHFeed = 0xFC1415403EbB0c693f9a7844b92aD2Ff24775C65;
            address stETHToETHFeed = 0xf586d0728a47229e747d824a939000Cf21dEF5A0;

            address wstETH = 0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452;
            address weETH = 0x04C0599Ae5A44757c0af6F9eC3b93da8976c150A;
            address weth = 0x4200000000000000000000000000000000000006;

            uint256 ethAmount = 0.0025e18;

            address sequencer = 0xBCF85224fc0756B9Fa45aA7892530B47e10b6433;

            // create chainlink oracle
            address wstETHTostETHOracle = address(
                new ChainlinkOracleProvider(
                    AggregatorV3Interface(sequencer), AggregatorV3Interface(wstETHTostETHFeed), 24 hours
                )
            );

            ChainlinkCompositeOracleProvider.Config[] memory configs = new ChainlinkCompositeOracleProvider.Config[](2);
            configs[0] = ChainlinkCompositeOracleProvider.Config({
                feed: AggregatorV3Interface(weETHToETHFeed),
                maxStalePeriod: 24 hours,
                assetDecimals: 18,
                isInverted: false
            });
            configs[1] = ChainlinkCompositeOracleProvider.Config({
                feed: AggregatorV3Interface(stETHToETHFeed),
                maxStalePeriod: 24 hours,
                assetDecimals: 18,
                isInverted: true
            });

            ChainlinkCompositeOracleProvider weETHTostETHOracle =
                new ChainlinkCompositeOracleProvider(AggregatorV3Interface(sequencer), configs);

            (address lpToken, address pool, address wlpToken,) =
                createChainlinkPool(wstETH, weETH, address(wstETHTostETHOracle), address(weETHTostETHOracle));

            initialMint(wstETH, weETH, ethAmount, ethAmount, SelfPeggingAsset(pool));

            ChainlinkCompositeOracleProvider.Config[] memory configs2 = new ChainlinkCompositeOracleProvider.Config[](1);
            configs2[0] = ChainlinkCompositeOracleProvider.Config({
                feed: AggregatorV3Interface(stETHToETHFeed),
                maxStalePeriod: 24 hours,
                assetDecimals: 18,
                isInverted: true
            });

            ChainlinkCompositeOracleProvider ETHTostETHOracle =
                new ChainlinkCompositeOracleProvider(AggregatorV3Interface(sequencer), configs2);

            (address lpToken2, address pool2, address wlpToken2,) =
                createChainlinkPool(weth, wstETH, address(ETHTostETHOracle), address(wstETHTostETHOracle));

            initialMint(weth, wstETH, ethAmount, ethAmount, SelfPeggingAsset(pool2));

            vm.writeJson(vm.serializeAddress("contracts", "Factory", address(factory)), path);
            vm.writeJson(vm.serializeAddress("contracts", "LPTokenBeacon", lpTokenBeacon), path);
            vm.writeJson(vm.serializeAddress("contracts", "SelfPeggingAssetBeacon", selfPeggingAssetBeacon), path);
            vm.writeJson(vm.serializeAddress("contracts", "WETHwstETHPool", pool2), path);
            vm.writeJson(vm.serializeAddress("contracts", "WETHwstETHPoolLPToken", lpToken2), path);
            vm.writeJson(vm.serializeAddress("contracts", "WETHwstETHPoolWLPToken", wlpToken2), path);
            vm.writeJson(vm.serializeAddress("contracts", "WLPTokenBeacon", wlpTokenBeacon), path);
            vm.writeJson(vm.serializeAddress("contracts", "Zap", zap), path);
            vm.writeJson(vm.serializeAddress("contracts", "wstETHweETHPool", pool), path);
            vm.writeJson(vm.serializeAddress("contracts", "wstETHweETHPoolLPToken", lpToken), path);
            vm.writeJson(vm.serializeAddress("contracts", "wstETHweETHPoolWLPToken", wlpToken), path);
        } else if (chainId == 84_532) {
            JSONDataTestnet memory jsonData = abi.decode(data, (JSONDataTestnet));

            factory = SelfPeggingAssetFactory(jsonData.Factory);
            selfPeggingAssetBeacon = jsonData.SelfPeggingAssetBeacon;
            lpTokenBeacon = jsonData.LPTokenBeacon;
            wlpTokenBeacon = jsonData.WLPTokenBeacon;
            zap = jsonData.Zap;

            vm.writeJson(vm.serializeAddress("contracts", "Zap", zap), path);
            vm.writeJson(vm.serializeAddress("contracts", "Factory", address(factory)), path);
            vm.writeJson(vm.serializeAddress("contracts", "SelfPeggingAssetBeacon", selfPeggingAssetBeacon), path);
            vm.writeJson(vm.serializeAddress("contracts", "LPTokenBeacon", lpTokenBeacon), path);
            vm.writeJson(vm.serializeAddress("contracts", "WLPTokenBeacon", wlpTokenBeacon), path);
            vm.writeJson(vm.serializeAddress("contracts", "USDC", jsonData.USDC), path);
            vm.writeJson(vm.serializeAddress("contracts", "USDT", jsonData.USDT), path);

            uint256 amount = 0.0026e18;

            MockToken weth = new MockToken("WETH", "WETH", 18);
            MockToken wstETH = new MockToken("wstETH", "wstETH", 18);
            MockToken weETH = new MockToken("weETH", "weETH", 18);

            MockToken(weth).mint(DEPLOYER, amount);
            MockToken(wstETH).mint(DEPLOYER, amount * 2);
            MockToken(weETH).mint(DEPLOYER, amount);

            MockExchangeRateProvider WETHTostETHOracle = new MockExchangeRateProvider(1e18, 18);
            MockExchangeRateProvider wstETHTostETHOracle = new MockExchangeRateProvider(1.1e18, 18);
            MockExchangeRateProvider weETHTostETHOracle = new MockExchangeRateProvider(1.2e18, 18);

            (address lpToken, address pool, address wlpToken,) = createMockExchangeRatePool(
                address(weth), address(wstETH), address(WETHTostETHOracle), address(wstETHTostETHOracle)
            );

            initialMint(address(weth), address(wstETH), amount, amount, SelfPeggingAsset(pool));

            (address lpToken2, address pool2, address wlpToken2,) = createMockExchangeRatePool(
                address(wstETH), address(weETH), address(wstETHTostETHOracle), address(weETHTostETHOracle)
            );
            initialMint(address(wstETH), address(weETH), amount, amount, SelfPeggingAsset(pool2));

            vm.writeJson(vm.serializeAddress("contracts", "wstETH", address(wstETH)), path);
            vm.writeJson(vm.serializeAddress("contracts", "weETH", address(weETH)), path);
            vm.writeJson(vm.serializeAddress("contracts", "WETH", address(weth)), path);
            vm.writeJson(vm.serializeAddress("contracts", "WETHwstETHPool", pool), path);
            vm.writeJson(vm.serializeAddress("contracts", "wstETHweETHPool", pool2), path);
            vm.writeJson(vm.serializeAddress("contracts", "WETHwstETHPoolLPToken", lpToken), path);
            vm.writeJson(vm.serializeAddress("contracts", "wstETHweETHPoolLPToken", lpToken2), path);
            vm.writeJson(vm.serializeAddress("contracts", "WETHwstETHPoolWLPToken", wlpToken), path);
            vm.writeJson(vm.serializeAddress("contracts", "wstETHweETHPoolWLPToken", wlpToken2), path);
        }

        vm.stopBroadcast();
    }
}
