// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "./interfaces/ITapETH.sol";

/**
 * @title TapETH token wrapper with static balances.
 * @dev It's an ERC20 token that represents the account's share of the total
 * supply of tapETH tokens. WtapETH token's balance only changes on transfers,
 * unlike tapETH that is also increased when staking rewards and swap fee are generated.
 * It's a "power user" token for DeFi protocols which don't
 * support rebasable tokens.
 * The contract is also a trustless wrapper that accepts tapETH tokens and mints
 * wtapETH in return. Then the user unwraps, the contract burns user's wtapETH
 * and sends user locked tapETH in return.
 * The contract provides the staking shortcut: user can send ETH with regular
 * transfer and get wtapETH in return. The contract will send ETH to Tapio
 * staking it and wrapping the received tapETH.
 */

contract WtaptETH is ERC20Permit {
  ITapETH public tapETH;

  constructor(
    ITapETH _tapETH
  ) ERC20Permit("Wrapped tapETH") ERC20("Wrapped tapETH", "wtapETH") {
    tapETH = _tapETH;
  }

  /**
   * @notice Exchanges tapETH to wtapETH
   * @param _tapETHAmount amount of tapETH to wrap in exchange for wtapETH
   * @dev Requirements:
   *  - msg.sender must approve at least `_tapETHAmount` tapETH to this
   *    contract.
   * @return Amount of wtapETH user receives after wrap
   */
  function wrap(uint256 _tapETHAmount) external returns (uint256) {
    require(_tapETHAmount > 0, "wtapETH: can't wrap zero tapETH");
    uint256 _wtapETHAmount = tapETH.getSharesByPooledEth(_tapETHAmount);
    _mint(msg.sender, _wtapETHAmount);
    tapETH.transferFrom(msg.sender, address(this), _tapETHAmount);
    return _wtapETHAmount;
  }

  /**
   * @notice Exchanges wtapETH to tapETH
   * @param _wtapETHAmount amount of wtapETH to uwrap in exchange for tapETH
   * @return Amount of tapETH user receives after unwrap
   */
  function unwrap(uint256 _wtapETHAmount) external returns (uint256) {
    require(_wtapETHAmount > 0, "wstETH: zero amount unwrap not allowed");
    uint256 _tapETHAmount = tapETH.getPooledEthByShares(_wtapETHAmount);
    _burn(msg.sender, _wtapETHAmount);
    tapETH.transfer(msg.sender, _tapETHAmount);
    return _tapETHAmount;
  }

  /**
   * @notice Shortcut to stake ETH and auto-wrap returned tapETH
   * @dev to do
   */
  receive() external payable {}

  /**
   * @notice Get amount of wtapETH for a given amount of tapETH
   * @param _tapETHAmount amount of tapETH
   * @return Amount of wtapETH for a given tapETH amount
   */
  function getWtapETHByTapETH(
    uint256 _tapETHAmount
  ) external view returns (uint256) {
    return tapETH.getSharesByPooledEth(_tapETHAmount);
  }

  /**
   * @notice Get amount of tapETH for a given amount of wtapETH
   * @param _wtapETHAmount amount of wtapETH
   * @return Amount of tapETH for a given wtapETH amount
   */
  function getTapETHByWtapETH(
    uint256 _wtapETHAmount
  ) external view returns (uint256) {
    return tapETH.getPooledEthByShares(_wtapETHAmount);
  }

  /**
   * @notice Get amount of tapETH for a one wtapETH
   * @return Amount of tapETH for 1 wstETH
   */
  function tapETHPerToken() external view returns (uint256) {
    return tapETH.getPooledEthByShares(1 ether);
  }

  /**
   * @notice Get amount of wtapETH for a one tapETH
   * @return Amount of wtapETH for a 1 tapETH
   */
  function tokensPerTapETH() external view returns (uint256) {
    return tapETH.getSharesByPooledEth(1 ether);
  }
}
