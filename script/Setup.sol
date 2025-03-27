// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { stdJson } from "forge-std/StdJson.sol";
import { console } from "forge-std/console.sol";
import { MockToken } from "../src/mock/MockToken.sol";
import { Config } from "script/Config.sol";

contract Setup is Config {
    function deployMocks() internal {
        MockToken tokenA = new MockToken("USDC", "USDC", 6);
        MockToken tokenB = new MockToken("USDT", "USDT", 6);

        usdc = address(tokenA);
        usdt = address(tokenB);
    }
}
