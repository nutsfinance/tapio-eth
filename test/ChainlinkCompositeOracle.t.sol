// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { console2 } from "forge-std/console2.sol";

import { ChainlinkCompositeOracleProvider } from "../src/misc/ChainlinkCompositeOracleProvider.sol";
import { MockChainlinkV3Aggregator } from "../src/mock/MockChainlinkV3Aggregator.sol";
import "@chainlink/contracts/shared/interfaces/AggregatorV3Interface.sol";

contract ChainlinkCompositeOracleProviderTest is Test {
    AggregatorV3Interface internal weETHToETHFeed;
    AggregatorV3Interface internal stETHToETHFeed;

    function setUp() public virtual {
        weETHToETHFeed = new MockChainlinkV3Aggregator(18, 1_064_223_213_384_926_000, 1_064_223_213_384_926_000);
        stETHToETHFeed = new MockChainlinkV3Aggregator(18, 998_828_010_001_348_900, 998_828_010_001_348_900);
    }

    function test_weETHTostETH() external {
        ChainlinkCompositeOracleProvider.Config[] memory configs = new ChainlinkCompositeOracleProvider.Config[](2);
        configs[0] = ChainlinkCompositeOracleProvider.Config({
            feed: weETHToETHFeed,
            maxStalePeriod: 24 hours,
            assetDecimals: 18,
            isInverted: false
        });
        configs[1] = ChainlinkCompositeOracleProvider.Config({
            feed: stETHToETHFeed,
            maxStalePeriod: 24 hours,
            assetDecimals: 18,
            isInverted: true
        });

        ChainlinkCompositeOracleProvider oracle =
            new ChainlinkCompositeOracleProvider(AggregatorV3Interface(address(0)), configs);

        assertEq(oracle.price(), 1.065471935837571059e18);
    }
}
