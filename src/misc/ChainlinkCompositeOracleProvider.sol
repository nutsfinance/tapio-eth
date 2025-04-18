//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@chainlink/contracts/shared/interfaces/AggregatorV3Interface.sol";

contract ChainlinkCompositeOracleProvider {
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

            if (address(_configs[i].feed) != address(0) && _configs[i].maxStalePeriod == 0) {
                revert InvalidStalePeriod();
            }

            if (!_configs[i].isInverted) {
                _configs[i].assetDecimals = _configs[i].feed.decimals();
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

        uint256 _price;
        uint256 priceDecimals;

        for (uint256 i = 0; i < configs.length; i++) {
            Config memory config = configs[i];

            (, int256 feedPrice,, uint256 updatedAt,) = config.feed.latestRoundData();

            if (feedPrice <= 0) {
                revert InvalidFeedPrice();
            }

            if (block.timestamp - updatedAt > config.maxStalePeriod) {
                revert StalePrice();
            }

            if (_price == 0) {
                _price = 10 ** config.assetDecimals;
                priceDecimals = config.assetDecimals;
            }

            if (config.isInverted) {
                uint256 invertedFeedPrice =
                    ((10 ** config.assetDecimals) * (10 ** config.feed.decimals())) / uint256(feedPrice);
                _price = (_price * invertedFeedPrice) / (10 ** priceDecimals);
                priceDecimals = config.assetDecimals;
                continue;
            }

            _price = (_price * uint256(feedPrice)) / (10 ** priceDecimals);
            priceDecimals = config.assetDecimals;
        }

        return _price;
    }

    /**
     * @notice Get the decimals of the price
     * @return Decimals of the price
     */
    function decimals() external view returns (uint256) {
        uint256 _decimals = 0;

        for (uint256 i = 0; i < configs.length; i++) {
            Config memory config = configs[i];

            if (address(config.feed) == address(0)) {
                return _decimals;
            }

            if (config.isInverted) {
                _decimals = config.assetDecimals;
                continue;
            }

            _decimals = config.feed.decimals();
        }

        return _decimals;
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
