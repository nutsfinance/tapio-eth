// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Vm } from "forge-std/Vm.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { console } from "forge-std/console.sol";
import { Config } from "script/Config.sol";
import { SelfPeggingAssetFactory } from "../src/SelfPeggingAssetFactory.sol";
import { SelfPeggingAsset } from "../src/SelfPeggingAsset.sol";
import { MockToken } from "../src/mock/MockToken.sol";
import { MockExchangeRateProvider } from "../src/mock/MockExchangeRateProvider.sol";
import { ChainlinkOracleProvider } from "../src/misc/ChainlinkOracleProvider.sol";

contract Pool is Config {
    function createStandardPool(address tokenA, address tokenB) internal returns (address, address, address, address) {
        console.log("---------------");
        console.log("create-pool-logs");
        console.log("---------------");

        SelfPeggingAssetFactory.CreatePoolArgument memory arg = SelfPeggingAssetFactory.CreatePoolArgument({
            tokenA: tokenA,
            tokenB: tokenB,
            tokenAType: SelfPeggingAssetFactory.TokenType.Standard,
            tokenAOracle: address(0),
            tokenARateFunctionSig: "",
            tokenADecimalsFunctionSig: "",
            tokenBType: SelfPeggingAssetFactory.TokenType.Standard,
            tokenBOracle: address(0),
            tokenBRateFunctionSig: "",
            tokenBDecimalsFunctionSig: ""
        });

        vm.recordLogs();
        factory.createPool(arg);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 eventSig = keccak256("PoolCreated(address,address,address,address,address,address)");

        address decodedPoolToken;
        address decodedSelfPeggingAsset;
        address decodedWrappedPoolToken;
        address decodedRampAController;
        address keeper;

        for (uint256 i = 0; i < entries.length; i++) {
            Vm.Log memory log = entries[i];

            if (log.topics[0] == eventSig) {
                (decodedPoolToken, decodedSelfPeggingAsset, decodedWrappedPoolToken, decodedRampAController,, keeper) =
                    abi.decode(log.data, (address, address, address, address, address, address));
            }
        }
        console.log(keeper);
        return (decodedPoolToken, decodedSelfPeggingAsset, decodedWrappedPoolToken, decodedRampAController);
    }

    function createStandardAndRebasingPool(
        address tokenA,
        address tokenB
    )
        internal
        returns (address, address, address, address)
    {
        console.log("---------------");
        console.log("create-pool-logs");
        console.log("---------------");

        SelfPeggingAssetFactory.CreatePoolArgument memory arg = SelfPeggingAssetFactory.CreatePoolArgument({
            tokenA: tokenA,
            tokenB: tokenB,
            tokenAType: SelfPeggingAssetFactory.TokenType.Standard,
            tokenAOracle: address(0),
            tokenARateFunctionSig: "",
            tokenADecimalsFunctionSig: "",
            tokenBType: SelfPeggingAssetFactory.TokenType.Rebasing,
            tokenBOracle: address(0),
            tokenBRateFunctionSig: "",
            tokenBDecimalsFunctionSig: ""
        });

        vm.recordLogs();
        factory.createPool(arg);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 eventSig = keccak256("PoolCreated(address,address,address,address,address,address)");

        address decodedPoolToken;
        address decodedSelfPeggingAsset;
        address decodedWrappedPoolToken;
        address decodedRampAController;

        for (uint256 i = 0; i < entries.length; i++) {
            Vm.Log memory log = entries[i];

            if (log.topics[0] == eventSig) {
                (decodedPoolToken, decodedSelfPeggingAsset, decodedWrappedPoolToken, decodedRampAController,,) =
                    abi.decode(log.data, (address, address, address, address, address, address));
            }
        }

        return (decodedPoolToken, decodedSelfPeggingAsset, decodedWrappedPoolToken, decodedRampAController);
    }

    function createStandardAndERC4626Pool(
        address tokenA,
        address tokenB
    )
        internal
        returns (address, address, address, address)
    {
        console.log("---------------");
        console.log("create-pool-logs");
        console.log("---------------");

        SelfPeggingAssetFactory.CreatePoolArgument memory arg = SelfPeggingAssetFactory.CreatePoolArgument({
            tokenA: tokenA,
            tokenB: tokenB,
            tokenAType: SelfPeggingAssetFactory.TokenType.Standard,
            tokenAOracle: address(0),
            tokenARateFunctionSig: "",
            tokenADecimalsFunctionSig: "",
            tokenBType: SelfPeggingAssetFactory.TokenType.ERC4626,
            tokenBOracle: address(0),
            tokenBRateFunctionSig: "",
            tokenBDecimalsFunctionSig: ""
        });

        vm.recordLogs();
        factory.createPool(arg);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 eventSig = keccak256("PoolCreated(address,address,address,address,address,address)");

        address decodedPoolToken;
        address decodedSelfPeggingAsset;
        address decodedWrappedPoolToken;
        address decodedRampAController;

        for (uint256 i = 0; i < entries.length; i++) {
            Vm.Log memory log = entries[i];

            if (log.topics[0] == eventSig) {
                (decodedPoolToken, decodedSelfPeggingAsset, decodedWrappedPoolToken, decodedRampAController,,) =
                    abi.decode(log.data, (address, address, address, address, address, address));
            }
        }

        return (decodedPoolToken, decodedSelfPeggingAsset, decodedWrappedPoolToken, decodedRampAController);
    }

    function createExchangeRatePool(
        address tokenA,
        address tokenB,
        address tokenBOracle,
        bytes4 rateFunc,
        bytes4 decimalsFunc
    )
        internal
        returns (address, address, address, address)
    {
        console.log("---------------");
        console.log("create-pool-logs");
        console.log("---------------");

        SelfPeggingAssetFactory.CreatePoolArgument memory arg = SelfPeggingAssetFactory.CreatePoolArgument({
            tokenA: tokenA,
            tokenB: tokenB,
            tokenAType: SelfPeggingAssetFactory.TokenType.Standard,
            tokenAOracle: address(0),
            tokenARateFunctionSig: "",
            tokenADecimalsFunctionSig: "",
            tokenBType: SelfPeggingAssetFactory.TokenType.Oracle,
            tokenBOracle: tokenBOracle,
            tokenBRateFunctionSig: abi.encodePacked(rateFunc),
            tokenBDecimalsFunctionSig: abi.encodePacked(decimalsFunc)
        });

        vm.recordLogs();
        factory.createPool(arg);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 eventSig = keccak256("PoolCreated(address,address,address,address,address,address)");

        address decodedPoolToken;
        address decodedSelfPeggingAsset;
        address decodedWrappedPoolToken;
        address decodedRampAController;

        for (uint256 i = 0; i < entries.length; i++) {
            Vm.Log memory log = entries[i];

            if (log.topics[0] == eventSig) {
                (decodedPoolToken, decodedSelfPeggingAsset, decodedWrappedPoolToken, decodedRampAController,,) =
                    abi.decode(log.data, (address, address, address, address, address, address));
            }
        }

        return (decodedPoolToken, decodedSelfPeggingAsset, decodedWrappedPoolToken, decodedRampAController);
    }

    function createChainlinkPool(
        address tokenA,
        address tokenB,
        address tokenBOracle
    )
        internal
        returns (address, address, address, address)
    {
        console.log("---------------");
        console.log("create-pool-logs");
        console.log("---------------");

        SelfPeggingAssetFactory.CreatePoolArgument memory arg = SelfPeggingAssetFactory.CreatePoolArgument({
            tokenA: tokenA,
            tokenB: tokenB,
            tokenAType: SelfPeggingAssetFactory.TokenType.Standard,
            tokenAOracle: address(0),
            tokenARateFunctionSig: "",
            tokenADecimalsFunctionSig: "",
            tokenBType: SelfPeggingAssetFactory.TokenType.Oracle,
            tokenBOracle: tokenBOracle,
            tokenBRateFunctionSig: abi.encodePacked(ChainlinkOracleProvider.price.selector),
            tokenBDecimalsFunctionSig: abi.encodePacked(ChainlinkOracleProvider.decimals.selector)
        });

        vm.recordLogs();
        factory.createPool(arg);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 eventSig = keccak256("PoolCreated(address,address,address,address,address,address)");

        address decodedPoolToken;
        address decodedSelfPeggingAsset;
        address decodedWrappedPoolToken;
        address decodedRampAController;

        for (uint256 i = 0; i < entries.length; i++) {
            Vm.Log memory log = entries[i];

            if (log.topics[0] == eventSig) {
                (decodedPoolToken, decodedSelfPeggingAsset, decodedWrappedPoolToken, decodedRampAController,,) =
                    abi.decode(log.data, (address, address, address, address, address, address));
            }
        }

        return (decodedPoolToken, decodedSelfPeggingAsset, decodedWrappedPoolToken, decodedRampAController);
    }

    function createChainlinkPool(
        address tokenA,
        address tokenB,
        address tokenAOracle,
        address tokenBOracle
    )
        internal
        returns (address, address, address, address)
    {
        console.log("---------------");
        console.log("create-pool-logs");
        console.log("---------------");

        SelfPeggingAssetFactory.CreatePoolArgument memory arg = SelfPeggingAssetFactory.CreatePoolArgument({
            tokenA: tokenA,
            tokenB: tokenB,
            tokenAType: SelfPeggingAssetFactory.TokenType.Oracle,
            tokenAOracle: tokenAOracle,
            tokenARateFunctionSig: abi.encodePacked(ChainlinkOracleProvider.price.selector),
            tokenADecimalsFunctionSig: abi.encodePacked(ChainlinkOracleProvider.decimals.selector),
            tokenBType: SelfPeggingAssetFactory.TokenType.Oracle,
            tokenBOracle: tokenBOracle,
            tokenBRateFunctionSig: abi.encodePacked(ChainlinkOracleProvider.price.selector),
            tokenBDecimalsFunctionSig: abi.encodePacked(ChainlinkOracleProvider.decimals.selector)
        });

        vm.recordLogs();
        factory.createPool(arg);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 eventSig = keccak256("PoolCreated(address,address,address,address,address,address)");

        address decodedPoolToken;
        address decodedSelfPeggingAsset;
        address decodedWrappedPoolToken;
        address decodedRampAController;

        for (uint256 i = 0; i < entries.length; i++) {
            Vm.Log memory log = entries[i];

            if (log.topics[0] == eventSig) {
                (decodedPoolToken, decodedSelfPeggingAsset, decodedWrappedPoolToken, decodedRampAController,,) =
                    abi.decode(log.data, (address, address, address, address, address, address));
            }
        }

        return (decodedPoolToken, decodedSelfPeggingAsset, decodedWrappedPoolToken, decodedRampAController);
    }

    function createMockExchangeRatePool(
        address tokenA,
        address tokenB,
        address tokenAOracle,
        address tokenBOracle
    )
        internal
        returns (address, address, address, address)
    {
        console.log("---------------");
        console.log("create-pool-logs");
        console.log("---------------");

        SelfPeggingAssetFactory.CreatePoolArgument memory arg = SelfPeggingAssetFactory.CreatePoolArgument({
            tokenA: tokenA,
            tokenB: tokenB,
            tokenAType: SelfPeggingAssetFactory.TokenType.Oracle,
            tokenAOracle: tokenAOracle,
            tokenARateFunctionSig: abi.encodePacked(MockExchangeRateProvider.exchangeRate.selector),
            tokenADecimalsFunctionSig: abi.encodePacked(MockExchangeRateProvider.exchangeRateDecimals.selector),
            tokenBType: SelfPeggingAssetFactory.TokenType.Oracle,
            tokenBOracle: tokenBOracle,
            tokenBRateFunctionSig: abi.encodePacked(MockExchangeRateProvider.exchangeRate.selector),
            tokenBDecimalsFunctionSig: abi.encodePacked(MockExchangeRateProvider.exchangeRateDecimals.selector)
        });

        vm.recordLogs();
        factory.createPool(arg);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 eventSig = keccak256("PoolCreated(address,address,address,address,address,address)");

        address decodedPoolToken;
        address decodedSelfPeggingAsset;
        address decodedWrappedPoolToken;
        address decodedRampAController;

        for (uint256 i = 0; i < entries.length; i++) {
            Vm.Log memory log = entries[i];

            if (log.topics[0] == eventSig) {
                (decodedPoolToken, decodedSelfPeggingAsset, decodedWrappedPoolToken, decodedRampAController,,) =
                    abi.decode(log.data, (address, address, address, address, address, address));
            }
        }

        return (decodedPoolToken, decodedSelfPeggingAsset, decodedWrappedPoolToken, decodedRampAController);
    }

    function initialMint(
        address tokenA,
        address tokenB,
        uint256 tokenAAmount,
        uint256 tokenBAmount,
        SelfPeggingAsset selfPeggingAsset
    )
        internal
    {
        console.log("---------------");
        console.log("initial-mint-logs");
        console.log("---------------");
        console.log("AAAA");

        // console.log(MockToken(tokenB).balanceOf(0x3a3C006053a9B40286B9951A11bE4C5808c11dc8));

        MockToken(tokenA).approve(address(selfPeggingAsset), tokenAAmount);
        MockToken(tokenB).approve(address(selfPeggingAsset), tokenBAmount);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = tokenAAmount;
        amounts[1] = tokenBAmount;

        selfPeggingAsset.mint(amounts, 0);
    }
}