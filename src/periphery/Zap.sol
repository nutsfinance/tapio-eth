// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { ISPAToken } from "../interfaces/ISPAToken.sol";
import { IZap } from "../interfaces/IZap.sol";

/**
 * @title Zap
 * @notice A helper contract to simplify liquidity provision and removal in Tapio
 * @dev Allows users to add/remove liquidity with automatic wrapping/unwrapping in 1 tx
 * @dev SPA and wSPA addresses are passed as parameters to each function
 */
contract Zap is IZap, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error ZeroAmount();
    error InvalidParameters();
    error CallFailed();

    /**
     * @notice Add liquidity to SPA and automatically wrap SPA tokens
     * @param spa Address of the SPA contract
     * @param wspa Address of the wrapped SPA token contract
     * @param receiver Address to receive the wrapped SPA tokens
     * @param minMintAmount Minimum amount of SPA tokens to receive
     * @param amounts Array of token amounts to add
     * @return wspaAmount Amount of wrapped SPA tokens minted
     */
    function zapIn(
        address spa,
        address wspa,
        address receiver,
        uint256 minMintAmount,
        uint256[] calldata amounts
    )
        external
        nonReentrant
        returns (uint256 wspaAmount)
    {
        require(spa != address(0) && wspa != address(0) && receiver != address(this), InvalidParameters());
        require(amounts.length > 0, InvalidParameters());
        address[] memory tokens = _getTokens(spa);
        require(amounts.length == tokens.length, InvalidParameters());

        for (uint256 i = 0; i < tokens.length; i++) {
            if (amounts[i] > 0) {
                IERC20(tokens[i]).safeTransferFrom(msg.sender, address(this), amounts[i]);
                IERC20(tokens[i]).forceApprove(spa, amounts[i]);
            }
        }

        uint256 spaAmount = _mint(spa, amounts, minMintAmount);

        for (uint256 i = 0; i < tokens.length; i++) {
            if (amounts[i] > 0) {
                IERC20(tokens[i]).forceApprove(spa, 0);
            }
        }

        address spaToken = _getPoolToken(spa);
        IERC20(spaToken).forceApprove(wspa, spaAmount);
        wspaAmount = _deposit(wspa, spaAmount, receiver);

        IERC20(spaToken).forceApprove(wspa, 0);

        emit ZapIn(spa, msg.sender, receiver, wspaAmount, amounts);
        return wspaAmount;
    }

    /**
     * @notice Remove liquidity from SPA by unwrapping SPA tokens first
     * @param spa Address of the SPA contract
     * @param wspa Address of the wrapped SPA token contract
     * @param receiver Address to receive the tokens
     * @param wspaAmount Amount of wrapped SPA tokens to redeem
     * @param minAmountsOut Minimum amounts of tokens to receive
     * @param proportional If true, withdraws proportionally; if false, uses minAmountsOut
     * @return amounts Array of token amounts received
     */
    function zapOut(
        address spa,
        address wspa,
        address receiver,
        uint256 wspaAmount,
        uint256[] calldata minAmountsOut,
        bool proportional
    )
        external
        nonReentrant
        returns (uint256[] memory amounts)
    {
        require(spa != address(0) && wspa != address(0) && receiver != address(this), InvalidParameters());
        require(wspaAmount > 0, ZeroAmount());
        address[] memory tokens = _getTokens(spa);
        require(minAmountsOut.length == tokens.length, InvalidParameters());

        IERC20(wspa).safeTransferFrom(msg.sender, address(this), wspaAmount);
        _redeem(wspa, wspaAmount, address(this));

        address spaToken = _getPoolToken(spa);
        uint256 spaAmount = ISPAToken(spaToken).balanceOf(address(this));
        IERC20(spaToken).forceApprove(spa, spaAmount);

        if (proportional) amounts = _redeemProportion(spa, spaAmount, minAmountsOut);
        else amounts = _redeemMulti(spa, minAmountsOut, spaAmount);

        IERC20(spaToken).forceApprove(spa, 0);
        // repay remaining
        ISPAToken(spaToken).transferShares(receiver, ISPAToken(spaToken).sharesOf(address(this)));

        for (uint256 i = 0; i < tokens.length; i++) {
            if (amounts[i] > 0) IERC20(tokens[i]).safeTransfer(receiver, amounts[i]);
        }

        emit ZapOut(spa, msg.sender, receiver, wspaAmount, amounts, proportional);
        return amounts;
    }

    /**
     * @notice Unwrap wSPA tokens and redeem a single asset
     * @param spa Address of the SPA contract
     * @param wspa Address of the wrapped SPA token contract
     * @param receiver Address to receive the tokens
     * @param wspaAmount Amount of wrapped SPA tokens to redeem
     * @param tokenIndex Index of the token to receive
     * @param minAmountOut Minimum amount of token to receive
     * @return amount Amount of token received
     */
    function zapOutSingle(
        address spa,
        address wspa,
        address receiver,
        uint256 wspaAmount,
        uint256 tokenIndex,
        uint256 minAmountOut
    )
        external
        nonReentrant
        returns (uint256 amount)
    {
        require(spa != address(0) && wspa != address(0) && receiver != address(this), InvalidParameters());
        require(wspaAmount > 0, ZeroAmount());
        address[] memory tokens = _getTokens(spa);
        require(tokenIndex < tokens.length, InvalidParameters());

        IERC20(wspa).safeTransferFrom(msg.sender, address(this), wspaAmount);
        _redeem(wspa, wspaAmount, address(this));

        address spaToken = _getPoolToken(spa);
        uint256 spaAmount = ISPAToken(spaToken).balanceOf(address(this));
        IERC20(spaToken).forceApprove(spa, spaAmount);
        amount = _redeemSingle(spa, spaAmount, tokenIndex, minAmountOut);

        IERC20(spaToken).forceApprove(spa, 0);
        // repay remaining
        ISPAToken(spaToken).transferShares(receiver, ISPAToken(spaToken).sharesOf(address(this)));

        IERC20(tokens[tokenIndex]).safeTransfer(receiver, amount);

        uint256[] memory amounts = new uint256[](tokens.length);
        amounts[tokenIndex] = amount;

        emit ZapOut(spa, msg.sender, receiver, wspaAmount, amounts, false);
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
     * @dev Call WSPAToken's deposit function
     */
    function _deposit(address wspa, uint256 assets, address receiver) internal returns (uint256) {
        (bool success, bytes memory data) =
            wspa.call(abi.encodeWithSignature("deposit(uint256,address)", assets, receiver));

        if (!success) _revertBytes(data);

        return abi.decode(data, (uint256));
    }

    /**
     * @dev Call WSPAToken's redeem function
     */
    function _redeem(address wspa, uint256 shares, address receiver) internal returns (uint256) {
        (bool success, bytes memory data) =
            wspa.call(abi.encodeWithSignature("redeem(uint256,address,address)", shares, receiver, address(this)));

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
     * @dev Get the pool token from SPA
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
