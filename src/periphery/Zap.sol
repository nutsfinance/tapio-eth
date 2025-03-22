// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { ILPToken } from "../interfaces/ILPToken.sol";
import { console } from "forge-std/console.sol";

/**
 * @title Zap
 * @notice A helper contract to simplify liquidity provision and removal in Tapio
 * @dev Allows users to add/remove liquidity with automatic wrapping/unwrapping in 1 tx
 */
contract Zap is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public spa;
    address public wlp;

    error ZeroAmount();
    error InsufficientAllowance();
    error SlippageExceeded();
    error InvalidParameters();
    error TransferFailed();
    error UnsupportedToken();

    event ZapIn(address indexed user, uint256 wlpAmount, uint256[] inputAmounts);
    event ZapOut(address indexed user, uint256 wlpAmount, uint256[] outputAmounts, bool proportional);

    constructor(address _spa, address _wlp) Ownable(msg.sender) {
        require(_spa != address(0) && _wlp != address(0), InvalidParameters());
        spa = _spa;
        wlp = _wlp;
    }

    /**
     * @notice Add liquidity to SPA and automatically wrap LP tokens
     * @param amounts Array of token amounts to add
     * @param minMintAmount Minimum amount of LP tokens to receive
     * @param receiver Address to receive the wrapped LP tokens
     * @return wlpAmount Amount of wrapped LP tokens minted
     */
    function zapIn(
        uint256[] calldata amounts,
        uint256 minMintAmount,
        address receiver
    )
        external
        nonReentrant
        returns (uint256 wlpAmount)
    {
        require(amounts.length > 0, InvalidParameters());
        address[] memory tokens = _getTokens();
        require(amounts.length == tokens.length, InvalidParameters());

        for (uint256 i = 0; i < tokens.length; i++) {
            if (amounts[i] > 0) {
                IERC20(tokens[i]).safeTransferFrom(msg.sender, address(this), amounts[i]);
                IERC20(tokens[i]).forceApprove(spa, amounts[i]);
            }
        }

        uint256 lpAmount = _mint(amounts, minMintAmount);

        address lpToken = _getPoolToken();
        IERC20(lpToken).forceApprove(wlp, lpAmount);
        wlpAmount = _deposit(lpAmount, receiver);

        emit ZapIn(msg.sender, wlpAmount, amounts);
        return wlpAmount;
    }

    /**
     * @notice Remove liquidity from SPA by unwrapping LP tokens first
     * @param wlpAmount Amount of wrapped LP tokens to redeem
     * @param minAmountsOut Minimum amounts of tokens to receive
     * @param receiver Address to receive the tokens
     * @param proportional If true, withdraws proportionally; if false, uses minAmountsOut
     * @return amounts Array of token amounts received
     */
    function zapOut(
        uint256 wlpAmount,
        uint256[] calldata minAmountsOut,
        address receiver,
        bool proportional
    )
        external
        nonReentrant
        returns (uint256[] memory amounts)
    {
        require(wlpAmount > 0, ZeroAmount());
        address[] memory tokens = _getTokens();
        require(minAmountsOut.length == tokens.length, InvalidParameters());

        IERC20(wlp).safeTransferFrom(msg.sender, address(this), wlpAmount);

        uint256 lpAmount = _redeem(wlpAmount, address(this));

        address lpToken = _getPoolToken();
        IERC20(lpToken).forceApprove(spa, lpAmount);
        if (proportional) amounts = _redeemProportion(lpAmount, minAmountsOut);
        else amounts = _redeemMulti(minAmountsOut, lpAmount);

        for (uint256 i = 0; i < tokens.length; i++) {
            if (amounts[i] > 0) IERC20(tokens[i]).safeTransfer(receiver, amounts[i]);
        }

        emit ZapOut(msg.sender, wlpAmount, amounts, proportional);
        return amounts;
    }

    /**
     * @notice Unwrap wLP tokens and redeem a single asset
     * @param wlpAmount Amount of wrapped LP tokens to redeem
     * @param tokenIndex Index of the token to receive
     * @param minAmountOut Minimum amount of token to receive
     * @param receiver Address to receive the tokens
     * @return amount Amount of token received
     */
    function zapOutSingle(
        uint256 wlpAmount,
        uint256 tokenIndex,
        uint256 minAmountOut,
        address receiver
    )
        external
        nonReentrant
        returns (uint256 amount)
    {
        require(wlpAmount > 0, ZeroAmount());
        address[] memory tokens = _getTokens();
        require(tokenIndex < tokens.length, InvalidParameters());

        IERC20(wlp).safeTransferFrom(msg.sender, address(this), wlpAmount);

        uint256 lpAmount = _redeem(wlpAmount, address(this));

        address lpToken = _getPoolToken();
        IERC20(lpToken).forceApprove(spa, lpAmount);
        amount = _redeemSingle(lpAmount, tokenIndex, minAmountOut);

        IERC20(tokens[tokenIndex]).safeTransfer(receiver, amount);

        uint256[] memory amounts = new uint256[](tokens.length);
        amounts[tokenIndex] = amount;

        emit ZapOut(msg.sender, wlpAmount, amounts, false);
        return amount;
    }

    /**
     * @notice Recover tokens accidentally sent to this contract
     * @param token Address of the token to recover
     * @param amount Amount to recover
     * @param to Address to send the tokens to
     */
    function recoverERC20(address token, uint256 amount, address to) external onlyOwner {
        IERC20(token).safeTransfer(to, amount);
    }

    // ============ Internal Functions ============

    /**
     * @dev Call SPA's mint function
     */
    function _mint(uint256[] calldata amounts, uint256 minMintAmount) internal returns (uint256) {
        (bool success, bytes memory data) =
            spa.call(abi.encodeWithSignature("mint(uint256[],uint256)", amounts, minMintAmount));

        if (!success) _revertBytes(data);

        return abi.decode(data, (uint256));
    }

    /**
     * @dev Call WLPToken's deposit function
     */
    function _deposit(uint256 assets, address receiver) internal returns (uint256) {
        (bool success, bytes memory data) =
            wlp.call(abi.encodeWithSignature("deposit(uint256,address)", assets, receiver));

        if (!success) _revertBytes(data);

        return abi.decode(data, (uint256));
    }

    /**
     * @dev Call WLPToken's redeem function
     */
    function _redeem(uint256 shares, address receiver) internal returns (uint256) {
        (bool success, bytes memory data) =
            wlp.call(abi.encodeWithSignature("redeem(uint256,address,address)", shares, receiver, address(this)));

        if (!success) _revertBytes(data);

        return abi.decode(data, (uint256));
    }

    /**
     * @dev Call SPA's redeemProportion function
     */
    function _redeemProportion(uint256 amount, uint256[] calldata minAmountsOut) internal returns (uint256[] memory) {
        (bool success, bytes memory data) =
            spa.call(abi.encodeWithSignature("redeemProportion(uint256,uint256[])", amount, minAmountsOut));

        if (!success) _revertBytes(data);

        return abi.decode(data, (uint256[]));
    }

    /**
     * @dev Call SPA's redeemSingle function
     */
    function _redeemSingle(uint256 amount, uint256 tokenIndex, uint256 minAmountOut) internal returns (uint256) {
        (bool success, bytes memory data) =
            spa.call(abi.encodeWithSignature("redeemSingle(uint256,uint256,uint256)", amount, tokenIndex, minAmountOut));

        if (!success) _revertBytes(data);

        return abi.decode(data, (uint256));
    }

    /**
     * @dev Call SPA's redeemMulti function
     */
    function _redeemMulti(uint256[] calldata amounts, uint256 maxRedeemAmount) internal returns (uint256[] memory) {
        (bool success, bytes memory data) =
            spa.call(abi.encodeWithSignature("redeemMulti(uint256[],uint256)", amounts, maxRedeemAmount));

        if (!success) _revertBytes(data);

        return abi.decode(data, (uint256[]));
    }

    /**
     * @dev Get the tokens from SPA
     */
    function _getTokens() internal view returns (address[] memory) {
        (bool success, bytes memory data) = spa.staticcall(abi.encodeWithSignature("getTokens()"));

        if (!success) _revertBytes(data);

        return abi.decode(data, (address[]));
    }

    /**
     * @dev Get the LP token from SPA
     */
    function _getPoolToken() internal view returns (address) {
        (bool success, bytes memory data) = spa.staticcall(abi.encodeWithSignature("poolToken()"));

        if (!success) _revertBytes(data);

        return abi.decode(data, (address));
    }

    /**
     * @dev Helper function to revert with the same error message as the original call
     */
    function _revertBytes(bytes memory data) internal pure {
        require(data.length > 0, TransferFailed());

        assembly {
            revert(add(32, data), mload(data))
        }
    }
}
