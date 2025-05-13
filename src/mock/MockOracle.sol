// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract MockOracle {
    uint256 internal _rate = 1e18;

    function setRate(uint256 newRate) external {
        _rate = newRate;
    }

    function rate() external view returns (uint256) {
        return _rate;
    }

    function decimals() external pure returns (uint256) {
        return 18;
    }
}
