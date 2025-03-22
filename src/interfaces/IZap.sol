// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title IZap
 * @notice Interface for Zap contract
 * @dev Defines functions to add and remove liquidity with wrapping/unwrapping in one transaction
 */
interface IZap {
    event ZapIn(address indexed user, address indexed receiver, uint256 wlpAmount, uint256[] inputAmounts);
    event ZapOut(
        address indexed user, address indexed receiver, uint256 wlpAmount, uint256[] outputAmounts, bool proportional
    );

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
        returns (uint256 wlpAmount);

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
        returns (uint256[] memory amounts);

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
        returns (uint256 amount);

    /**
     * @notice Recover tokens accidentally sent to this contract
     * @param token Address of the token to recover
     * @param amount Amount to recover
     * @param to Address to send the tokens to
     */
    function recoverERC20(address token, uint256 amount, address to) external;
}
