// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IWtaptETH {
  function wrap(uint256 _tapETHAmount) external returns (uint256);

  function unwrap(uint256 _wtapETHAmount) external returns (uint256);

  receive() external payable;

  function getWtapETHByTapETH(
    uint256 _tapETHAmount
  ) external view returns (uint256);

  function getTapETHByWtapETH(
    uint256 _wtapETHAmount
  ) external view returns (uint256);

  function tapETHPerToken() external view returns (uint256);

  function tokensPerTapETH() external view returns (uint256);
}
