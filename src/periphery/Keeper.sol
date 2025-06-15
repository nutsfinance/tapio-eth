// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../interfaces/IRampAController.sol";
import "../interfaces/IParameterRegistry.sol";
import "../interfaces/IKeeper.sol";
import "../SelfPeggingAsset.sol";
import "../LPToken.sol";

/**
 * @title Keeper
 * @notice Follows Tapio Governance model
 * @notice Fast-path executor that lets curators adjust parameters within bounds enforced by ParameterRegistry
 * @dev UUPS upgradeable. Governor is admin, curator and guardian are roles.
 */
contract Keeper is AccessControlUpgradeable, UUPSUpgradeable, IKeeper {
    /**
     * @dev This is the denominator used for formatting ranges
     */
    uint256 private constant DENOMINATOR = 1e10;

    bytes32 public constant PROTOCOL_OWNER_ROLE = keccak256("PROTOCOL_OWNER_ROLE");
    bytes32 public constant CURATOR_ROLE = keccak256("CURATOR_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    IParameterRegistry private registry;
    IRampAController private rampAController;
    SelfPeggingAsset private spa;
    LPToken private lpToken;

    // Address that receives withdrawn LP tokens from Buffer
    address public treasury;

    error ZeroAddress();
    error OutOfBounds();
    error DeltaTooBig();
    error RelativeRangeNotSet();
    error WrongSymbol();

    /**
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _owner,
        address _governor,
        address _curator,
        address _guardian,
        IParameterRegistry _registry,
        IRampAController _rampAController,
        SelfPeggingAsset _spa,
        LPToken _lpToken
    )
        public
        initializer
    {
        require(_governor != address(0), ZeroAddress());
        require(_curator != address(0), ZeroAddress());
        require(_guardian != address(0), ZeroAddress());
        require(address(_registry) != address(0), ZeroAddress());
        require(address(_rampAController) != address(0), ZeroAddress());
        require(address(_spa) != address(0), ZeroAddress());
        require(address(_lpToken) != address(0), ZeroAddress());

        __AccessControl_init();
        __UUPSUpgradeable_init();

        registry = _registry;
        rampAController = _rampAController;
        spa = _spa;
        lpToken = _lpToken;

        // Role assignment
        _grantRole(PROTOCOL_OWNER_ROLE, _owner);
        _grantRole(GOVERNOR_ROLE, _governor);
        _grantRole(CURATOR_ROLE, _curator);
        _grantRole(GUARDIAN_ROLE, _guardian);
        _setRoleAdmin(GUARDIAN_ROLE, GOVERNOR_ROLE);
        _setRoleAdmin(CURATOR_ROLE, GOVERNOR_ROLE);
        _setRoleAdmin(GOVERNOR_ROLE, PROTOCOL_OWNER_ROLE);

        // initialise treasury as governor by default
        treasury = _governor;
    }

    /**
     * @inheritdoc IKeeper
     */
    function rampA(uint256 newA, uint256 endTime) external override onlyRole(CURATOR_ROLE) {
        IParameterRegistry.Bounds memory aParams = registry.aParams();

        uint256 curA = rampAController.getA();
        if (curA <= 2) {
            uint256 maxMultiplier = 11 - curA; // 10 for initialA=1, 9 for initialA=2
            require(newA <= curA * maxMultiplier, OutOfBounds());
        } else if (aParams.maxDecreasePct == 0 && aParams.maxIncreasePct == 0) {
            // no relative bounds set
            revert RelativeRangeNotSet();
        }

        checkBounds(newA, curA, aParams);

        rampAController.rampA(newA, endTime);
        emit RampAInitiated(curA, newA, endTime);
    }

    /**
     * @inheritdoc IKeeper
     */
    function setMinRampTime(uint256 newMinRampTime) external override onlyRole(GOVERNOR_ROLE) {
        IParameterRegistry.Bounds memory minRampTimeParams = registry.minRampTimeParams();

        uint256 curMinRampTime = rampAController.minRampTime();
        checkBounds(newMinRampTime, curMinRampTime, minRampTimeParams);

        rampAController.setMinRampTime(newMinRampTime);
        emit MinRampTimeUpdated(curMinRampTime, newMinRampTime);
    }

    /**
     * @inheritdoc IKeeper
     */
    function setSwapFee(uint256 newFee) external override onlyRole(GOVERNOR_ROLE) {
        IParameterRegistry.Bounds memory swapFeeParams = registry.swapFeeParams();

        uint256 cur = spa.swapFee();
        checkBounds(newFee, cur, swapFeeParams);

        spa.setSwapFee(newFee);
        emit SwapFeeUpdated(cur, newFee);
    }

    /**
     * @inheritdoc IKeeper
     */
    function setMintFee(uint256 newFee) external override onlyRole(GOVERNOR_ROLE) {
        IParameterRegistry.Bounds memory mintFeeParams = registry.mintFeeParams();

        uint256 cur = spa.mintFee();
        checkBounds(newFee, cur, mintFeeParams);

        spa.setMintFee(newFee);
        emit MintFeeUpdated(cur, newFee);
    }

    /**
     * @inheritdoc IKeeper
     */
    function setRedeemFee(uint256 newFee) external override onlyRole(GOVERNOR_ROLE) {
        IParameterRegistry.Bounds memory redeemFeeParams = registry.redeemFeeParams();

        uint256 cur = spa.redeemFee();
        checkBounds(newFee, cur, redeemFeeParams);

        spa.setRedeemFee(newFee);
        emit RedeemFeeUpdated(cur, newFee);
    }

    /**
     * @inheritdoc IKeeper
     */
    function cancelRamp() external override onlyRole(GUARDIAN_ROLE) {
        rampAController.stopRamp();
        emit RampCancelled();
    }

    /**
     * @inheritdoc IKeeper
     */
    function setOffPegFeeMultiplier(uint256 newMultiplier) external override onlyRole(GOVERNOR_ROLE) {
        IParameterRegistry.Bounds memory offPegParams = registry.offPegParams();

        uint256 cur = spa.offPegFeeMultiplier();
        checkBounds(newMultiplier, cur, offPegParams);

        spa.setOffPegFeeMultiplier(newMultiplier);
        emit OffPegFeeMultiplierUpdated(cur, newMultiplier);
    }

    /**
     * @inheritdoc IKeeper
     */
    function setExchangeRateFeeFactor(uint256 newFeeFactor) external override onlyRole(GOVERNOR_ROLE) {
        IParameterRegistry.Bounds memory exchangeRateFeeParams = registry.exchangeRateFeeParams();

        uint256 cur = spa.exchangeRateFeeFactor();
        checkBounds(newFeeFactor, cur, exchangeRateFeeParams);

        spa.setExchangeRateFeeFactor(newFeeFactor);
        emit ExchangeRateFeeFactorUpdated(cur, newFeeFactor);
    }

    /**
     * @inheritdoc IKeeper
     */
    function setBufferPercent(uint256 newBuffer) external override onlyRole(GOVERNOR_ROLE) {
        IParameterRegistry.Bounds memory bufferParams = registry.bufferPercentParams();

        uint256 cur = lpToken.bufferPercent();
        checkBounds(newBuffer, cur, bufferParams);

        lpToken.setBuffer(newBuffer);
        emit BufferPercentUpdated(cur, newBuffer);
    }

    /**
     * @inheritdoc IKeeper
     */
    function setTokenSymbol(string calldata newSymbol) external override onlyRole(GOVERNOR_ROLE) {
        string memory cur = lpToken.symbol();
        require(
            bytes(newSymbol).length > 0 && keccak256(abi.encodePacked(cur)) != keccak256(abi.encodePacked(newSymbol)),
            WrongSymbol()
        );

        lpToken.setSymbol(newSymbol);
        emit TokenSymbolUpdated(cur, newSymbol);
    }

    /**
     * @inheritdoc IKeeper
     */
    function setDecayPeriod(uint256 newDecayPeriod) external override onlyRole(GOVERNOR_ROLE) {
        IParameterRegistry.Bounds memory decayPeriodParams = registry.decayPeriodParams();

        uint256 cur = spa.decayPeriod();
        checkBounds(newDecayPeriod, cur, decayPeriodParams);

        spa.setDecayPeriod(newDecayPeriod);
        emit DecayPeriodUpdated(cur, newDecayPeriod);
    }

    /**
     * @inheritdoc IKeeper
     */
    function setRateChangeSkipPeriod(uint256 newSkipPeriod) external override onlyRole(GOVERNOR_ROLE) {
        IParameterRegistry.Bounds memory rateChangeSkipPeriodParams = registry.rateChangeSkipPeriodParams();

        uint256 cur = spa.rateChangeSkipPeriod();
        checkBounds(newSkipPeriod, cur, rateChangeSkipPeriodParams);

        spa.setRateChangeSkipPeriod(newSkipPeriod);
        emit RateChangeSkipPeriodUpdated(cur, newSkipPeriod);
    }

    /**
     * @inheritdoc IKeeper
     */
    function updateFeeErrorMargin(uint256 newMargin) external override onlyRole(GOVERNOR_ROLE) {
        IParameterRegistry.Bounds memory feeErrorMarginParams = registry.feeErrorMarginParams();

        uint256 cur = spa.feeErrorMargin();
        checkBounds(newMargin, cur, feeErrorMarginParams);

        spa.updateFeeErrorMargin(newMargin);
        emit FeeErrorMarginUpdated(cur, newMargin);
    }

    /**
     * @inheritdoc IKeeper
     */
    function updateYieldErrorMargin(uint256 newMargin) external override onlyRole(GOVERNOR_ROLE) {
        IParameterRegistry.Bounds memory yieldErrorMarginParams = registry.yieldErrorMarginParams();

        uint256 cur = spa.yieldErrorMargin();
        checkBounds(newMargin, cur, yieldErrorMarginParams);

        spa.updateYieldErrorMargin(newMargin);
        emit YieldErrorMarginUpdated(cur, newMargin);
    }

    /**
     * @inheritdoc IKeeper
     */
    function distributeLoss() external override onlyRole(GOVERNOR_ROLE) {
        spa.distributeLoss();
        emit LossDistributed();
    }

    /**
     * @notice Set treasury address that will receive withdrawn LP tokens from Buffer
     */
    function setTreasury(address newTreasury) external onlyRole(GOVERNOR_ROLE) {
        require(newTreasury != address(0), ZeroAddress());
        emit TreasuryChanged(treasury, newTreasury);
        treasury = newTreasury;
    }

    /**
     * @notice Withdraw Buffer through LPToken and send newly-minted LP tokens to Treasury
     * @param amount Amount of tokens to withdraw (18-decimals)
     */
    function withdrawAdminFee(uint256 amount) external onlyRole(GOVERNOR_ROLE) {
        lpToken.withdrawBuffer(treasury, amount);
        emit AdminFeeWithdrawn(treasury, amount, lpToken.bufferAmount());
    }

    /**
     * @inheritdoc IKeeper
     */
    function pause() external override onlyRole(GUARDIAN_ROLE) {
        spa.pause();
        emit ProtocolPaused();
    }

    /**
     * @inheritdoc IKeeper
     */
    function unpause() external override onlyRole(PROTOCOL_OWNER_ROLE) {
        spa.unpause();
        emit ProtocolUnpaused();
    }

    /**
     * @inheritdoc IKeeper
     */
    function getRegistry() external view override returns (IParameterRegistry) {
        return registry;
    }

    /**
     * @inheritdoc IKeeper
     */
    function getRampAController() external view override returns (IRampAController) {
        return rampAController;
    }

    /**
     * @inheritdoc IKeeper
     */
    function getSpa() external view override returns (SelfPeggingAsset) {
        return spa;
    }

    /**
     * @inheritdoc IKeeper
     */
    function getLpToken() external view override returns (LPToken) {
        return lpToken;
    }

    /**
     * @dev Authorisation to upgrade the implementation of the contract.
     */
    function _authorizeUpgrade(address) internal override onlyRole(PROTOCOL_OWNER_ROLE) { }

    /**
     * @dev Validates if new value is within both absolute and relative bounds
     * @param newValue The new value to check
     * @param currentValue The current value for relative bounds checking
     * @param bounds The bounds object containing min, max, and relative change limits
     */
    function checkBounds(
        uint256 newValue,
        uint256 currentValue,
        IParameterRegistry.Bounds memory bounds
    )
        internal
        pure
    {
        // Check minimum bound if it's set
        if (bounds.min > 0) {
            require(newValue >= bounds.min, OutOfBounds());
        }

        // Check maximum bound if it's set (max = 0 means no upper limit)
        if (bounds.max > 0) {
            require(newValue <= bounds.max, OutOfBounds());
        }

        // Check relative bounds
        checkRange(newValue, currentValue, bounds);
    }

    /**
     * @dev Checks if new value is within the allowed relative change from current value
     * @param newValue The new value to check
     * @param currentValue The current value to compare against
     * @param bounds The bounds object containing relative change limits
     */
    function checkRange(
        uint256 newValue,
        uint256 currentValue,
        IParameterRegistry.Bounds memory bounds
    )
        internal
        pure
    {
        // Skip percentage checks if explicitly disabled or if current value is zero
        if (currentValue == 0) return;
        if (bounds.maxDecreasePct == 0 && bounds.maxIncreasePct == 0) return;

        if (newValue < currentValue) {
            uint256 decreasePct = ((currentValue - newValue) * DENOMINATOR) / currentValue;
            require(decreasePct <= bounds.maxDecreasePct, DeltaTooBig());
        } else if (newValue > currentValue) {
            uint256 increasePct = ((newValue - currentValue) * DENOMINATOR) / currentValue;
            require(increasePct <= bounds.maxIncreasePct, DeltaTooBig());
        }
    }
}
