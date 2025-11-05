// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IParameterRegistry.sol";
import "../SelfPeggingAsset.sol";

/**
 * @title ParameterRegistry
 * @notice Stores hard caps and per-transaction relative ranges that bound keeper operations.
 * @dev Only the Governor (admin role) can modify values.
 * Each SPA has its own ParameterRegistry
 */
contract ParameterRegistry is IParameterRegistry, Ownable {

    uint256 private constant MAX_A = 10 ** 6; // 1M
    uint64 private constant MAX_DECREASE_PCT_A = 0.9e10; // -90%
    uint64 private constant MAX_INCREASE_PCT_A = 9e10; // +900%

    /// @notice SPA this registry is connected
    SelfPeggingAsset public spa;

    mapping(ParamKey => Bounds) public bounds;

    constructor(address _governor, address _spa) Ownable(_governor) {
        require(_spa != address(0), ZeroAddress());

        spa = SelfPeggingAsset(_spa);

        // set default values for A boundry
        bounds[ParamKey.A] =
            Bounds({ max: MAX_A, min: 0, maxDecreasePct: MAX_DECREASE_PCT_A, maxIncreasePct: MAX_INCREASE_PCT_A });
    }

    /**
     * @inheritdoc IParameterRegistry
     */
    function setBounds(ParamKey key, Bounds calldata newBounds) external onlyOwner {
        emit BoundsUpdated(key, bounds[key], newBounds);
        bounds[key] = newBounds;
    }

    /**
     * @inheritdoc IParameterRegistry
     */
    function aParams() external view returns (Bounds memory) {
        return bounds[ParamKey.A];
    }

    /**
     * @inheritdoc IParameterRegistry
     */
    function wholesalerRateParams() external view returns (Bounds memory) {
        return bounds[ParamKey.WholesalerRate];
    }

    /**
     * @inheritdoc IParameterRegistry
     */
    function swapFeeParams() external view returns (Bounds memory) {
        return bounds[ParamKey.SwapFee];
    }

    /**
     * @inheritdoc IParameterRegistry
     */
    function mintFeeParams() external view returns (Bounds memory) {
        return bounds[ParamKey.MintFee];
    }

    /**
     * @inheritdoc IParameterRegistry
     */
    function redeemFeeParams() external view returns (Bounds memory) {
        return bounds[ParamKey.RedeemFee];
    }

    /**
     * @inheritdoc IParameterRegistry
     */
    function feeErrorMarginParams() external view returns (Bounds memory) {
        return bounds[ParamKey.FeeErrorMargin];
    }

    /**
     * @inheritdoc IParameterRegistry
     */
    function yieldErrorMarginParams() external view returns (Bounds memory) {
        return bounds[ParamKey.YieldErrorMargin];
    }

    /**
     * @inheritdoc IParameterRegistry
     */
    function minRampTimeParams() external view returns (Bounds memory) {
        return bounds[ParamKey.MinRampTime];
    }

    /**
     * @inheritdoc IParameterRegistry
     */
    function bufferPercentParams() external view returns (Bounds memory) {
        return bounds[ParamKey.BufferPercent];
    }
}
