//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@chainlink/contracts/shared/interfaces/AggregatorV3Interface.sol";

contract MockChainlinkV3Aggregator is AggregatorV3Interface {
    uint8 private _decimals;
    int256 private _answer;
    uint80 private _answeredInRound;

    constructor(uint8 decimals_, int256 answer_, uint80 answeredInRound_) {
        _decimals = decimals_;
        _answer = answer_;
        _answeredInRound = answeredInRound_;
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function description() external pure override returns (string memory) {
        return "";
    }

    function version() external pure override returns (uint256) {
        return 0;
    }

    function getRoundData(uint80 _roundId)
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, _answer, block.timestamp, block.timestamp, _answeredInRound);
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_answeredInRound, _answer, block.timestamp, block.timestamp, _answeredInRound);
    }
}
