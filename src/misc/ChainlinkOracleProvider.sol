//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@chainlink/contracts/shared/interfaces/AggregatorV3Interface.sol";

contract ChainlinkOracleProvider {
    /**
     * @notice Grace period time after the sequencer is back up
     */
    uint256 private constant GRACE_PERIOD_TIME = 3600;

    /**
     * @notice Chainlink feed for the sequencer uptime
     */
    AggregatorV3Interface public immutable sequencerUptimeFeed;

    /**
     * @notice Chainlink feed for the asset
     */
    AggregatorV3Interface public immutable feed;

    /**
     * @notice Maximum stale period for the price feed
     */
    uint256 public immutable maxStalePeriod;

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
     * @notice Contract constructor
     * @param _sequencerUptimeFeed L2 Sequencer uptime feed
     */
    constructor(AggregatorV3Interface _sequencerUptimeFeed, AggregatorV3Interface _feed, uint256 _maxStalePeriod) {
        if (address(_feed) == address(0)) {
            revert InvalidFeed();
        }

        if (_maxStalePeriod == 0) {
            revert InvalidStalePeriod();
        }

        sequencerUptimeFeed = _sequencerUptimeFeed;
        feed = _feed;
        maxStalePeriod = _maxStalePeriod;
    }

    /**
     * @notice Get the price of the asset
     * @return Price of the asset
     */
    function price() external view returns (uint256) {
        _validateSequencerStatus();

        (, int256 price,, uint256 updatedAt,) = feed.latestRoundData();

        if (block.timestamp - updatedAt > maxStalePeriod) {
            revert StalePrice();
        }

        return uint256(price);
    }

    /**
     * @notice Get the decimals of the price
     * @return Decimals of the price
     */
    function decimals() external view returns (uint256) {
        return feed.decimals();
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
