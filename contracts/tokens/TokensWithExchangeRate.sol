// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "../interfaces/ITokensWithExchangeRate.sol";

/**
 * @notice Mock ERC20 token.
 */
contract TokensWithExchangeRate is
  IERC20,
  Initializable,
  ReentrancyGuardUpgradeable
{
  using SafeMathUpgradeable for uint256;
  using SafeERC20Upgradeable for IERC20Upgradeable;

  address public token;
  ITokensWithExchangeRate public exchangeRateProvider;
  uint8 public exchangeRateDecimal;

  function initialize(
    address _token,
    address _exchangeRateProvider,
    uint8 _decimals
  ) public initializer {
    require(_token != address(0x0), "token not set");
    require(
      _exchangeRateProvider != address(0x0),
      "exchangeRateProvider not set"
    );
    require(_decimals != 0, "decimals not set");

    token = _token;
    exchangeRateProvider = ITokensWithExchangeRate(_exchangeRateProvider);
    exchangeRateDecimal = _decimals;
  }

  function totalSupply() external view returns (uint256) {
    return IERC20Upgradeable(token).totalSupply();
  }

  function balanceOf(address account) external view returns (uint256) {
    return
      IERC20Upgradeable(token)
        .balanceOf(account)
        .mul(exchangeRateProvider.exchangeRate())
        .div(10 ** exchangeRateDecimal);
  }

  function transfer(address to, uint256 amount) external returns (bool) {
    IERC20Upgradeable(token).safeTransfer(
      to,
      amount.mul(10 ** exchangeRateDecimal).div(
        exchangeRateProvider.exchangeRate()
      )
    );
    return true;
  }

  function allowance(
    address owner,
    address spender
  ) external view returns (uint256) {
    return IERC20Upgradeable(token).allowance(owner, spender);
  }

  function approve(address spender, uint256 amount) external returns (bool) {
    IERC20Upgradeable(token).safeApprove(spender, amount);
    return true;
  }

  function transferFrom(
    address from,
    address to,
    uint256 amount
  ) external returns (bool) {
    IERC20Upgradeable(token).safeTransferFrom(
      from,
      to,
      amount.mul(10 ** exchangeRateDecimal).div(
        exchangeRateProvider.exchangeRate()
      )
    );
    return true;
  }
}
