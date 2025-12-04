// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Vm } from "forge-std/Vm.sol";
import { console2 } from "forge-std/console2.sol";
import { ChainConfig } from "./ChainConfig.sol";
import { SelfPeggingAssetFactory } from "../../src/SelfPeggingAssetFactory.sol";
import { SelfPeggingAsset } from "../../src/SelfPeggingAsset.sol";
import { RampAController } from "../../src/periphery/RampAController.sol";
import { ChainlinkOracleProvider } from "../../src/misc/ChainlinkOracleProvider.sol";
import { ChainlinkCompositeOracleProvider } from "../../src/misc/ChainlinkCompositeOracleProvider.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title PoolDeployer
 * @notice Handles pool deployment logic using factory pattern
 * @dev Reads pool configurations and deploys pools accordingly
 */
contract PoolDeployer is ChainConfig {
    SelfPeggingAssetFactory internal poolFactory;

    struct DeployedPool {
        string name;
        address poolToken;
        address selfPeggingAsset;
        address wrappedPoolToken;
        address rampAController;
        address parameterRegistry;
        address keeper;
    }

    struct DeployedOracle {
        string name;
        address oracle;
    }

    DeployedPool[] public deployedPools;
    DeployedOracle[] public deployedOracles;

    /**
     * @notice Set the factory instance for pool deployment
     */
    function setPoolFactory(SelfPeggingAssetFactory _factory) internal {
        poolFactory = _factory;
    }

    /**
     * @notice Deploy pools based on configuration
     */
    function deployPools() internal {
        uint256 poolCount = getPoolCount();

        for (uint256 i = 0; i < poolCount; i++) {
            PoolConfig memory config = getPool(i);

            if (!config.enabled) {
                console2.log("Skipping disabled pool:", config.name);
                continue;
            }

            console2.log("Deploying pool:", config.name);
            console2.log("  Description:", config.description);

            // Get token addresses
            address tokenA = getTokenAddress(config.tokenA);
            address tokenB = getTokenAddress(config.tokenB);

            console2.log("  TokenA:", tokenA);
            console2.log("  TokenB:", tokenB);

            // Deploy based on pool type
            DeployedPool memory deployedPool = _deployPoolByType(config, tokenA, tokenB);

            deployedPools.push(deployedPool);
            console2.log("  Pool deployed at:", deployedPool.selfPeggingAsset);
        }
    }

    /**
     * @notice Deploy pool based on type configuration
     */
    function _deployPoolByType(
        PoolConfig memory config,
        address tokenA,
        address tokenB
    )
        internal
        returns (DeployedPool memory)
    {
        SelfPeggingAssetFactory.CreatePoolArgument memory arg = SelfPeggingAssetFactory.CreatePoolArgument({
            tokenA: tokenA,
            tokenB: tokenB,
            tokenAType: stringToTokenType(config.tokenAType),
            tokenAOracle: address(0),
            tokenARateFunctionSig: "",
            tokenADecimalsFunctionSig: "",
            tokenBType: stringToTokenType(config.tokenBType),
            tokenBOracle: address(0),
            tokenBRateFunctionSig: "",
            tokenBDecimalsFunctionSig: ""
        });

        // Deploy oracles if needed (for Oracle token types)
        if (arg.tokenAType == SelfPeggingAssetFactory.TokenType.Oracle) {
            require(config.tokenAOracle.feeds.length > 0, "Token A oracle config required");
            address oracle = _deployOracle(config.name, "tokenA", config.tokenAOracle);

            arg.tokenAOracle = oracle;
            arg.tokenARateFunctionSig = abi.encodePacked(ChainlinkOracleProvider.price.selector);
            arg.tokenADecimalsFunctionSig = abi.encodePacked(ChainlinkOracleProvider.decimals.selector);
        }

        if (arg.tokenBType == SelfPeggingAssetFactory.TokenType.Oracle) {
            require(config.tokenBOracle.feeds.length > 0, "Token B oracle config required");
            address oracle = _deployOracle(config.name, "tokenB", config.tokenBOracle);

            arg.tokenBOracle = oracle;
            arg.tokenBRateFunctionSig = abi.encodePacked(ChainlinkOracleProvider.price.selector);
            arg.tokenBDecimalsFunctionSig = abi.encodePacked(ChainlinkOracleProvider.decimals.selector);
        }

        // Create pool and capture event
        vm.recordLogs();
        poolFactory.createPool(arg);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 eventSig = keccak256("PoolCreated(address,address,address,address,address,address)");

        // Parse event data
        for (uint256 i = 0; i < entries.length; i++) {
            Vm.Log memory log = entries[i];

            if (log.topics[0] == eventSig) {
                (
                    address poolToken,
                    address selfPeggingAsset,
                    address wrappedPoolToken,
                    address rampAController,
                    address parameterRegistry,
                    address keeper
                ) = abi.decode(log.data, (address, address, address, address, address, address));

                return DeployedPool({
                    name: config.name,
                    poolToken: poolToken,
                    selfPeggingAsset: selfPeggingAsset,
                    wrappedPoolToken: wrappedPoolToken,
                    rampAController: rampAController,
                    parameterRegistry: parameterRegistry,
                    keeper: keeper
                });
            }
        }

        revert("Pool creation event not found");
    }

    function _runInitialMints() internal {
        for (uint256 i = 0; i < getPoolCount(); i++) {
            PoolConfig memory p = getPool(i);
            if (!p.enabled || !p.initialMint.enabled) continue;

            address spaAddr = deployedPools[i].selfPeggingAsset;
            if (SelfPeggingAsset(spaAddr).totalSupply() != 0) continue;

            address tokenA = SelfPeggingAsset(spaAddr).tokens(0);
            address tokenB = SelfPeggingAsset(spaAddr).tokens(1);

            // Approve & mint (deployer currently broadcasting)
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

            console2.log("  Initial mint done for:", p.name);
        }
    }

    /**
     * @notice Deploy oracle based on configuration
     */
    function _deployOracle(
        string memory poolName,
        string memory tokenLabel,
        OracleConfig memory oracleConfig
    )
        private
        returns (address)
    {
        bytes32 oracleTypeHash = keccak256(abi.encodePacked(oracleConfig.oracleType));
        address oracle;

        if (oracleTypeHash == keccak256(abi.encodePacked("chainlink"))) {
            // Simple ChainlinkOracleProvider (single feed)
            require(oracleConfig.feeds.length == 1, "Chainlink oracle requires exactly 1 feed");

            OracleFeedConfig memory feedConfig = oracleConfig.feeds[0];
            address feed = vm.parseAddress(feedConfig.feed);

            oracle = address(
                new ChainlinkOracleProvider(
                    AggregatorV3Interface(chainData.sequencer), AggregatorV3Interface(feed), feedConfig.heartbeat
                )
            );

            console2.log(string.concat("  Deployed ChainlinkOracleProvider for ", tokenLabel, ":"), oracle);
        } else if (oracleTypeHash == keccak256(abi.encodePacked("composite"))) {
            // ChainlinkCompositeOracleProvider (multiple feeds)
            require(oracleConfig.feeds.length > 0, "Composite oracle requires at least 1 feed");

            ChainlinkCompositeOracleProvider.Config[] memory configs =
                new ChainlinkCompositeOracleProvider.Config[](oracleConfig.feeds.length);

            for (uint256 i = 0; i < oracleConfig.feeds.length; i++) {
                OracleFeedConfig memory feedConfig = oracleConfig.feeds[i];
                address feed = vm.parseAddress(feedConfig.feed);

                configs[i] = ChainlinkCompositeOracleProvider.Config({
                    feed: AggregatorV3Interface(feed),
                    maxStalePeriod: feedConfig.heartbeat,
                    assetDecimals: feedConfig.decimals,
                    isInverted: feedConfig.inverted
                });
            }

            oracle = address(new ChainlinkCompositeOracleProvider(AggregatorV3Interface(chainData.sequencer), configs));

            console2.log(string.concat("  Deployed ChainlinkCompositeOracleProvider for ", tokenLabel, ":"), oracle);
        } else {
            revert(string.concat("Unknown oracle type: ", oracleConfig.oracleType));
        }

        // Save deployed oracle
        deployedOracles.push(
            DeployedOracle({ name: string.concat(poolName, "_", tokenLabel, "_oracle"), oracle: oracle })
        );

        return oracle;
    }

    /**
     * @notice Parse address from string (hex format)
     */
    function _parseAddress(string memory addressStr) private pure returns (address) {
        return vm.parseAddress(addressStr);
    }

    /**
     * @notice Get deployed oracle address by name
     */
    function _getDeployedOracle(string memory name) internal view returns (address) {
        if (bytes(name).length == 0) {
            return address(0);
        }

        for (uint256 i = 0; i < deployedOracles.length; i++) {
            if (keccak256(abi.encodePacked(deployedOracles[i].name)) == keccak256(abi.encodePacked(name))) {
                return deployedOracles[i].oracle;
            }
        }

        revert(string.concat("Oracle not found: ", name));
    }

    /**
     * @notice Get number of deployed pools
     */
    function getDeployedPoolCount() internal view returns (uint256) {
        return deployedPools.length;
    }

    /**
     * @notice Get deployed pool by index
     */
    function getDeployedPool(uint256 index) internal view returns (DeployedPool memory) {
        require(index < deployedPools.length, "Pool index out of bounds");
        return deployedPools[index];
    }

    /**
     * @notice Get deployed oracle by index
     */
    function getDeployedOracle(uint256 index) internal view returns (DeployedOracle memory) {
        require(index < deployedOracles.length, "Oracle index out of bounds");
        return deployedOracles[index];
    }
}
