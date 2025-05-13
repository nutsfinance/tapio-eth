// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../interfaces/IRampAController.sol";

/**
 * @title RampAController
 * @dev Contract for managing gradual changes to A coeff (A) parameter
 * Allows for smooth transitions between different A values.
 */
contract RampAController is IRampAController, Initializable, OwnableUpgradeable {
    // Constants for A parameter limits and precision
    uint256 private constant DEFAULT_RAMP_TIME = 30 minutes;

    // A parameter limits and precision
    uint256 public MAX_A;// as Curve but modifiable
    uint256 public MAX_A_CHANGE_NEG ; // Allow currentA/MAX_A_CHANGE_NEG percent decrease but modifiable
    uint256 public MAX_A_CHANGE_POS ; // Allow currentA/MAX_A_CHANGE_POS percent increase but modifiable

    uint256 public override initialA; // when starts
    uint256 public override futureA; // when completes
    uint256 public override initialATime;
    uint256 public override futureATime;
    uint256 public minRampTime;
    address public keeperController;


    // Events
    event RampInitiated(uint256 initialA, uint256 futureA, uint256 initialATime, uint256 futureATime);
    event RampStopped(uint256 currentA);
    event MinRampTimeUpdated(uint256 oldValue, uint256 newValue);
    event MaxAUpdated(uint256 previousAMax,uint256 newAMax);
    event MaxAChangeIncreased(uint256 previousALimit,uint256 newALimit);
    event MaxAChangeDecreased(uint256 previousALimit,uint256 newALimit);

    // Custom errors
    error InvalidFutureTime();
    error RampAlreadyInProgress();
    error NoOngoingRamp();
    error AOutOfBounds();
    error ExcessiveAChange();
    error InsufficientRampTime();
    error Unauthorized();

    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializer for RampAController
     * @param _initialA is the initial value of A
     * @param _minRampTime is min ramp time
     * @param _keeperController is the address of the keeper controller
     */
    function initialize(uint256 _initialA, uint256 _minRampTime,address _keeperController) external initializer {
        __Ownable_init(msg.sender);
        
        // setting constants in upgradable fashion
        MAX_A = 10 ** 6; // as Curve but modifiable
        MAX_A_CHANGE_NEG = 2; // Allow 50% decrease but modifiable
        MAX_A_CHANGE_POS = 2; // Allow 50% increase but modifiable

        if (_initialA == 0 || _initialA > MAX_A) revert AOutOfBounds();

        initialA = _initialA;
        futureA = _initialA;
        initialATime = block.timestamp;
        futureATime = block.timestamp;
        minRampTime = _minRampTime == 0 ? DEFAULT_RAMP_TIME : _minRampTime;
        keeperController = _keeperController;


        emit MinRampTimeUpdated(0, minRampTime);
    }

    /**
     * @notice Set the minimum ramp time (default is 30 minutes)
     * @param _minRampTime is the new minimum ramp time
     */
    function setMinRampTime(uint256 _minRampTime) external onlyOwner {
        uint256 oldValue = minRampTime;
        minRampTime = _minRampTime;
        emit MinRampTimeUpdated(oldValue, _minRampTime);
    }

    /**
     * @notice Set the new maximum value of A
     * @dev Can only be called by the owner
     * @param _AMax is the new maximum value of A
     */
    function setAMax(uint256 _AMax) external onlyOwner {
        emit MaxAUpdated(MAX_A,_AMax);
        MAX_A=_AMax;
    }

    /**
     * @notice Set the maximum change in A
     * @dev Can only be called by the owner
     * @param _maxChangeInAIncrease is the new maximum increase in A as a multiplier
     * @param _maxChangeInADecrease is the new maximum decrease in A as a multiplier
     */
    function setAMaxChange(uint256 _maxChangeInAIncrease, uint256 _maxChangeInADecrease) external onlyOwner {
        
        emit MaxAChangeIncreased(MAX_A_CHANGE_POS,_maxChangeInAIncrease);
        MAX_A_CHANGE_POS=_maxChangeInAIncrease;
        emit MaxAChangeDecreased(MAX_A_CHANGE_NEG,_maxChangeInADecrease);
        MAX_A_CHANGE_NEG=_maxChangeInADecrease;
    }


    /**
     * @notice Initiate a ramp to a new A value
     * @param _futureA is the target value of A
     * @param _futureTime is UNIX timestamp when the ramp should complete
     */
    function rampA(uint256 _futureA, uint256 _futureTime) external override onlyOwner {
        if (_futureTime <= block.timestamp) revert InvalidFutureTime();
        if (block.timestamp < futureATime) revert RampAlreadyInProgress();
        if (_futureA == 0 || _futureA > MAX_A) revert AOutOfBounds();
        if (_futureTime - block.timestamp < minRampTime) revert InsufficientRampTime();

        // should be static
        uint256 _initialA = getA();

        if (_initialA <= 2) {
            uint256 maxMultiplier = 11 - _initialA; // 10 for initialA=1, 9 for initialA=2
            if (_futureA > _initialA * maxMultiplier) revert ExcessiveAChange();
        } else if (_futureA > _initialA) {
            // A increasing, check if futureA <= initialA * (1 + 1/MAX_A_CHANGE)
            if (_futureA * MAX_A_CHANGE_POS > _initialA * (MAX_A_CHANGE_POS + 1)) revert ExcessiveAChange();
        } else {
            // A decreasing, check if initialA <= futureA * MAX_A_CHANGE
            if (_initialA > _futureA * MAX_A_CHANGE_NEG) revert ExcessiveAChange();
        }

        initialA = _initialA;
        futureA = _futureA;
        initialATime = block.timestamp;
        futureATime = _futureTime;

        emit RampInitiated(_initialA, _futureA, block.timestamp, _futureTime);
    }

    /**
     * @notice Force-stop ramping A coeff
     */
    function stopRamp() external override onlyOwner {
        if (block.timestamp >= futureATime) revert NoOngoingRamp();
        uint256 currentA = getA();

        initialA = currentA;
        futureA = currentA;
        initialATime = block.timestamp;
        futureATime = block.timestamp;

        emit RampStopped(currentA);
    }

    /**
     * @notice Check if ramping in progress
     * @return true if it is, false otherwise
     */
    function isRamping() external view override returns (bool) {
        return block.timestamp < futureATime;
    }

    /**
     * @notice Public getter which is used in SPA
     * @return the current value of A coeff
     */
    function getA() public view override returns (uint256) {
        if (block.timestamp >= futureATime) return futureA;
        if (block.timestamp <= initialATime) return initialA;

        uint256 timeElapsed = block.timestamp - initialATime;
        uint256 totalRampTime = futureATime - initialATime;

        // interpolate
        if (futureA > initialA) {
            // A is increasing
            return initialA + (futureA - initialA) * timeElapsed / totalRampTime;
        } else {
            // A is decreasing
            return initialA - (initialA - futureA) * timeElapsed / totalRampTime;
        }
    }
}
