// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockERC4626Token is ERC4626Upgradeable {
    function initialize(IERC20 token) public initializer {
        __ERC4626_init(token);
    }
}
