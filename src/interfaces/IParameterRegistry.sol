// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IParameterRegistry
 */
interface IParameterRegistry {
    /**
     * @notice Unique keys identifying different parameter types.
     */
    enum ParamKey {
        A,
        SwapFee,
        MintFee,
        RedeemFee,
        OffPeg,
        ExchangeRateFee,
        DecayPeriod,
        RateChangeSkipPeriod,
        FeeErrorMargin,
        YieldErrorMargin,
        MinRampTime,
        BufferPercent
    }

    /**
     * @notice Structure representing bounds for a given parameter.
     * @dev All percentages are expressed in parts-per-million (ppm), i.e., 1e6 = 100%.
     * @param max The maximum hard cap for the parameter value in parameter format.
     * @param min The minimum hard cap for the parameter value in parameter format.
     * @param maxDecreasePct The maximum decrease allowed per transaction with 1e10 decimal, e.g., 9e9 = -90%.
     * @param maxIncreasePct The maximum increase allowed per transaction with 1e10 decimal, e.g., 9e9 = +90%.
     */
    struct Bounds {
        uint256 max;
        uint256 min;
        uint64 maxDecreasePct;
        uint64 maxIncreasePct;
    }

    /**
     * @notice Emitted when parameter bounds are updated.
     * @param key The parameter key that was updated.
     * @param oldParams The old bounds before the update.
     * @param newParams The new bounds after the update.
     */
    event BoundsUpdated(ParamKey key, Bounds oldParams, Bounds newParams);

    error ZeroAddress();

    /**
     * @notice Updates the bounds for a specific parameter.
     * @dev Only callable by an authorized governor.
     * @param key The parameter key to update.
     * @param newBounds The new bounds structure to apply.
     */
    function setBounds(ParamKey key, Bounds calldata newBounds) external;

    /// @return Bounds for the 'A' coefficient parameter
    function aParams() external view returns (Bounds memory);

    /// @return Bounds for the swap fee
    function swapFeeParams() external view returns (Bounds memory);

    /// @return Bounds for the mint fee
    function mintFeeParams() external view returns (Bounds memory);

    /// @return Bounds for the redeem fee
    function redeemFeeParams() external view returns (Bounds memory);

    /// @return Bounds for the off-peg multiplier
    function offPegParams() external view returns (Bounds memory);

    /// @return Bounds for exchange rate fee changes
    function exchangeRateFeeParams() external view returns (Bounds memory);

    /// @return Bounds for decay period
    function decayPeriodParams() external view returns (Bounds memory);

    /// @return Bounds for the rate change skip period
    function rateChangeSkipPeriodParams() external view returns (Bounds memory);

    /// @return Bounds for the fee error margin
    function feeErrorMarginParams() external view returns (Bounds memory);

    /// @return Bounds for the yield error margin
    function yieldErrorMarginParams() external view returns (Bounds memory);

    /// @return Bounds for the minimum ramp time
    function minRampTimeParams() external view returns (Bounds memory);

    /// @return Bounds for the buffer percentage
    function bufferPercentParams() external view returns (Bounds memory);
}
