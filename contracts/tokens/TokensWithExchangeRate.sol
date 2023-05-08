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
 * @title Tokens With Exchange Rate Contract
 * @author Nuts Finance Developer
 * @dev This contract implements the IERC20 interface and extends from the Initializable and ReentrancyGuardUpgradeable contracts.
 * It provides a basic structure for tokens with exchange rate functionality.
 */
contract TokensWithExchangeRate is
  IERC20,
  Initializable,
  ReentrancyGuardUpgradeable
{
  using SafeMathUpgradeable for uint256;
  using SafeERC20Upgradeable for IERC20Upgradeable;

  /**
   * @dev The address of the token.
   */
  address public token;
  /**
   * @dev The address of the exchange rate provider.
   */
  ITokensWithExchangeRate public exchangeRateProvider;
  /**
   * @dev The decimals of the exchange rate.
   */
  uint8 public exchangeRateDecimal;

  /**
   * @dev Initializes the contract setting the deployer as the initial owner.
   * @param _token The address of the token.
   * @param _exchangeRateProvider The address of the exchange rate provider.
   * @param _decimals The decimals of the exchange rate.
   */
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

  /**
   * @dev Get the total supply of the token.
   * @return The total supply of the token.
   */
  function totalSupply() external view returns (uint256) {
    return IERC20Upgradeable(token).totalSupply();
  }

  /**
   * @dev Get the balance of an account.
   * @param account The address of the account.
   * @return The balance of the account.
   */
  function balanceOf(address account) external view returns (uint256) {
    return
      IERC20Upgradeable(token)
        .balanceOf(account)
        .mul(exchangeRateProvider.exchangeRate())
        .div(10 ** exchangeRateDecimal);
  }

  /**
   * @dev Transfer tokens to a specified address.
   * @param to The address to transfer to.
   * @param amount The amount to be transferred.
   * @return A boolean that indicates if the operation was successful.
   */
  function transfer(address to, uint256 amount) external returns (bool) {
    IERC20Upgradeable(token).safeTransfer(
      to,
      amount.mul(10 ** exchangeRateDecimal).div(
        exchangeRateProvider.exchangeRate()
      )
    );
    return true;
  }

  /**
   * @dev Get the allowance of a spender for an owner's account.
   * @param owner The address of the owner.
   * @param spender The address of the spender.
   * @return The allowance of the spender for the owner's account.
   */
  function allowance(
    address owner,
    address spender
  ) external view returns (uint256) {
    return IERC20Upgradeable(token).allowance(owner, spender);
  }

  /**
   * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
   * @param spender The address which will spend the funds.
   * @param amount The amount of tokens to be spent.
   * @return A boolean that indicates if the operation was successful.
   */
  function approve(address spender, uint256 amount) external returns (bool) {
    IERC20Upgradeable(token).safeApprove(spender, amount);
    return true;
  }

  /**
   * @dev Transfer tokens from one address to another.
   * @param from The address which you want to send tokens from.
   * @param to The address which you want to transfer to.
   * @param amount The amount of tokens to be transferred.
   * @return A boolean that indicates if the operation was successful.
   */
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
