// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface ITokensWithExchangeRate {
  function exchangeRate() external view returns (uint256 _exchangeRate);
}