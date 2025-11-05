// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../interfaces/IRampAController.sol";
import "../SelfPeggingAsset.sol";
import "./IParameterRegistry.sol";
import "../SPAToken.sol";

/**
 * @title IKeeper
 * @notice Interface for the Keeper contract that enforces parameter bounds for curators
 */
interface IKeeper {
    // self-descripting events for gov actions
    event RampAInitiated(uint256 oldA, uint256 newA, uint256 endTime);
    event MinRampTimeUpdated(uint256 oldTime, uint256 newTime);
    event SwapFeeUpdated(uint256 oldFee, uint256 newFee);
    event MintFeeUpdated(uint256 oldFee, uint256 newFee);
    event RedeemFeeUpdated(uint256 oldFee, uint256 newFee);
    event BufferPercentUpdated(uint256 oldBuffer, uint256 newBuffer);
    event TokenSymbolUpdated(string oldSymbol, string newSymbol);
    event FeeErrorMarginUpdated(uint256 oldMargin, uint256 newMargin);
    event YieldErrorMarginUpdated(uint256 oldMargin, uint256 newMargin);
    event LossDistributed();
    event ProtocolPaused();
    event ProtocolUnpaused();
    event RampCancelled();
    event TreasuryChanged(address indexed oldTreasury, address indexed newTreasury);
    event AdminFeeWithdrawn(address indexed to, uint256 amount, uint256 bufferLeft);
    event WholesalersUpdated(address[] wholesalers, uint16[] rates);

    /**
     * @notice Allows curators to set wholesalers and discount rates on swap fees
     * @param wholesalers Array of whitelisted wholesalers addresses
     * @param rates Array of discount rates denominated in 1e4
     */
    function setWholesalerRates(address[] memory wholesalers, uint16[] memory rates) external;

    /**
     * @notice Allows curators to gradually ramp the A coefficient within allowed bounds
     * @param newA The target A value
     * @param endTime Timestamp when ramping should complete
     */
    function rampA(uint256 newA, uint256 endTime) external;

    /**
     * @notice Set the minimum ramp time
     * @param newMinRampTime is the new minimum ramp time
     */
    function setMinRampTime(uint256 newMinRampTime) external;

    /**
     * @notice Set the swap fee within allowed bounds
     * @param newFee The new swap fee value
     */
    function setSwapFee(uint256 newFee) external;

    /**
     * @notice Set the mint fee within allowed bounds
     * @param newFee The new mint fee value
     */
    function setMintFee(uint256 newFee) external;

    /**
     * @notice Set the redeem fee within allowed bounds
     * @param newFee The new redeem fee value
     */
    function setRedeemFee(uint256 newFee) external;

    /**
     * @notice Set the buffer within allowed bounds
     * @param newBuffer The new buffer value
     */
    function setBufferPercent(uint256 newBuffer) external;

    /**
     * @notice Set the token symbol
     * @param newSymbol The new token symbol
     */
    function setTokenSymbol(string calldata newSymbol) external;

    /**
     * @notice Set the fee error margin within allowed bounds
     * @param newMargin The new fee error margin value
     */
    function updateFeeErrorMargin(uint256 newMargin) external;

    /**
     * @notice Set the yield error margin within allowed bounds
     * @param newMargin The new yield error margin value
     */
    function updateYieldErrorMargin(uint256 newMargin) external;

    /**
     * @notice Distribute any losses incurred
     */
    function distributeLoss() external;

    /**
     * @notice Pause the SPA
     */
    function pause() external;

    /**
     * @notice Unpause the SPA
     */
    function unpause() external;

    /**
     * @notice Allows guardians to cancel an ongoing A ramp in emergencies
     */
    function cancelRamp() external;

    /**
     * @notice Get the parameter registry used for bounds checking
     * @return The parameter registry address
     */
    function getRegistry() external view returns (IParameterRegistry);

    /**
     * @notice Get the RampAController being managed
     * @return The RampAController address
     */
    function getRampAController() external view returns (IRampAController);

    /**
     * @notice Get the SelfPeggingAsset being managed
     * @return The SelfPeggingAsset address
     */
    function getSpa() external view returns (SelfPeggingAsset);

    /**
     * @notice Get the SPA token being managed
     * @return The SPA token address
     */
    function getSpaToken() external view returns (SPAToken);
}
