// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { ILPToken } from "../interfaces/ILPToken.sol";
import { IZap } from "../interfaces/IZap.sol";

/**
 * @title Zap
 * @notice A helper contract to simplify liquidity provision and removal in Tapio
 * @dev Allows users to add/remove liquidity with automatic wrapping/unwrapping in 1 tx
 * @dev SPA and wLP addresses are passed as parameters to each function
 */
contract Zap is IZap, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error ZeroAmount();
    error InvalidParameters();
    error CallFailed();

    /**
     * @notice Add liquidity to SPA and automatically wrap LP tokens
     * @param spa Address of the SPA contract
     * @param wlp Address of the wrapped LP token contract
     * @param receiver Address to receive the wrapped LP tokens
     * @param minMintAmount Minimum amount of LP tokens to receive
     * @param amounts Array of token amounts to add
     * @return wlpAmount Amount of wrapped LP tokens minted
     */
    function zapIn(
        address spa,
        address wlp,
        address receiver,
        uint256 minMintAmount,
        uint256[] calldata amounts
    )
        external
        nonReentrant
        returns (uint256 wlpAmount)
    {
        require(spa != address(0) && wlp != address(0) && receiver != address(this), InvalidParameters());
        require(amounts.length > 0, InvalidParameters());
        address[] memory tokens = _getTokens(spa);
        require(amounts.length == tokens.length, InvalidParameters());

        for (uint256 i = 0; i < tokens.length; i++) {
            if (amounts[i] > 0) {
                IERC20(tokens[i]).safeTransferFrom(msg.sender, address(this), amounts[i]);
                IERC20(tokens[i]).forceApprove(spa, amounts[i]);
            }
        }

        uint256 lpAmount = _mint(spa, amounts, minMintAmount);

        for (uint256 i = 0; i < tokens.length; i++) {
            if (amounts[i] > 0) {
                IERC20(tokens[i]).forceApprove(spa, 0);
            }
        }

        address lpToken = _getPoolToken(spa);
        IERC20(lpToken).forceApprove(wlp, lpAmount);
        wlpAmount = _deposit(wlp, lpAmount, receiver);

        IERC20(lpToken).forceApprove(wlp, 0);

        emit ZapIn(spa, msg.sender, receiver, wlpAmount, amounts);
        return wlpAmount;
    }

    /**
     * @notice Remove liquidity from SPA by unwrapping LP tokens first
     * @param spa Address of the SPA contract
     * @param wlp Address of the wrapped LP token contract
     * @param receiver Address to receive the tokens
     * @param wlpAmount Amount of wrapped LP tokens to redeem
     * @param minAmountsOut Minimum amounts of tokens to receive
     * @param proportional If true, withdraws proportionally; if false, uses minAmountsOut
     * @return amounts Array of token amounts received
     */
    function zapOut(
        address spa,
        address wlp,
        address receiver,
        uint256 wlpAmount,
        uint256[] calldata minAmountsOut,
        bool proportional
    )
        external
        nonReentrant
        returns (uint256[] memory amounts)
    {
        require(spa != address(0) && wlp != address(0) && receiver != address(this), InvalidParameters());
        require(wlpAmount > 0, ZeroAmount());
        address[] memory tokens = _getTokens(spa);
        require(minAmountsOut.length == tokens.length, InvalidParameters());

        IERC20(wlp).safeTransferFrom(msg.sender, address(this), wlpAmount);
        _redeem(wlp, wlpAmount, address(this));

        address lpToken = _getPoolToken(spa);
        uint256 lpAmount = ILPToken(lpToken).balanceOf(address(this));
        IERC20(lpToken).forceApprove(spa, lpAmount);

        if (proportional) amounts = _redeemProportion(spa, lpAmount, minAmountsOut);
        else amounts = _redeemMulti(spa, minAmountsOut, lpAmount);

        IERC20(lpToken).forceApprove(spa, 0);
        // repay remaining
        ILPToken(lpToken).transferShares(receiver, ILPToken(lpToken).sharesOf(address(this)));

        for (uint256 i = 0; i < tokens.length; i++) {
            if (amounts[i] > 0) IERC20(tokens[i]).safeTransfer(receiver, amounts[i]);
        }

        emit ZapOut(spa, msg.sender, receiver, wlpAmount, amounts, proportional);
        return amounts;
    }

    /**
     * @notice Unwrap wLP tokens and redeem a single asset
     * @param spa Address of the SPA contract
     * @param wlp Address of the wrapped LP token contract
     * @param receiver Address to receive the tokens
     * @param wlpAmount Amount of wrapped LP tokens to redeem
     * @param tokenIndex Index of the token to receive
     * @param minAmountOut Minimum amount of token to receive
     * @return amount Amount of token received
     */
    function zapOutSingle(
        address spa,
        address wlp,
        address receiver,
        uint256 wlpAmount,
        uint256 tokenIndex,
        uint256 minAmountOut
    )
        external
        nonReentrant
        returns (uint256 amount)
    {
        require(spa != address(0) && wlp != address(0) && receiver != address(this), InvalidParameters());
        require(wlpAmount > 0, ZeroAmount());
        address[] memory tokens = _getTokens(spa);
        require(tokenIndex < tokens.length, InvalidParameters());

        IERC20(wlp).safeTransferFrom(msg.sender, address(this), wlpAmount);
        _redeem(wlp, wlpAmount, address(this));

        address lpToken = _getPoolToken(spa);
        uint256 lpAmount = ILPToken(lpToken).balanceOf(address(this));
        IERC20(lpToken).forceApprove(spa, lpAmount);
        amount = _redeemSingle(spa, lpAmount, tokenIndex, minAmountOut);

        IERC20(lpToken).forceApprove(spa, 0);
        // repay remaining
        ILPToken(lpToken).transferShares(receiver, ILPToken(lpToken).sharesOf(address(this)));

        IERC20(tokens[tokenIndex]).safeTransfer(receiver, amount);

        uint256[] memory amounts = new uint256[](tokens.length);
        amounts[tokenIndex] = amount;

        emit ZapOut(spa, msg.sender, receiver, wlpAmount, amounts, false);
        return amount;
    }

    // ============ Internal Functions ============

    /**
     * @dev Call SPA's mint function
     */
    function _mint(address spa, uint256[] calldata amounts, uint256 minMintAmount) internal returns (uint256) {
        (bool success, bytes memory data) =
            spa.call(abi.encodeWithSignature("mint(uint256[],uint256)", amounts, minMintAmount));

        if (!success) _revertBytes(data);

        return abi.decode(data, (uint256));
    }

    /**
     * @dev Call WLPToken's deposit function
     */
    function _deposit(address wlp, uint256 assets, address receiver) internal returns (uint256) {
        (bool success, bytes memory data) =
            wlp.call(abi.encodeWithSignature("deposit(uint256,address)", assets, receiver));

        if (!success) _revertBytes(data);

        return abi.decode(data, (uint256));
    }

    /**
     * @dev Call WLPToken's redeem function
     */
    function _redeem(address wlp, uint256 shares, address receiver) internal returns (uint256) {
        (bool success, bytes memory data) =
            wlp.call(abi.encodeWithSignature("redeem(uint256,address,address)", shares, receiver, address(this)));

        if (!success) _revertBytes(data);

        return abi.decode(data, (uint256));
    }

    /**
     * @dev Call SPA's redeemProportion function
     */
    function _redeemProportion(
        address spa,
        uint256 amount,
        uint256[] calldata minAmountsOut
    )
        internal
        returns (uint256[] memory)
    {
        (bool success, bytes memory data) =
            spa.call(abi.encodeWithSignature("redeemProportion(uint256,uint256[])", amount, minAmountsOut));

        if (!success) _revertBytes(data);

        return abi.decode(data, (uint256[]));
    }

    /**
     * @dev Call SPA's redeemSingle function
     */
    function _redeemSingle(
        address spa,
        uint256 amount,
        uint256 tokenIndex,
        uint256 minAmountOut
    )
        internal
        returns (uint256)
    {
        (bool success, bytes memory data) =
            spa.call(abi.encodeWithSignature("redeemSingle(uint256,uint256,uint256)", amount, tokenIndex, minAmountOut));

        if (!success) _revertBytes(data);

        return abi.decode(data, (uint256));
    }

    /**
     * @dev Call SPA's redeemMulti function
     */
    function _redeemMulti(
        address spa,
        uint256[] calldata amounts,
        uint256 maxRedeemAmount
    )
        internal
        returns (uint256[] memory)
    {
        (bool success, bytes memory data) =
            spa.call(abi.encodeWithSignature("redeemMulti(uint256[],uint256)", amounts, maxRedeemAmount));

        if (!success) _revertBytes(data);

        return abi.decode(data, (uint256[]));
    }

    /**
     * @dev Get the tokens from SPA
     */
    function _getTokens(address spa) internal view returns (address[] memory) {
        (bool success, bytes memory data) = spa.staticcall(abi.encodeWithSignature("getTokens()"));

        if (!success) _revertBytes(data);

        return abi.decode(data, (address[]));
    }

    /**
     * @dev Get the LP token from SPA
     */
    function _getPoolToken(address spa) internal view returns (address) {
        (bool success, bytes memory data) = spa.staticcall(abi.encodeWithSignature("poolToken()"));

        if (!success) _revertBytes(data);

        return abi.decode(data, (address));
    }

    /**
     * @dev Helper function to revert with the same error message as the original call
     */
    function _revertBytes(bytes memory data) internal pure {
        require(data.length > 0, CallFailed());

        assembly {
            revert(add(32, data), mload(data))
        }
    }
}
