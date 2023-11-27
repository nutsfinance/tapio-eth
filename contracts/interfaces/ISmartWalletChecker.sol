// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface ISmartWalletChecker {
  function check(address addr) external view returns (bool);
}
