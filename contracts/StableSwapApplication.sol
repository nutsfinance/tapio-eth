// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "./interfaces/IWETH.sol";
import "./StableSwap.sol";

contract StableSwapApplication is Initializable, ReentrancyGuardUpgradeable {
  using SafeMathUpgradeable for uint256;
  using SafeERC20Upgradeable for IERC20Upgradeable;

  IWETH public wETH;

  function initialize(IWETH _wETH) public initializer {
    require(address(_wETH) != address(0x0), "wETH not set");
    wETH = _wETH;
  }

  receive() external payable {
    assert(msg.sender == address(wETH)); // only accept ETH via fallback from the WETH contract
  }

  /**
   * @dev Mints new pool token and wrap ETH.
   * @param _swap Underlying stable swap address.
   * @param _amounts Unconverted token balances used to mint pool token.
   * @param _minMintAmount Minimum amount of pool token to mint.
   */
  function mint(
    StableSwap _swap,
    uint256[] calldata _amounts,
    uint256 _minMintAmount
  ) external payable nonReentrant {
    address[] memory tokens = _swap.getTokens();
    address poolToken = _swap.getPoolToken();
    uint256 wETHIndex = findWETHIndex(tokens);
    require(_amounts[wETHIndex] == msg.value, "msg.value equals amounts");

    wETH.deposit{value: _amounts[wETHIndex]}();
    for (uint256 i = 0; i < tokens.length; i++) {
      if (i != wETHIndex) {
        IERC20Upgradeable(tokens[i]).safeTransferFrom(
          msg.sender,
          address(this),
          _amounts[i]
        );
      }
      IERC20Upgradeable(tokens[i]).safeApprove(address(_swap), _amounts[i]);
    }
    uint256 mintAmount = _swap.mint(_amounts, _minMintAmount);
    IERC20Upgradeable(poolToken).safeTransfer(msg.sender, mintAmount);
  }

  /**
   * @dev Exchange between two underlying tokens with wrap/unwrap ETH.
   * @param _swap Underlying stable swap address.
   * @param _i Token index to swap in.
   * @param _j Token index to swap out.
   * @param _dx Unconverted amount of token _i to swap in.
   * @param _minDy Minimum token _j to swap out in converted balance.
   */
  function swap(
    StableSwap _swap,
    uint256 _i,
    uint256 _j,
    uint256 _dx,
    uint256 _minDy
  ) external payable nonReentrant {
    address[] memory tokens = _swap.getTokens();
    uint256 wETHIndex = findWETHIndex(tokens);

    if (_i == wETHIndex) {
      require(_dx == msg.value, "msg.value equals amounts");
      wETH.deposit{value: _dx}();
    } else {
      IERC20Upgradeable(tokens[_i]).safeTransferFrom(
        msg.sender,
        address(this),
        _dx
      );
    }
    IERC20Upgradeable(tokens[_i]).safeApprove(address(_swap), _dx);
    uint256 swapAmount = _swap.swap(_i, _j, _dx, _minDy);

    if (_j == wETHIndex) {
      wETH.withdraw(swapAmount);
      payable(msg.sender).transfer(swapAmount);
    } else {
      IERC20Upgradeable(tokens[_j]).safeTransfer(msg.sender, swapAmount);
    }
  }

  /**
   * @dev Redeems pool token to underlying tokens proportionally with unwrap ETH.
   * @param _swap Underlying stable swap address.
   * @param _amount Amount of pool token to redeem.
   * @param _minRedeemAmounts Minimum amount of underlying tokens to get.
   */
  function redeemProportion(
    StableSwap _swap,
    uint256 _amount,
    uint256[] calldata _minRedeemAmounts
  ) external nonReentrant {
    address[] memory tokens = _swap.getTokens();
    address poolToken = _swap.getPoolToken();
    uint256 wETHIndex = findWETHIndex(tokens);

    IERC20Upgradeable(poolToken).safeApprove(address(_swap), _amount);
    IERC20Upgradeable(poolToken).safeTransferFrom(
      msg.sender,
      address(this),
      _amount
    );

    uint256[] memory amounts = _swap.redeemProportion(
      _amount,
      _minRedeemAmounts
    );

    for (uint256 i = 0; i < tokens.length; i++) {
      if (i == wETHIndex) {
        wETH.withdraw(amounts[i]);
        payable(msg.sender).transfer(amounts[i]);
      } else {
        IERC20Upgradeable(tokens[i]).safeTransfer(msg.sender, amounts[i]);
      }
    }
  }

  function findWETHIndex(
    address[] memory tokens
  ) internal view returns (uint256) {
    for (uint256 i = 0; i < tokens.length; i++) {
      if (tokens[i] == address(wETH)) {
        return i;
      }
    }
    revert("wETH not found");
  }
}
