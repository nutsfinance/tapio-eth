// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { SelfPeggingAssetFactory } from "../../src/SelfPeggingAssetFactory.sol";

/**
 * @title ChainConfig
 * @notice Handles loading and parsing chain-specific configuration from JSON files
 * @dev Provides structured access to chain metadata, token addresses, oracles, and deployment parameters
 */
contract ChainConfig is Script {
    using stdJson for string;

    uint256 internal deployerPrivateKey;
    address internal DEPLOYER;
    address internal GOVERNOR;

    struct TapioChainData {
        uint256 chainId;
        string name;
        string rpcUrl;
        mapping(string => address) tokens;
        address sequencer;
    }

    struct FactoryDefaults {
        uint256 mintFee;
        uint256 swapFee;
        uint256 redeemFee;
        uint256 offPegFeeMultiplier;
        uint256 A;
        uint256 minRampTime;
        uint256 exchangeRateFeeFactor;
        uint256 bufferPercent;
    }

    struct SPAParameters {
        uint256 mintFee;
        uint256 swapFee;
        uint256 redeemFee;
        uint256 offPegFeeMultiplier;
        uint256 A;
        uint256 minRampTime;
        uint256 exchangeRateFeeFactor;
        uint256 bufferPercent;
    }

    struct OracleFeedConfig {
        string feed; // Feed address
        uint256 heartbeat; // Max stale period
        uint256 decimals; // Asset decimals
        bool inverted; // Is inverted (for composite)
    }

    struct OracleConfig {
        string oracleType; // "chainlink" or "composite"
        OracleFeedConfig[] feeds; // Single feed for chainlink, multiple for composite
    }

    struct InitialMint {
        bool enabled;
        uint256 amountTokenA;
        uint256 amountTokenB;
    }

    struct PoolConfig {
        string name;
        string tokenA;
        string tokenB;
        string tokenAType;
        string tokenBType;
        OracleConfig tokenAOracle;
        OracleConfig tokenBOracle;
        bool enabled;
        string description;
        SPAParameters spa;
        InitialMint initialMint;
    }

    TapioChainData internal chainData;
    PoolConfig[] internal pools;

    // Track current network and environment for config loading
    string internal currentNetwork;
    string internal currentEnvironment;

    /**
     * @notice Load chain configuration from JSON file
     * @param networkName The network name (e.g., "ethereum", "base")
     * @param environment The environment ("mainnet" or "testnet")
     */
    function loadChainConfig(string memory networkName, string memory environment) internal {
        currentNetwork = networkName;
        currentEnvironment = environment;

        string memory chainPath = string.concat("./script/configs/chains/", environment, "/", networkName, ".json");
        string memory chainJson = vm.readFile(chainPath);

        // Load basic chain data
        chainData.chainId = chainJson.readUint(".chainId");
        chainData.name = chainJson.readString(".name");
        chainData.rpcUrl = chainJson.readString(".rpcUrl");

        // Load sequencer if exists (only for L2s)
        if (vm.keyExists(chainJson, ".oracles.sequencer")) {
            chainData.sequencer = chainJson.readAddress(".oracles.sequencer");
        } else {
            chainData.sequencer = address(0);
        }

        console2.log("Loaded config for:", networkName);
        console2.log("Loaded chain ID:", chainData.chainId);
    }

    /**
     * @notice Load token address from config
     * @param tokenKey The token key (e.g., "usdc", "weth")
     * @return Token address
     */
    function getTokenAddress(string memory tokenKey) internal returns (address) {
        // Check if already cached
        if (chainData.tokens[tokenKey] != address(0)) {
            return chainData.tokens[tokenKey];
        }

        // Load from JSON
        string memory chainPath =
            string.concat("./script/configs/chains/", currentEnvironment, "/", currentNetwork, ".json");
        string memory chainJson = vm.readFile(chainPath);
        string memory tokenPath = string.concat(".tokens.", tokenKey);

        address tokenAddress = chainJson.readAddress(tokenPath);
        chainData.tokens[tokenKey] = tokenAddress;

        return tokenAddress;
    }

    /**
     * @notice Load factory default parameters from chain config
     * @return Factory defaults for this chain
     */
    function loadFactoryDefaults() internal view returns (FactoryDefaults memory) {
        string memory chainPath =
            string.concat("./script/configs/chains/", currentEnvironment, "/", currentNetwork, ".json");
        string memory chainJson = vm.readFile(chainPath);

        FactoryDefaults memory defaults;
        string memory basePath = ".factoryDefaults";

        defaults.mintFee = chainJson.readUint(string.concat(basePath, ".mintFee"));
        defaults.swapFee = chainJson.readUint(string.concat(basePath, ".swapFee"));
        defaults.redeemFee = chainJson.readUint(string.concat(basePath, ".redeemFee"));
        defaults.offPegFeeMultiplier = chainJson.readUint(string.concat(basePath, ".offPegFeeMultiplier"));
        defaults.A = chainJson.readUint(string.concat(basePath, ".A"));
        defaults.minRampTime = chainJson.readUint(string.concat(basePath, ".minRampTime"));
        defaults.exchangeRateFeeFactor = chainJson.readUint(string.concat(basePath, ".exchangeRateFeeFactor"));
        defaults.bufferPercent = chainJson.readUint(string.concat(basePath, ".bufferPercent"));

        return defaults;
    }

    /**
     * @notice Load pool configurations from JSON file
     * @param networkName The network name (e.g., "ethereum", "base")
     * @param environment The environment ("mainnet" or "testnet")
     */
    function loadPoolConfigs(string memory networkName, string memory environment) internal {
        string memory poolPath = string.concat("./script/configs/pools/", environment, "/", networkName, "-pools.json");
        string memory poolJson = vm.readFile(poolPath);

        // Load pools by iterating until we hit an error
        uint256 i = 0;
        while (true) {
            string memory basePath = string.concat(".pools[", vm.toString(i), "]");

            // Check if this index exists
            if (!vm.keyExists(poolJson, string.concat(basePath, ".name"))) {
                break;
            }

            PoolConfig memory pool;
            pool.name = poolJson.readString(string.concat(basePath, ".name"));
            pool.tokenA = poolJson.readString(string.concat(basePath, ".tokenA"));
            pool.tokenB = poolJson.readString(string.concat(basePath, ".tokenB"));
            pool.tokenAType = poolJson.readString(string.concat(basePath, ".tokenAType"));
            pool.tokenBType = poolJson.readString(string.concat(basePath, ".tokenBType"));
            // Load oracle configurations (optional - only for Oracle token types)
            pool.tokenAOracle = _loadOracleConfig(poolJson, string.concat(basePath, ".tokenAOracle"));
            pool.tokenBOracle = _loadOracleConfig(poolJson, string.concat(basePath, ".tokenBOracle"));
            pool.enabled = poolJson.readBool(string.concat(basePath, ".enabled"));
            pool.description = poolJson.readString(string.concat(basePath, ".description"));

            // Load SPA parameters for this pool (optional - used for governance, not deployment)
            string memory spaPath = string.concat(basePath, ".spa");
            if (vm.keyExists(poolJson, spaPath)) {
                pool.spa.mintFee = poolJson.readUint(string.concat(spaPath, ".mintFee"));
                pool.spa.swapFee = poolJson.readUint(string.concat(spaPath, ".swapFee"));
                pool.spa.redeemFee = poolJson.readUint(string.concat(spaPath, ".redeemFee"));
                pool.spa.offPegFeeMultiplier = poolJson.readUint(string.concat(spaPath, ".offPegFeeMultiplier"));
                pool.spa.A = poolJson.readUint(string.concat(spaPath, ".A"));
                pool.spa.minRampTime = poolJson.readUint(string.concat(spaPath, ".minRampTime"));
                pool.spa.exchangeRateFeeFactor = poolJson.readUint(string.concat(spaPath, ".exchangeRateFeeFactor"));
                pool.spa.bufferPercent = poolJson.readUint(string.concat(spaPath, ".bufferPercent"));
            }

            // Load initialMint (optional)
            string memory imPath = string.concat(basePath, ".initialMint");
            if (vm.keyExists(poolJson, imPath)) {
                pool.initialMint.enabled = poolJson.readBool(string.concat(imPath, ".enabled"));
                pool.initialMint.amountTokenA = poolJson.readUint(string.concat(imPath, ".amountTokenA"));
                pool.initialMint.amountTokenB = poolJson.readUint(string.concat(imPath, ".amountTokenB"));
            } else {
                pool.initialMint.enabled = false;
            }

            pools.push(pool);
            i++;
        }

        console2.log("Loaded pool configs:", pools.length, "pools");
    }

    /**
     * @notice Load oracle configuration from JSON
     */
    function _loadOracleConfig(
        string memory poolJson,
        string memory oraclePath
    )
        private
        view
        returns (OracleConfig memory)
    {
        OracleConfig memory config;

        // Check if oracle config exists
        if (!vm.keyExists(poolJson, oraclePath)) {
            return config; // Return empty config
        }

        // Load oracle type
        string memory typePath = string.concat(oraclePath, ".type");
        if (vm.keyExists(poolJson, typePath)) {
            config.oracleType = poolJson.readString(typePath);

            // Count feeds first
            string memory feedsPath = string.concat(oraclePath, ".feeds");
            uint256 feedCount = 0;
            while (true) {
                string memory feedPath = string.concat(feedsPath, "[", vm.toString(feedCount), "]");
                if (!vm.keyExists(poolJson, string.concat(feedPath, ".feed"))) {
                    break;
                }
                feedCount++;
            }

            // Allocate array
            config.feeds = new OracleFeedConfig[](feedCount);

            // Load feeds
            for (uint256 i = 0; i < feedCount; i++) {
                string memory feedPath = string.concat(feedsPath, "[", vm.toString(i), "]");

                config.feeds[i].feed = poolJson.readString(string.concat(feedPath, ".feed"));
                config.feeds[i].heartbeat = poolJson.readUint(string.concat(feedPath, ".heartbeat"));
                config.feeds[i].decimals = poolJson.readUint(string.concat(feedPath, ".decimals"));

                // inverted is optional (default false)
                if (vm.keyExists(poolJson, string.concat(feedPath, ".inverted"))) {
                    config.feeds[i].inverted = poolJson.readBool(string.concat(feedPath, ".inverted"));
                }
            }
        }

        return config;
    }

    /**
     * @notice Helper to get array length from JSON bytes
     */
    function _getArrayLength(bytes memory data) private pure returns (uint256) {
        // Decode as a dynamic array to get length
        // The first 32 bytes contain the array length
        uint256 len;
        assembly {
            len := mload(add(data, 0x20))
        }
        return len;
    }

    /**
     * @notice Get configured chain ID from loaded config
     */
    function getConfiguredChainId() internal view returns (uint256) {
        return chainData.chainId;
    }

    /**
     * @notice Get network name from loaded chain config
     */
    function getNetworkName() internal view returns (string memory) {
        return chainData.name;
    }

    /**
     * @notice Get network name from chain ID (mainnet networks only)
     * @dev Static helper for scripts that need network name before loading config
     *      This is overridden in testnet scripts
     */
    function getNetworkName(uint256 chainId) internal pure virtual returns (string memory) {
        if (chainId == 1) return "ethereum";
        if (chainId == 10) return "optimism";
        if (chainId == 146) return "sonic";
        if (chainId == 999) return "hyper";
        if (chainId == 8453) return "base";
        if (chainId == 9745) return "plasma";
        if (chainId == 42_161) return "arbitrum";
        if (chainId == 59_144) return "linea";
        revert("Unsupported chain ID");
    }

    /**
     * @notice Get sequencer address
     */
    function getSequencer() internal view returns (address) {
        return chainData.sequencer;
    }

    /**
     * @notice Get number of pools configured
     */
    function getPoolCount() internal view returns (uint256) {
        return pools.length;
    }

    /**
     * @notice Get pool configuration by index
     */
    function getPool(uint256 index) internal view returns (PoolConfig memory) {
        require(index < pools.length, "Pool index out of bounds");
        return pools[index];
    }

    /**
     * @notice Helper to convert string to TokenType enum
     */
    function stringToTokenType(string memory typeStr) internal pure returns (SelfPeggingAssetFactory.TokenType) {
        bytes32 typeHash = keccak256(abi.encodePacked(typeStr));

        if (typeHash == keccak256(abi.encodePacked("Standard"))) {
            return SelfPeggingAssetFactory.TokenType.Standard;
        } else if (typeHash == keccak256(abi.encodePacked("Rebasing"))) {
            return SelfPeggingAssetFactory.TokenType.Rebasing;
        } else if (typeHash == keccak256(abi.encodePacked("ERC4626"))) {
            return SelfPeggingAssetFactory.TokenType.ERC4626;
        } else if (typeHash == keccak256(abi.encodePacked("Oracle"))) {
            return SelfPeggingAssetFactory.TokenType.Oracle;
        } else {
            revert("Invalid token type");
        }
    }
}
