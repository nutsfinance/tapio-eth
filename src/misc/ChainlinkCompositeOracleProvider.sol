//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@chainlink/contracts/shared/interfaces/AggregatorV3Interface.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract ChainlinkCompositeOracleProvider {
    using Math for uint256;

    struct Config {
        /// @notice Chainlink feed
        AggregatorV3Interface feed;
        /// @notice Max stale period in seconds
        uint256 maxStalePeriod;
        /// @notice Should be first token decimals if inverted and if not inverted then feed decimals
        uint256 assetDecimals;
        /// @notice If true, the price is inverted
        bool isInverted;
    }

    /**
     * @notice Fixed-point precision for internal calculations
     */
    uint256 private constant PRECISION = 1e36;

    /**
     * @notice Grace period time after the sequencer is back up
     */
    uint256 private constant GRACE_PERIOD_TIME = 3600;

    /**
     * @notice Chainlink feed for the sequencer uptime
     */
    AggregatorV3Interface public immutable sequencerUptimeFeed;

    /**
     * @notice Array of 3 configs
     */
    Config[] public configs;

    /**
     * @notice Error emitted when feed is invalid
     */
    error InvalidFeed();

    /**
     * @notice Error emitted when stale period is invalid
     */
    error InvalidStalePeriod();

    /**
     * @notice Error emitted when price is stale
     */
    error StalePrice();

    /**
     * @notice Error emitted when sequencer is down
     */
    error SequencerDown();

    /**
     * @notice Error emitted when grace period is not over
     */
    error GracePeriodNotOver();

    /**
     * @notice Error emitted when price from feed is invalid
     */
    error InvalidFeedPrice();

    /**
     * @notice Contract constructor
     * @param _sequencerUptimeFeed L2 Sequencer uptime feed
     * @param _configs Array of configs for feeds
     */
    constructor(AggregatorV3Interface _sequencerUptimeFeed, Config[] memory _configs) {
        for (uint256 i = 0; i < _configs.length; i++) {
            if (address(_configs[i].feed) == address(0)) {
                revert InvalidFeed();
            }

            if (_configs[i].maxStalePeriod == 0) {
                revert InvalidStalePeriod();
            }

            configs.push(_configs[i]);
        }

        sequencerUptimeFeed = _sequencerUptimeFeed;
    }

    /**
     * @notice Get the price of the asset
     * @return Price of the asset
     */
    function price() external view returns (uint256) {
        _validateSequencerStatus();

        uint256 highPrecisionPrice = PRECISION; // precision accumulator
        uint256 currentDecimals;

        for (uint256 i = 0; i < configs.length; i++) {
            Config memory config = configs[i];
            currentDecimals = _getCurrentDecimals(config);

            (, int256 feedPrice,, uint256 updatedAt,) = config.feed.latestRoundData();

            if (feedPrice <= 0) {
                revert InvalidFeedPrice();
            }

            if (block.timestamp - updatedAt > config.maxStalePeriod) {
                revert StalePrice();
            }

            if (config.isInverted) {
                uint256 invertedFeedPrice =
                    PRECISION.mulDiv((10 ** config.assetDecimals) * (10 ** config.feed.decimals()), uint256(feedPrice));
                highPrecisionPrice = highPrecisionPrice.mulDiv(invertedFeedPrice, PRECISION);
            } else {
                highPrecisionPrice = (highPrecisionPrice).mulDiv(uint256(feedPrice), (10 ** currentDecimals));
            }
        }

        if (highPrecisionPrice == 0) return 0;

        return highPrecisionPrice / PRECISION;
    }

    /**
     * @notice Get the decimals of the price
     * @return Decimals of the price
     */
    function decimals() external view returns (uint256) {
        if (configs.length == 0) return 0;

        // last config only matters
        Config memory lastConfig = configs[configs.length - 1];
        return _getCurrentDecimals(lastConfig);
    }

    /**
     * @notice Get the current decimals of a config
     * @param config The config to get decimals for
     * @return The current decimals value
     */
    function _getCurrentDecimals(Config memory config) internal view returns (uint256) {
        if (config.isInverted) return config.assetDecimals;
        return config.feed.decimals();
    }

    /**
     * @notice Validate the sequencer status
     */
    function _validateSequencerStatus() internal view {
        if (address(sequencerUptimeFeed) == address(0)) {
            return;
        }

        (
            /*uint80 roundID*/
            ,
            int256 answer,
            uint256 startedAt,
            /*uint256 updatedAt*/
            ,
            /*uint80 answeredInRound*/
        ) = sequencerUptimeFeed.latestRoundData();

        // Answer == 0: Sequencer is up
        // Answer == 1: Sequencer is down
        bool isSequencerUp = answer == 0;
        if (!isSequencerUp) {
            revert SequencerDown();
        }

        // Make sure the grace period has passed after the
        // sequencer is back up.
        uint256 timeSinceUp = block.timestamp - startedAt;
        if (timeSinceUp <= GRACE_PERIOD_TIME) {
            revert GracePeriodNotOver();
        }
    }
}
