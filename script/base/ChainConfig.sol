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

    mapping(uint256 => string) rpcs;

    uint256 deployerPrivateKey;
    uint256 adminPrivateKey;

    address DEPLOYER;
    address ADMIN;
    address GOVERNOR;

    struct TapioChainData {
        address sequencer;
    }

    struct FactoryDefaults {
        address owner;
        address governor;
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

    struct PoolConfig {
        string name;
        string tokenA;
        string tokenB;
        address tokenAAddress;
        address tokenBAddress;
        string tokenAType;
        string tokenBType;
        OracleConfig tokenAOracle;
        OracleConfig tokenBOracle;
        bool enabled;
        string description;
        SPAParameters spa;
    }

    constructor() {
        rpcs[1] = "MAINNET";
        rpcs[8453] = "BASE_RPC";
        rpcs[84_532] = "BASE_SEPOLIA_RPC";
        rpcs[42_161] = "ARB_RPC";
        rpcs[421_614] = "ARB_SEPOLIA_RPC";
        rpcs[10] = "OP_RPC";
        rpcs[11_155_420] = "OP_SEPOLIA_RPC";
        rpcs[80_069] = "BERA_BEPOLIA_RPC";
        rpcs[10_143] = "MONAD_TESTNET_RPC";
        rpcs[998] = "HYPER_TESTNET";
        rpcs[146] = "SONIC_MAINNET_RPC";
        rpcs[57_054] = "SONIC_TESTNET_RPC";
        rpcs[1301] = "UNICHAIN_SEPOLIA_RPC";
    }

    TapioChainData internal chainData;
    PoolConfig[] internal pools;

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

    function getBaseDir(bool isDryRun) internal view returns (string memory) {
        string memory root = vm.projectRoot();
        string memory chain = vm.envString("CHAIN");
        string memory version = vm.envString("VERSION");
        return isDryRun
            ? string(abi.encodePacked(root, "/deployments/", version, "/", chain, "/dry-run"))
            : string(abi.encodePacked(root, "/deployments/", version, "/", chain));
    }

    function setUp() internal {
        if (vm.envUint("HEX_PRIV_KEY") == 0) revert("No private keys found");
        deployerPrivateKey = vm.envUint("HEX_PRIV_KEY");
        adminPrivateKey = vm.envUint("MODERATOR_PRIV_KEY");
        uint256 governorPrivateKey = vm.envUint("DEV_PROD_KEY");
        DEPLOYER = vm.addr(deployerPrivateKey);
        ADMIN = vm.addr(adminPrivateKey);
        GOVERNOR = vm.addr(governorPrivateKey);
    }

    function loadConfig(string memory chain, string memory version) internal {
        string memory chainPath = string.concat("./script/configs/", chain, "/", version, ".json");
        string memory chainJson = vm.readFile(chainPath);

        // Load sequencer if exists (only for L2s)
        if (vm.keyExists(chainJson, ".oracles.sequencer")) {
            chainData.sequencer = chainJson.readAddress(".oracles.sequencer");
        } else {
            chainData.sequencer = address(0);
        }

        console2.log("Loaded config for chain %s and version %s", chain, version);
    }

    function loadFactoryDefaults(
        string memory chain,
        string memory version
    )
        internal
        view
        returns (FactoryDefaults memory)
    {
        string memory chainPath = string.concat("./script/configs/", chain, "/", version, ".json");
        string memory chainJson = vm.readFile(chainPath);

        FactoryDefaults memory defaults;
        string memory basePath = ".factoryDefaults";

        defaults.owner = chainJson.readAddress(string.concat(basePath, ".owner"));
        defaults.governor = chainJson.readAddress(string.concat(basePath, ".governor"));
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
     * @param chain The network name
     */
    function loadPoolConfigs(string memory chain, string memory version) internal {
        string memory poolPath = string.concat("./script/configs/", chain, "/", version, ".json");
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
            pool.tokenAAddress = poolJson.readAddress(string.concat(basePath, ".tokenAAddress"));
            pool.tokenBAddress = poolJson.readAddress(string.concat(basePath, ".tokenBAddress"));
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

            pools.push(pool);
            i++;
        }

        console2.log("Loaded pool configs:", pools.length, "pools");
    }
}
