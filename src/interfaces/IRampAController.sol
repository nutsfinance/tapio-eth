// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title IRampAController
 * @dev Interface for the RampAController contract that manages gradual A parameter changes
 */
interface IRampAController {
    /**
     * @dev Initiates the ramping of A from current value to the target over the specified duration
     * @param _futureA Target A value
     * @param _futureTime Timestamp when ramping should complete
     */
    function rampA(uint256 _futureA, uint256 _futureTime) external;

    /**
     * @dev Stops an ongoing ramp and freezes A at the current value
     */
    function stopRamp() external;

    /**
     * @dev Returns the current A value based on the ongoing ramp progress or the static value if no ramp
     * @return The current A value
     */
    function getA() external view returns (uint256);

    /**
     * @dev Checks if the controller is currently in a ramping state
     * @return True if ramping, false otherwise
     */
    function isRamping() external view returns (bool);

    /**
     * @dev Returns the initial A value for the current/most recent ramp
     * @return The initial A value
     */
    function initialA() external view returns (uint256);

    /**
     * @dev Returns the target A value for the current/most recent ramp
     * @return The target A value
     */
    function futureA() external view returns (uint256);

    /**
     * @dev Returns the timestamp when the current/most recent ramp started
     * @return The timestamp
     */
    function initialATime() external view returns (uint256);

    /**
     * @dev Returns the timestamp when the current/most recent ramp will/did complete
     * @return The timestamp
     */
    function futureATime() external view returns (uint256);
}