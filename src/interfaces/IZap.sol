// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title IZap
 * @notice Interface for Zap contract
 * @dev Defines functions to add and remove liquidity with wrapping/unwrapping in one transaction
 */
interface IZap {
    event ZapIn(
        address indexed spa, address indexed user, address indexed receiver, uint256 wspaAmount, uint256[] inputAmounts
    );
    event ZapOut(
        address indexed spa,
        address indexed user,
        address indexed receiver,
        uint256 wspaAmount,
        uint256[] outputAmounts,
        bool proportional
    );

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
        returns (uint256 wspaAmount);

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
        returns (uint256[] memory amounts);

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
        returns (uint256 amount);
}
