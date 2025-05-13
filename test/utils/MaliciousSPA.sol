// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MaliciousSPA {
    address public poolToken;
    address[] public tokens;

    constructor(address _poolToken, address[] memory _tokens) {
        poolToken = _poolToken;
        tokens = _tokens;
    }

    function mint(uint256[] calldata amounts, uint256) external returns (uint256) {
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).transferFrom(msg.sender, address(this), amounts[i]);
        }
        return type(uint256).max;
    }

    function deposit(uint256, address) external returns (uint256) {
        return type(uint256).max;
    }

    function getTokens() external view returns (address[] memory) {
        return tokens;
    }
}
