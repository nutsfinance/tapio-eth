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

    error ZeroAddress();
    error OutOfBounds();
    error DeltaTooBig();
    error RelativeRangeNotSet();
    error UnauthorizedAccount();

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
    }

    /**
     * @inheritdoc IKeeper
     */
    function rampA(uint256 newA, uint256 endTime) external override onlyRole(CURATOR_ROLE) {
        IParameterRegistry.Bounds memory aParams = registry.aParams();

        uint256 curA = rampAController.getA();
        if (curA <= 2) {
            uint256 maxMultiplier = 11 - curA; // 10 for initialA=1, 9 for initialA=2
            if (newA > curA * maxMultiplier) revert OutOfBounds();
        } else {
            if (aParams.maxDecreasePct == 0 && aParams.maxIncreasePct == 0) revert RelativeRangeNotSet();
            checkRange(newA, curA, aParams);
        }

        require(newA <= aParams.max, OutOfBounds());

        rampAController.rampA(newA, endTime);
        emit RampAInitiated(msg.sender, curA, newA, endTime);
    }

    /**
     * @inheritdoc IKeeper
     */
    function setMinRampTime(uint256 newMinRampTime) external override onlyRole(GOVERNOR_ROLE) {
        IParameterRegistry.Bounds memory minRampTimeParams = registry.minRampTimeParams();

        uint256 curMinRampTime = rampAController.minRampTime();
        checkRange(newMinRampTime, curMinRampTime, minRampTimeParams);

        rampAController.setMinRampTime(newMinRampTime);
        emit MinRampTimeUpdated(msg.sender, curMinRampTime, newMinRampTime);
    }

    /**
     * @inheritdoc IKeeper
     */
    function setSwapFee(uint256 newFee) external override onlyRole(GOVERNOR_ROLE) {
        IParameterRegistry.Bounds memory swapFeeParams = registry.swapFeeParams();

        uint256 cur = spa.swapFee();
        checkRange(newFee, cur, swapFeeParams);

        spa.setSwapFee(newFee);
        emit SwapFeeUpdated(msg.sender, cur, newFee);
    }

    /**
     * @inheritdoc IKeeper
     */
    function setMintFee(uint256 newFee) external override onlyRole(GOVERNOR_ROLE) {
        IParameterRegistry.Bounds memory mintFeeParams = registry.mintFeeParams();

        uint256 cur = spa.mintFee();
        checkRange(newFee, cur, mintFeeParams);

        spa.setMintFee(newFee);
        emit MintFeeUpdated(msg.sender, cur, newFee);
    }

    /**
     * @inheritdoc IKeeper
     */
    function setRedeemFee(uint256 newFee) external override onlyRole(GOVERNOR_ROLE) {
        IParameterRegistry.Bounds memory redeemFeeParams = registry.redeemFeeParams();

        uint256 cur = spa.redeemFee();

        checkRange(newFee, cur, redeemFeeParams);
        spa.setRedeemFee(newFee);
        emit RedeemFeeUpdated(msg.sender, cur, newFee);
    }

    /**
     * @inheritdoc IKeeper
     */
    function cancelRamp() external override onlyRole(GUARDIAN_ROLE) {
        rampAController.stopRamp();
        emit RampCancelled(msg.sender);
    }

    /**
     * @inheritdoc IKeeper
     */
    function setOffPegFeeMultiplier(uint256 newMultiplier) external override onlyRole(GOVERNOR_ROLE) {
        IParameterRegistry.Bounds memory offPegParams = registry.offPegParams();

        uint256 cur = spa.offPegFeeMultiplier();
        checkRange(newMultiplier, cur, offPegParams);

        require(newMultiplier >= offPegParams.min, OutOfBounds());

        spa.setOffPegFeeMultiplier(newMultiplier);
        emit OffPegFeeMultiplierUpdated(msg.sender, cur, newMultiplier);
    }

    /**
     * @inheritdoc IKeeper
     */
    function setExchangeRateFeeFactor(uint256 newFeeFactor) external override onlyRole(GOVERNOR_ROLE) {
        IParameterRegistry.Bounds memory exchangeRateFeeParams = registry.exchangeRateFeeParams();

        uint256 cur = spa.exchangeRateFeeFactor();
        checkRange(newFeeFactor, cur, exchangeRateFeeParams);

        spa.setExchangeRateFeeFactor(newFeeFactor);
        emit ExchangeRateFeeFactorUpdated(msg.sender, cur, newFeeFactor);
    }

    /**
     * @inheritdoc IKeeper
     */
    function setBufferPercent(uint256 newBuffer) external override onlyRole(GOVERNOR_ROLE) {
        IParameterRegistry.Bounds memory bufferParams = registry.bufferPercentParams();

        uint256 cur = lpToken.bufferPercent();
        checkBounds(newBuffer, cur, bufferParams);

        lpToken.setBuffer(newBuffer);
        emit BufferPercentUpdated(msg.sender, cur, newBuffer);
    }

    /**
     * @inheritdoc IKeeper
     */
    function setDecayPeriod(uint256 newDecayPeriod) external override onlyRole(GOVERNOR_ROLE) {
        IParameterRegistry.Bounds memory decayPeriodParams = registry.decayPeriodParams();

        uint256 cur = spa.decayPeriod();
        checkRange(newDecayPeriod, cur, decayPeriodParams);

        spa.setDecayPeriod(newDecayPeriod);
        emit DecayPeriodUpdated(msg.sender, cur, newDecayPeriod);
    }

    /**
     * @inheritdoc IKeeper
     */
    function setRateChangeSkipPeriod(uint256 newSkipPeriod) external override onlyRole(GOVERNOR_ROLE) {
        IParameterRegistry.Bounds memory rateChangeSkipPeriodParams = registry.rateChangeSkipPeriodParams();

        uint256 cur = spa.rateChangeSkipPeriod();
        checkRange(newSkipPeriod, cur, rateChangeSkipPeriodParams);

        spa.setRateChangeSkipPeriod(newSkipPeriod);
        emit RateChangeSkipPeriodUpdated(msg.sender, cur, newSkipPeriod);
    }

    /**
     * @inheritdoc IKeeper
     */
    function updateFeeErrorMargin(uint256 newMargin) external override onlyRole(GOVERNOR_ROLE) {
        IParameterRegistry.Bounds memory feeErrorMarginParams = registry.feeErrorMarginParams();

        uint256 cur = spa.feeErrorMargin();
        checkRange(newMargin, cur, feeErrorMarginParams);

        spa.updateFeeErrorMargin(newMargin);
        emit FeeErrorMarginUpdated(msg.sender, cur, newMargin);
    }

    /**
     * @inheritdoc IKeeper
     */
    function updateYieldErrorMargin(uint256 newMargin) external override onlyRole(GOVERNOR_ROLE) {
        IParameterRegistry.Bounds memory yieldErrorMarginParams = registry.yieldErrorMarginParams();

        uint256 cur = spa.yieldErrorMargin();
        checkRange(newMargin, cur, yieldErrorMarginParams);

        spa.updateYieldErrorMargin(newMargin);
        emit YieldErrorMarginUpdated(msg.sender, cur, newMargin);
    }

    /**
     * @inheritdoc IKeeper
     */
    function distributeLoss() external override onlyRole(GOVERNOR_ROLE) {
        spa.distributeLoss();
        emit LossDistributed(msg.sender);
    }

    /**
     * @inheritdoc IKeeper
     */
    function pause() external override onlyRole(GUARDIAN_ROLE) {
        spa.pause();
        emit ProtocolPaused(msg.sender);
    }

    /**
     * @inheritdoc IKeeper
     */
    function unpause() external override onlyRole(PROTOCOL_OWNER_ROLE) {
        spa.unpause();
        emit ProtocolUnpaused(msg.sender);
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
