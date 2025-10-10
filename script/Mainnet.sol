// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { stdJson } from "forge-std/StdJson.sol";
import { console } from "forge-std/console.sol";

import { Deploy } from "script/Deploy.sol";
import { Pool } from "script/Pool.sol";
import { MockToken } from "../src/mock/MockToken.sol";
import { SelfPeggingAsset } from "../src/SelfPeggingAsset.sol";
import { ChainlinkOracleProvider } from "../src/misc/ChainlinkOracleProvider.sol";
import "@chainlink/contracts/shared/interfaces/AggregatorV3Interface.sol";

contract Mainnet is Deploy, Pool {
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

        deployBeacons();
        deployFactory();
        deployZap();

        uint256 chainId = getChainId();
        string memory networkName = getNetworkName(chainId);
        string memory path = string.concat("./broadcast/", networkName, ".json");

        if (chainId == 8453) {
            // base mainnet
            address wstETHFeed = 0x43a5C292A453A3bF3606fa856197f09D7B74251a;
            address weETHFeed = 0xFC1415403EbB0c693f9a7844b92aD2Ff24775C65;
            address cbETHFeed = 0x806b4Ac04501c29769051e42783cF04dCE41440b;

            address weth = 0x4200000000000000000000000000000000000006;
            address wstETH = 0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452;
            address weETH = 0x04C0599Ae5A44757c0af6F9eC3b93da8976c150A;
            address cbETH = 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22;
            address usdc = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
            address usdt = 0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2;

            uint256 ethAmount = 0.0027e18;
            uint256 usdAmount = 5e6;

            address sequencer = 0xBCF85224fc0756B9Fa45aA7892530B47e10b6433;

            // create chainlink oracle
            address wstETHOracle = address(
                new ChainlinkOracleProvider(
                    AggregatorV3Interface(sequencer), AggregatorV3Interface(wstETHFeed), 24 hours
                )
            );

            address weETHOracle = address(
                new ChainlinkOracleProvider(
                    AggregatorV3Interface(sequencer), AggregatorV3Interface(weETHFeed), 24 hours
                )
            );

            address cbETHOracle = address(
                new ChainlinkOracleProvider(
                    AggregatorV3Interface(sequencer), AggregatorV3Interface(cbETHFeed), 24 hours
                )
            );

            (, address pool,,) = createChainlinkPool(weth, wstETH, wstETHOracle);

            initialMint(weth, wstETH, ethAmount, ethAmount, SelfPeggingAsset(pool));

            (, pool,,) = createChainlinkPool(weth, weETH, weETHOracle);

            initialMint(weth, weETH, ethAmount, ethAmount, SelfPeggingAsset(pool));

            (, pool,,) = createChainlinkPool(weth, cbETH, cbETHOracle);

            initialMint(weth, cbETH, ethAmount, ethAmount, SelfPeggingAsset(pool));

            (, pool,,) = createStandardPool(usdc, usdt);

            initialMint(usdc, usdt, usdAmount, usdAmount, SelfPeggingAsset(pool));
        } else if (chainId == 146) {
            // sonic mainnet

            address ws = 0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38;
            address stS = 0xE5DA20F15420aD15DE0fa650600aFc998bbE3955;
            address wOS = 0x9F0dF7799f6FDAd409300080cfF680f5A23df4b1;

            (address wSstSLpToken, address wSstSPool, address wSstSWlpToken,) = createStandardAndERC4626Pool(ws, stS);

            initialMint(ws, stS, 5e18, 4.9e18, SelfPeggingAsset(wSstSPool));

            (address wSwOSLpToken, address wSwOSPool, address wSwOSWlpToken,) = createStandardAndERC4626Pool(ws, wOS);

            initialMint(ws, wOS, 5e18, 3e18, SelfPeggingAsset(wSwOSPool));

            vm.writeJson(vm.serializeAddress("contracts", "Zap", zap), path);
            vm.writeJson(vm.serializeAddress("contracts", "Factory", address(factory)), path);
            vm.writeJson(vm.serializeAddress("contracts", "SelfPeggingAssetBeacon", selfPeggingAssetBeacon), path);
            vm.writeJson(vm.serializeAddress("contracts", "LPTokenBeacon", lpTokenBeacon), path);
            vm.writeJson(vm.serializeAddress("contracts", "WLPTokenBeacon", wlpTokenBeacon), path);
            vm.writeJson(vm.serializeAddress("contracts", "wS", address(ws)), path);
            vm.writeJson(vm.serializeAddress("contracts", "stS", address(stS)), path);
            vm.writeJson(vm.serializeAddress("contracts", "wOS", address(wOS)), path);
            vm.writeJson(vm.serializeAddress("contracts", "wSstSPool", address(wSstSPool)), path);
            vm.writeJson(vm.serializeAddress("contracts", "wSstSPoolLPToken", wSstSLpToken), path);
            vm.writeJson(vm.serializeAddress("contracts", "wSstSPoolWLPToken", wSstSWlpToken), path);
            vm.writeJson(vm.serializeAddress("contracts", "wSwOSPool", address(wSwOSPool)), path);
            vm.writeJson(vm.serializeAddress("contracts", "wSwOSPoolLPToken", wSwOSLpToken), path);
            vm.writeJson(vm.serializeAddress("contracts", "wSwOSPoolWLPToken", wSwOSWlpToken), path);
        } else if (chainId == 1) {
            // mainnet

            address usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
            address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

            (address usdcusdtLpToken, address usdcusdtPool, address usdcusdtWlpToken,) = createStandardPool(usdc, usdt);

            // initialMint(usdc, usdt, 50e6, 50e6, SelfPeggingAsset(usdcusdtPool));

            vm.writeJson(vm.serializeAddress("contracts", "Zap", zap), path);
            vm.writeJson(vm.serializeAddress("contracts", "Factory", address(factory)), path);
            vm.writeJson(vm.serializeAddress("contracts", "SelfPeggingAssetBeacon", selfPeggingAssetBeacon), path);
            vm.writeJson(vm.serializeAddress("contracts", "LPTokenBeacon", lpTokenBeacon), path);
            vm.writeJson(vm.serializeAddress("contracts", "WLPTokenBeacon", wlpTokenBeacon), path);
            vm.writeJson(vm.serializeAddress("contracts", "usdc", address(usdc)), path);
            vm.writeJson(vm.serializeAddress("contracts", "usdt", address(usdt)), path);
            vm.writeJson(vm.serializeAddress("contracts", "usdcusdtPool", address(usdcusdtPool)), path);
            vm.writeJson(vm.serializeAddress("contracts", "usdcusdtPoolLPToken", usdcusdtLpToken), path);
            vm.writeJson(vm.serializeAddress("contracts", "usdcusdtPoolWLPToken", usdcusdtWlpToken), path);
        } else if (chainId == 999) {
            // hyper evm mainnet

            address behype = 0xd8FC8F0b03eBA61F64D08B0bef69d80916E5DdA9;
            address whype = 0x5555555555555555555555555555555555555555;
            (address whypeBehypeLpToken, address whypeBehypePool, address whypeBehypeWlpToken,) = createExchangeRatePool(
                whype,
                behype,
                0xCeaD893b162D38e714D82d06a7fe0b0dc3c38E0b,
                bytes4(abi.encodeWithSignature("exchangeRatio()")),
                18
            );

            vm.writeJson(vm.serializeAddress("contracts", "Zap", zap), path);
            vm.writeJson(vm.serializeAddress("contracts", "Factory", address(factory)), path);
            vm.writeJson(vm.serializeAddress("contracts", "SelfPeggingAssetBeacon", selfPeggingAssetBeacon), path);
            vm.writeJson(vm.serializeAddress("contracts", "LPTokenBeacon", lpTokenBeacon), path);
            vm.writeJson(vm.serializeAddress("contracts", "WLPTokenBeacon", wlpTokenBeacon), path);
            vm.writeJson(vm.serializeAddress("contracts", "BeHype", address(behype)), path);
            vm.writeJson(vm.serializeAddress("contracts", "WHype", address(whype)), path);
            vm.writeJson(vm.serializeAddress("contracts", "WhypeBehypePool", address(whypeBehypePool)), path);
            vm.writeJson(vm.serializeAddress("contracts", "WhypeBehypeLpToken", whypeBehypeLpToken), path);
            vm.writeJson(vm.serializeAddress("contracts", "WhypeBehypeWlpToken", whypeBehypeWlpToken), path);
        }

        vm.stopBroadcast();
    }
}
