// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./interfaces/IExchangeRateProvider.sol";
import "./interfaces/ILPToken.sol";
import "./interfaces/IRampAController.sol";

/**
 * @title SelfPeggingAsset swap
 * @author Nuts Finance Developer
 * @notice The SelfPeggingAsset pool provides a way to swap between different tokens
 * @dev The SelfPeggingAsset contract allows users to trade between different tokens, with prices determined
 * algorithmically based on the current supply and demand of each token
 */
contract SelfPeggingAsset is Initializable, ReentrancyGuardUpgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    /**
     * @dev Data structure for each token's fee status:
     *      - lastRate: last recorded exchange rate for this token.
     *      - multiplier: current multiplier (scaled by FEE_DENOMINATOR).
     *      - raisedAt: timestamp when the multiplier was last raised.
     */
    struct TokenFeeStatus {
        uint256 lastRate;
        uint256 multiplier;
        uint256 raisedAt;
    }

    /**
     * @dev This is the denominator used for calculating transaction fees in the SelfPeggingAsset contract.
     */
    uint256 private constant FEE_DENOMINATOR = 10 ** 10;
    /**
     *  @dev This is the maximum error margin for calculating transaction fees in the SelfPeggingAsset contract.
     */
    uint256 private constant DEFAULT_FEE_ERROR_MARGIN = 100_000;

    /**
     *  @dev This is the maximum error margin for calculating transaction yield in the SelfPeggingAsset contract.
     */
    uint256 private constant DEFAULT_YIELD_ERROR_MARGIN = 10_000;

    /**
     *  @dev This is the maximum error margin for updating A in the SelfPeggingAsset contract.
     */
    uint256 private constant DEFAULT_MAX_DELTA_D = 100_000;

    /**
     * @dev This is the maximum value of the amplification coefficient A.
     */
    uint256 private constant MAX_A = 10 ** 6;

    /**
     *  @dev This is minimum initial mint
     */
    uint256 private constant INITIAL_MINT_MIN = 100_000;

    /**
     * @dev This is the default decay period
     */
    uint256 private constant DEFAULT_DECAY_PERIOD = 5 minutes;

    /**
     * @dev This is an array of addresses representing the tokens currently supported by the SelfPeggingAsset contract.
     */
    address[] public tokens;

    /**
     * @dev This is an array of uint256 values representing the precisions of each token in the SelfPeggingAsset
     * contract.
     * The precision of each token is calculated as 10 ** (18 - token decimals).
     */
    uint256[] public precisions;

    /**
     * @dev This is an array of uint256 values representing the current balances of each token in the SelfPeggingAsset
     * contract.
     * The balances are converted to the standard token unit (10 ** 18).
     */
    uint256[] public balances;
    uint256[] public exchangeRateDecimals;

    /**
     * @dev This is the fee charged for adding liquidity to the SelfPeggingAsset contract.
     */
    uint256 public mintFee;

    /**
     * @dev This is the fee charged for trading assets in the SelfPeggingAsset contract.
     * swapFee = swapFee * FEE_DENOMINATOR
     */
    uint256 public swapFee;

    /**
     * @dev This is the fee charged for removing liquidity from the SelfPeggingAsset contract.
     * redeemFee = redeemFee * FEE_DENOMINATOR
     */
    uint256 public redeemFee;

    /**
     * @dev This is the off peg fee multiplier.
     * offPegFeeMultiplier = offPegFeeMultiplier * FEE_DENOMINATOR
     */
    uint256 public offPegFeeMultiplier;

    /**
     * @dev This is the address of the ERC20 token contract that represents the SelfPeggingAsset pool token.
     */
    ILPToken public poolToken;

    /**
     * @dev The total supply of pool token minted by the swap.
     * It might be different from the pool token supply as the pool token can have multiple minters.
     */
    uint256 public totalSupply;

    /**
     * @dev This is a mapping of accounts that have administrative privileges over the SelfPeggingAsset contract.
     */
    mapping(address => bool) public admins;

    /**
     * @dev This is a state variable that represents whether or not the SelfPeggingAsset contract is currently paused.
     */
    bool public paused;

    /**
     * @dev These is a state variables that represents the amplification coefficient A.
     */
    uint256 public A;

    /**
     * @dev RampAController contract address for gradual A changes
     */
    IRampAController public rampAController;

    /**
     * @dev Exchange rate provider for the tokens
     */
    IExchangeRateProvider[] public exchangeRateProviders;

    /**
     * @dev Fee error margin.
     */
    uint256 public feeErrorMargin;

    /**
     * @dev Yield error margin.
     */
    uint256 public yieldErrorMargin;

    /**
     * @dev The fee factor for rate change fee
     */
    uint256 public exchangeRateFeeFactor;

    /**
     * @notice The time (in seconds) over which the multiplier decays back to 1x after being raised.
     */
    uint256 public decayPeriod;

    /**
     * @notice Mapping of token index -> TokenFeeStatus
     */
    mapping(uint256 => TokenFeeStatus) public feeStatusByToken;

    /**
     * @notice This event is emitted when a token swap occurs.
     * @param buyer is the address of the account that made the swap.
     * @param swapAmount is the amount of the token swapped by the buyer.
     * @param amounts is an array containing the amounts of each token received by the buyer.
     * @param feeAmount is the amount of transaction fee charged for the swap.
     */
    event TokenSwapped(address indexed buyer, uint256 swapAmount, uint256[] amounts, uint256 feeAmount);

    /**
     * @notice This event is emitted when liquidity is added to the SelfPeggingAsset contract.
     * @param provider is the address of the liquidity provider.
     * @param mintAmount is the amount of liquidity tokens minted to the provider in exchange for their contribution.
     * @param amounts is an array containing the amounts of each token contributed by the provider.
     * @param feeAmount is the amount of transaction fee charged for the liquidity provision.
     */
    event Minted(address indexed provider, uint256 mintAmount, uint256[] amounts, uint256 feeAmount);

    /**
     * @notice This event is emitted when liquidity is added to the SelfPeggingAsset contract.
     * @param provider is the address of the liquidity provider.
     * @param mintAmount is the amount of liquidity tokens minted to the provider in exchange for their contribution.
     * @param amounts is an array containing the amounts of each token contributed by the provider.
     */
    event Donated(address indexed provider, uint256 mintAmount, uint256[] amounts);

    /**
     * @dev This event is emitted when liquidity is removed from the SelfPeggingAsset contract.
     * @param provider is the address of the liquidity provider.
     * @param redeemAmount is the amount of liquidity tokens redeemed by the provider.
     * @param amounts is an array containing the amounts of each token received by the provider.
     * @param feeAmount is the amount of transaction fee charged for the liquidity provision.
     */
    event Redeemed(address indexed provider, uint256 redeemAmount, uint256[] amounts, uint256 feeAmount);

    /**
     * @dev This event is emitted when transaction fees are collected by the SelfPeggingAsset contract.
     * @param feeAmount is the amount of fee collected.
     * @param totalSupply is the total supply of LP token.
     */
    event FeeCollected(uint256 feeAmount, uint256 totalSupply);

    /**
     * @dev This event is emitted when yield is collected by the SelfPeggingAsset contract.
     * @param feeAmount is the amount of yield collected.
     * @param totalSupply is the total supply of LP token.
     */
    event YieldCollected(uint256 feeAmount, uint256 totalSupply);

    /**
     * @dev This event is emitted when the RampAController is set or updated.
     */
    event RampAControllerUpdated(address indexed _rampAController);

    /**
     * @dev This event is emitted when the mint fee is modified.
     * @param mintFee is the new value of the mint fee.
     */
    event MintFeeModified(uint256 mintFee);

    /**
     * @dev This event is emitted when the swap fee is modified.
     * @param swapFee is the new value of the swap fee.
     */
    event SwapFeeModified(uint256 swapFee);

    /**
     * @dev This event is emitted when the redeem fee is modified.
     * @param redeemFee is the new value of the redeem fee.
     */
    event RedeemFeeModified(uint256 redeemFee);

    /**
     * @dev This event is emitted when the off peg fee multiplier is modified.
     * @param offPegFeeMultiplier is the new value of the off peg fee multiplier.
     */
    event OffPegFeeMultiplierModified(uint256 offPegFeeMultiplier);

    /**
     * @dev This event is emitted when the fee margin is modified.
     * @param margin is the new value of the margin.
     */
    event FeeMarginModified(uint256 margin);

    /**
     * @dev This event is emitted when the fee margin is modified.
     * @param margin is the new value of the margin.
     */
    event YieldMarginModified(uint256 margin);

    /**
     * @dev This event is emitted when the exchange rate fee factor is modified.
     * @param factor is the new value of the factor.
     */
    event ExchangeRateFeeFactorModified(uint256 factor);

    /**
     * @dev This event is emitted when the decay period is modified.
     * @param decayPeriod is the new value of the decay period.
     */
    event DecayPeriodModified(uint256 decayPeriod);

    /// @notice Error thrown when the input parameters do not match the expected values.
    error InputMismatch();

    /// @notice Error thrown when fees are not set
    error NoFees();

    /// @notice Error thrown when the fee percentage is too large.
    error FeePercentageTooLarge();

    /// @notice Error thrown when the token address is not set.
    error TokenNotSet();

    /// @notice Error thrown when the exchange rate provider is not set.
    error ExchangeRateProviderNotSet();

    /// @notice Error thrown when the precision is not set.
    error PrecisionNotSet();

    /// @notice Error thrown when the tokens are duplicates.
    error DuplicateToken();

    /// @notice Error thrown when the pool token is not set.
    error PoolTokenNotSet();

    /// @notice Error thrown when the A value is not set.
    error ANotSet();

    /// @notice Error thrown when the controller is in a ramp
    error CannotChangeControllerDuringRamp();

    /// @notice Error thrown when the controller initial A not match
    error InitialANotMatchCurrentA();

    /// @notice Error thrown when the amount is invalid.
    error InvalidAmount();

    /// @notice Error thrown when the pool is paused.
    error Paused();

    /// @notice Error thrown when the amount is zero.
    error ZeroAmount();

    /// @notice Error thrown when the token is the same.
    error SameToken();

    /// @notice Error thrown when the input token is invalid.
    error InvalidIn();

    /// @notice Error thrown when the output token is invalid.
    error InvalidOut();

    /// @notice Error thrown when the amount is invalid.
    error InvalidMins();

    /// @notice Error thrown when the token is invalid.
    error InvalidToken();

    /// @notice Error thrown when the limit is exceeded.
    error LimitExceeded();

    /// @notice Error thrown when the pool is not paused.
    error NotPaused();

    /// @notice Error thrown when the account address is zero
    error AccountIsZero();

    /// @notice Error thrown when the block number is an past block
    error PastBlock();

    /// @notice Error thrown when there is no loss
    error NoLosses();

    /// @notice Error thrown when the account is not an admin
    error NotAdmin();

    /// @notice Error thrown donation amount is insufficient
    error InsufficientDonationAmount();

    /// @notice Error thrown insufficient mint amount
    error InsufficientMintAmount(uint256 mintAmount, uint256 minMintAmount);

    /// @notice Error thrown insufficient swap out amount
    error InsufficientSwapOutAmount(uint256 outAmount, uint256 minOutAmount);

    /// @notice Error thrown insufficient redeem amount
    error InsufficientRedeemAmount(uint256 redeemAmount, uint256 minRedeemAmount);

    /// @notice Error thrown when redeem amount is max
    error MaxRedeemAmount(uint256 redeemAmount, uint256 maxRedeemAmount);

    /// @notice Error thrown in and out token are the same
    error SameTokenInTokenOut(uint256 tokenInIndex, uint256 tokenOutIndex);

    /// @notice Error thrown when the pool is imbalanced
    error ImbalancedPool(uint256 oldD, uint256 newD);

    modifier syncRamping() {
        if (address(rampAController) != address(0)) {
            uint256 currentA = getCurrentA();
            if (currentA != A) {
                A = currentA;
                _syncTotalSupply();
            }
        }
        _;
    }

    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the SelfPeggingAsset contract with the given parameters.
     * @param _tokens The tokens in the pool.
     * @param _precisions The precisions of each token (10 ** (18 - token decimals)).
     * @param _fees The fees for minting, swapping, and redeeming.
     * @param _offPegFeeMultiplier The off peg fee multiplier.
     * @param _poolToken The address of the pool token.
     * @param _A The initial value of the amplification coefficient A for the pool.
     * @param _exchangeRateProviders The exchange rate providers for the tokens.
     * @param _rampAController The address of the RampAController contract.
     */
    function initialize(
        address[] memory _tokens,
        uint256[] memory _precisions,
        uint256[] memory _fees,
        uint256 _offPegFeeMultiplier,
        ILPToken _poolToken,
        uint256 _A,
        IExchangeRateProvider[] memory _exchangeRateProviders,
        address _rampAController,
        uint256 _exchangeRateFeeFactor
    )
        public
        initializer
    {
        require(
            _tokens.length >= 2 && _tokens.length == _precisions.length
                && _tokens.length == _exchangeRateProviders.length,
            InputMismatch()
        );
        require(_fees.length == 3, NoFees());
        for (uint256 i = 0; i < 3; i++) {
            require(_fees[i] < FEE_DENOMINATOR, FeePercentageTooLarge());
        }
        exchangeRateDecimals = new uint256[](_tokens.length);
        for (uint256 i = 0; i < _tokens.length; i++) {
            require(_tokens[i] != address(0), TokenNotSet());
            require(address(_exchangeRateProviders[i]) != address(0), ExchangeRateProviderNotSet());
            // query tokens decimals
            uint256 _decimals = ERC20Upgradeable(_tokens[i]).decimals();
            require(_precisions[i] == 10 ** (18 - _decimals), PrecisionNotSet());
            exchangeRateDecimals[i] = _exchangeRateProviders[i].exchangeRateDecimals();
            balances.push(0);
        }
        for (uint256 i = 0; i < _tokens.length; i++) {
            for (uint256 j = i + 1; j < _tokens.length; j++) {
                require(_tokens[i] != _tokens[j], DuplicateToken());
            }
        }
        require(address(_poolToken) != address(0), PoolTokenNotSet());
        require(_A > 0 && _A < MAX_A, ANotSet());
        __ReentrancyGuard_init();
        __Ownable_init(msg.sender);

        tokens = _tokens;
        precisions = _precisions;
        mintFee = _fees[0];
        swapFee = _fees[1];
        redeemFee = _fees[2];
        poolToken = _poolToken;
        exchangeRateProviders = _exchangeRateProviders;
        offPegFeeMultiplier = _offPegFeeMultiplier;
        exchangeRateFeeFactor = _exchangeRateFeeFactor;

        rampAController = IRampAController(_rampAController);

        A = _A;
        feeErrorMargin = DEFAULT_FEE_ERROR_MARGIN;
        yieldErrorMargin = DEFAULT_YIELD_ERROR_MARGIN;
        decayPeriod = DEFAULT_DECAY_PERIOD;

        paused = false;

        for (uint256 i = 0; i < _exchangeRateProviders.length; i++) {
            uint256 initRate = _exchangeRateProviders[i].exchangeRate();
            feeStatusByToken[i] =
                TokenFeeStatus({ lastRate: initRate, multiplier: FEE_DENOMINATOR, raisedAt: block.timestamp });
        }
    }

    /**
     * @dev Mints new pool token.
     * @param _amounts Unconverted token balances used to mint pool token.
     * @param _minMintAmount Minimum amount of pool token to mint.
     * @return The amount of pool tokens minted.
     */
    function mint(
        uint256[] calldata _amounts,
        uint256 _minMintAmount
    )
        external
        nonReentrant
        syncRamping
        returns (uint256)
    {
        // If swap is paused, only admins can mint.
        require(!paused || admins[msg.sender], Paused());
        require(balances.length == _amounts.length, InvalidAmount());

        for (uint256 i = 0; i < _amounts.length; i++) {
            _updateMultiplierForToken(i);
        }

        collectFeeOrYield(false);
        uint256[] memory _balances = balances;
        uint256 oldD = totalSupply;
        bool hasNonZero = false;
        for (uint256 i = 0; i < _balances.length; i++) {
            if (_amounts[i] < INITIAL_MINT_MIN) require(oldD > 0, ZeroAmount());
            if (_amounts[i] != 0) hasNonZero = true;
        }
        require(hasNonZero, ZeroAmount());

        _balances = _updateBalancesForDeposit(_balances, _amounts);
        uint256 newD = _getD(_balances, A);
        // newD should be bigger than or equal to oldD
        uint256 mintAmount = newD - oldD;

        uint256 feeAmount = 0;
        if (mintFee > 0 && oldD != 0) {
            uint256 ys = (newD + oldD) / _balances.length;
            uint256[] memory fees = new uint256[](_balances.length);
            for (uint256 i = 0; i < _balances.length; i++) {
                uint256 idealBalance = newD * balances[i] / oldD;
                uint256 difference =
                    idealBalance > _balances[i] ? idealBalance - _balances[i] : _balances[i] - idealBalance;
                uint256 xs = ((balances[i] + _balances[i]) * exchangeRateProviders[i].exchangeRate())
                    / (10 ** exchangeRateDecimals[i]);
                fees[i] = (difference * (_dynamicFee(xs, ys, mintFee) + _volatilityFee(i, mintFee))) / FEE_DENOMINATOR;
                _balances[i] -= fees[i];
            }

            newD = _getD(_balances, A);
            mintAmount = newD - oldD;
        }

        if (mintAmount < _minMintAmount) revert InsufficientMintAmount(mintAmount, _minMintAmount);

        // Transfer tokens into the swap
        for (uint256 i = 0; i < _amounts.length; i++) {
            if (_amounts[i] == 0) continue;
            // Update the balance in storage
            balances[i] = _balances[i];
            IERC20(tokens[i]).safeTransferFrom(msg.sender, address(this), _amounts[i]);
        }
        totalSupply = oldD + mintAmount;
        poolToken.mintShares(msg.sender, mintAmount);
        feeAmount = collectFeeOrYield(true);
        emit Minted(msg.sender, mintAmount, _amounts, feeAmount);
        return mintAmount;
    }

    /**
     * @dev Exchange between two underlying tokens.
     * @param _i Token index to swap in.
     * @param _j Token index to swap out.
     * @param _dx Unconverted amount of token _i to swap in.
     * @param _minDy Minimum token _j to swap out in converted balance.
     * @return Amount of swap out.
     */
    function swap(
        uint256 _i,
        uint256 _j,
        uint256 _dx,
        uint256 _minDy
    )
        external
        nonReentrant
        syncRamping
        returns (uint256)
    {
        // If swap is paused, only admins can swap.
        require(!paused || admins[msg.sender], Paused());
        require(_i != _j, SameToken());
        require(_i < balances.length, InvalidIn());
        require(_j < balances.length, InvalidOut());
        require(_dx != 0, InvalidAmount());

        _updateMultiplierForToken(_i);
        _updateMultiplierForToken(_j);

        collectFeeOrYield(false);
        uint256[] memory _balances = balances;
        uint256 prevBalanceI = _balances[_i];
        _balances[_i] +=
            (_dx * exchangeRateProviders[_i].exchangeRate() * precisions[_i]) / (10 ** exchangeRateDecimals[_i]);
        uint256 y = _getY(_balances, _j, totalSupply, A);
        // dy = (balance[j] - y - 1) / precisions[j] in case there was rounding errors
        uint256 dy = (_balances[_j] - y - 1) / precisions[_j];
        // Update token balance in storage
        balances[_j] = y;
        balances[_i] = _balances[_i];

        uint256 feeAmount = 0;
        if (swapFee > 0) {
            feeAmount = _calcSwapFee(_i, _j, prevBalanceI, _balances[_i], _balances[_j], y, dy);
            dy -= feeAmount;
        }
        _minDy = (_minDy * exchangeRateProviders[_j].exchangeRate()) / (10 ** exchangeRateDecimals[_j]);
        if (dy < _minDy) revert InsufficientSwapOutAmount(dy, _minDy);

        IERC20(tokens[_i]).safeTransferFrom(msg.sender, address(this), _dx);
        // Important: When swap fee > 0, the swap fee is charged on the output token.
        // Therefore, balances[j] < tokens[j].balanceOf(this)
        // Since balances[j] is used to compute D, D is unchanged.
        // collectFees() is used to convert the difference between balances[j] and tokens[j].balanceOf(this)
        // into pool token as fees!
        uint256 transferAmountJ = (dy * (10 ** exchangeRateDecimals[_j])) / exchangeRateProviders[_j].exchangeRate();
        IERC20(tokens[_j]).safeTransfer(msg.sender, transferAmountJ);

        uint256[] memory amounts = new uint256[](_balances.length);
        amounts[_i] = _dx;
        amounts[_j] = transferAmountJ;

        uint256 feeAmountActual = collectFeeOrYield(true);
        emit TokenSwapped(msg.sender, transferAmountJ, amounts, feeAmountActual);
        return transferAmountJ;
    }

    /**
     * @dev Redeems pool token to underlying tokens proportionally.
     * @param _amount Amount of pool token to redeem.
     * @param _minRedeemAmounts Minimum amount of underlying tokens to get.
     * @return An array of the amounts of each token to redeem.
     */
    function redeemProportion(
        uint256 _amount,
        uint256[] calldata _minRedeemAmounts
    )
        external
        nonReentrant
        syncRamping
        returns (uint256[] memory)
    {
        // If swap is paused, only admins can redeem.
        require(!paused || admins[msg.sender], Paused());
        require(_amount != 0, ZeroAmount());
        require(balances.length == _minRedeemAmounts.length, InvalidMins());

        collectFeeOrYield(false);
        uint256[] memory _balances = balances;
        uint256 D = totalSupply;
        uint256[] memory amounts = new uint256[](_balances.length);
        uint256 feeAmount = 0;
        uint256 redeemAmount = _amount;
        if (redeemFee > 0) {
            feeAmount = (_amount * redeemFee) / FEE_DENOMINATOR;
            redeemAmount = _amount - feeAmount;
        }

        for (uint256 i = 0; i < _balances.length; i++) {
            // We might choose to use poolToken.totalSupply to compute the amount, but decide to use
            // D in case we have multiple minters on the pool token.
            uint256 tokenAmount = (_balances[i] * redeemAmount) / D;
            // Important: Underlying tokens must convert back to original decimals!
            amounts[i] = tokenAmount / precisions[i];
            uint256 minRedeemAmount =
                (_minRedeemAmounts[i] * exchangeRateProviders[i].exchangeRate()) / (10 ** exchangeRateDecimals[i]);
            if (amounts[i] < minRedeemAmount) revert InsufficientRedeemAmount(amounts[i], minRedeemAmount);
            // Updates the balance in storage
            balances[i] = _balances[i] - tokenAmount;
            uint256 transferAmount =
                (amounts[i] * (10 ** exchangeRateDecimals[i])) / exchangeRateProviders[i].exchangeRate();
            amounts[i] = transferAmount;
            IERC20(tokens[i]).safeTransfer(msg.sender, transferAmount);
        }

        totalSupply = D - _amount;
        // After reducing the redeem fee, the remaining pool tokens are burned!
        poolToken.burnSharesFrom(msg.sender, _amount);
        feeAmount = collectFeeOrYield(true);
        emit Redeemed(msg.sender, _amount, amounts, feeAmount);
        return amounts;
    }

    /**
     * @dev Redeem pool token to one specific underlying token.
     * @param _amount Amount of pool token to redeem.
     * @param _i Index of the token to redeem to.
     * @param _minRedeemAmount Minimum amount of the underlying token to redeem to.
     * @return Amount received.
     */
    function redeemSingle(
        uint256 _amount,
        uint256 _i,
        uint256 _minRedeemAmount
    )
        external
        nonReentrant
        syncRamping
        returns (uint256)
    {
        // If swap is paused, only admins can redeem.
        require(!paused || admins[msg.sender], Paused());
        require(_amount > 0, ZeroAmount());
        require(_i < balances.length, InvalidToken());

        _updateMultiplierForToken(_i);

        collectFeeOrYield(false);
        uint256[] memory _balances = balances;
        uint256 oldD = totalSupply;
        uint256 oldBalanceI = _balances[_i];

        uint256 newD = oldD - _amount;
        // y is converted(18 decimals)
        uint256 y = _getY(_balances, _i, newD, A);
        // dy is not converted
        // dy = (balance[i] - y - 1) / precisions[i] in case there was rounding errors
        uint256 dy = (_balances[_i] - y - 1) / precisions[_i];
        uint256 feeAmount = 0;
        if (redeemFee > 0) {
            uint256 xs =
                ((oldBalanceI + y) * exchangeRateProviders[_i].exchangeRate()) / (10 ** exchangeRateDecimals[_i]) / 2;
            uint256 ys = (oldD + newD) / (_balances.length * 2);
            uint256 dynamicFee = _dynamicFee(xs, ys, redeemFee);
            feeAmount = (dy * (dynamicFee + _volatilityFee(_i, redeemFee))) / FEE_DENOMINATOR;
            dy -= feeAmount;
        }
        _minRedeemAmount =
            (_minRedeemAmount * exchangeRateProviders[_i].exchangeRate()) / (10 ** exchangeRateDecimals[_i]);
        if (dy < _minRedeemAmount) revert InsufficientRedeemAmount(dy, _minRedeemAmount);

        // Updates token balance in storage
        balances[_i] = y;
        uint256 transferAmount = (dy * (10 ** exchangeRateDecimals[_i])) / exchangeRateProviders[_i].exchangeRate();
        uint256[] memory amounts = new uint256[](_balances.length);
        amounts[_i] = transferAmount;
        IERC20(tokens[_i]).safeTransfer(msg.sender, transferAmount);
        totalSupply = newD;
        poolToken.burnSharesFrom(msg.sender, _amount);
        feeAmount = collectFeeOrYield(true);
        emit Redeemed(msg.sender, _amount, amounts, feeAmount);
        return transferAmount;
    }

    /**
     * @dev Redeems underlying tokens.
     * @param _amounts Amounts of underlying tokens to redeem to.
     * @param _maxRedeemAmount Maximum of pool token to redeem.
     * @return Amounts received.
     */
    function redeemMulti(
        uint256[] calldata _amounts,
        uint256 _maxRedeemAmount
    )
        external
        nonReentrant
        syncRamping
        returns (uint256[] memory)
    {
        require(_amounts.length == balances.length, InputMismatch());
        // If swap is paused, only admins can redeem.
        require(!paused || admins[msg.sender], Paused());

        for (uint256 i = 0; i < _amounts.length; i++) {
            _updateMultiplierForToken(i);
        }

        collectFeeOrYield(false);
        uint256[] memory _balances = balances;
        uint256 oldD = totalSupply;
        _balances = _updateBalancesForWithdrawal(_balances, _amounts);
        uint256 newD = _getD(_balances, A);

        // newD should be smaller than or equal to oldD
        uint256 redeemAmount = oldD - newD;
        uint256 feeAmount = 0;
        if (redeemFee > 0) {
            uint256 ys = (newD + oldD) / _balances.length;
            uint256[] memory fees = new uint256[](_balances.length);
            for (uint256 i = 0; i < _balances.length; i++) {
                uint256 idealBalance = newD * balances[i] / oldD;
                uint256 difference =
                    idealBalance > _balances[i] ? idealBalance - _balances[i] : _balances[i] - idealBalance;
                uint256 xs = ((balances[i] + _balances[i]) * exchangeRateProviders[i].exchangeRate())
                    / (10 ** exchangeRateDecimals[i]);
                fees[i] =
                    (difference * (_dynamicFee(xs, ys, redeemFee) + _volatilityFee(i, redeemFee))) / FEE_DENOMINATOR;
                _balances[i] -= fees[i];
            }

            newD = _getD(_balances, A);
            redeemAmount = oldD - newD;
        }

        if (redeemAmount > _maxRedeemAmount) revert MaxRedeemAmount(redeemAmount, _maxRedeemAmount);

        totalSupply = oldD - redeemAmount;
        poolToken.burnSharesFrom(msg.sender, redeemAmount);
        uint256[] memory amounts = _amounts;
        for (uint256 i = 0; i < _balances.length; i++) {
            if (_amounts[i] == 0) continue;
            // Updates token balances in storage.
            balances[i] = _balances[i];
            IERC20(tokens[i]).safeTransfer(msg.sender, _amounts[i]);
        }
        feeAmount = collectFeeOrYield(true);
        emit Redeemed(msg.sender, redeemAmount, amounts, feeAmount);
        return amounts;
    }

    /**
     * @dev Updates the mint fee.
     * @param _mintFee The new mint fee.
     */
    function setMintFee(uint256 _mintFee) external onlyOwner {
        require(_mintFee < FEE_DENOMINATOR, LimitExceeded());
        mintFee = _mintFee;
        emit MintFeeModified(_mintFee);
    }

    /**
     * @dev Updates the swap fee.
     * @param _swapFee The new swap fee.
     */
    function setSwapFee(uint256 _swapFee) external onlyOwner {
        require(_swapFee < FEE_DENOMINATOR, LimitExceeded());
        swapFee = _swapFee;
        emit SwapFeeModified(_swapFee);
    }

    /**
     * @dev Updates the redeem fee.
     * @param _redeemFee The new redeem fee.
     */
    function setRedeemFee(uint256 _redeemFee) external onlyOwner {
        require(_redeemFee < FEE_DENOMINATOR, LimitExceeded());
        redeemFee = _redeemFee;
        emit RedeemFeeModified(_redeemFee);
    }

    /**
     * @dev Updates the off peg fee multiplier.
     * @param _offPegFeeMultiplier The new off peg fee multiplier.
     */
    function setOffPegFeeMultiplier(uint256 _offPegFeeMultiplier) external onlyOwner {
        offPegFeeMultiplier = _offPegFeeMultiplier;
        emit OffPegFeeMultiplierModified(_offPegFeeMultiplier);
    }

    /**
     * @dev Updates the exchange rate fee factor.
     * @param _exchangeRateFeeFactor The new exchange rate fee factor.
     */
    function setExchangeRateFeeFactor(uint256 _exchangeRateFeeFactor) external onlyOwner {
        exchangeRateFeeFactor = _exchangeRateFeeFactor;
        emit ExchangeRateFeeFactorModified(_exchangeRateFeeFactor);
    }

    /**
     * @dev Updates the decay period.
     * @param _decayPeriod The new decay period.
     */
    function setDecayPeriod(uint256 _decayPeriod) external onlyOwner {
        decayPeriod = _decayPeriod;
        emit DecayPeriodModified(_decayPeriod);
    }

    /**
     * @dev Pause mint/swap/redeem actions. Can unpause later.
     */
    function pause() external {
        require(!paused, Paused());
        require(admins[msg.sender], NotAdmin());

        paused = true;
    }

    /**
     * @dev Unpause mint/swap/redeem actions.
     */
    function unpause() external {
        require(paused, NotPaused());
        require(admins[msg.sender], NotAdmin());

        paused = false;
    }

    /**
     * @dev Updates the admin role for the address.
     * @param _account Address to update admin role.
     * @param _allowed Whether the address is granted the admin role.
     */
    function setAdmin(address _account, bool _allowed) external onlyOwner {
        require(_account != address(0), AccountIsZero());

        admins[_account] = _allowed;
    }

    /**
     * @dev Set the RampAController address
     * @param _rampAController New controller address
     */
    function setRampAController(address _rampAController) external onlyOwner {
        if (address(rampAController) != address(0) && rampAController.isRamping()) {
            revert CannotChangeControllerDuringRamp();
        }
        if (IRampAController(_rampAController).initialA() != A) {
            revert InitialANotMatchCurrentA();
        }
        rampAController = IRampAController(_rampAController);
        emit RampAControllerUpdated(_rampAController);
    }

    /**
     * @dev Update the exchange rate provider for the token.
     */
    function donateD(
        uint256[] calldata _amounts,
        uint256 _minDonationAmount
    )
        external
        nonReentrant
        syncRamping
        returns (uint256)
    {
        collectFeeOrYield(false);

        uint256[] memory _balances = balances;
        uint256 oldD = totalSupply;
        _balances = _updateBalancesForDeposit(_balances, _amounts);
        uint256 newD = _getD(_balances, A);
        // newD should be bigger than or equal to oldD
        uint256 donationAmount = newD - oldD;
        require(donationAmount >= _minDonationAmount, InsufficientDonationAmount());

        for (uint256 i = 0; i < _balances.length; i++) {
            if (_amounts[i] == 0) continue;
            balances[i] = _balances[i];
            IERC20(tokens[i]).safeTransferFrom(msg.sender, address(this), _amounts[i]);
        }
        totalSupply = newD;
        poolToken.addBuffer(donationAmount);

        emit Donated(msg.sender, donationAmount, _amounts);

        return donationAmount;
    }

    /**
     * @dev update fee error margin.
     */
    function updateFeeErrorMargin(uint256 newValue) external onlyOwner {
        feeErrorMargin = newValue;
        emit FeeMarginModified(newValue);
    }

    /**
     * @dev update yield error margin.
     */
    function updateYieldErrorMargin(uint256 newValue) external onlyOwner {
        yieldErrorMargin = newValue;
        emit YieldMarginModified(newValue);
    }

    /**
     * @dev Distribute losses by rebasing negatively
     */
    function distributeLoss() external onlyOwner {
        require(paused, NotPaused());

        uint256[] memory _balances = balances;
        uint256 oldD = totalSupply;

        for (uint256 i = 0; i < _balances.length; i++) {
            uint256 balanceI = IERC20(tokens[i]).balanceOf(address(this));
            _balances[i] =
                (balanceI * exchangeRateProviders[i].exchangeRate()) / (10 ** exchangeRateDecimals[i]) * precisions[i];
        }
        uint256 newD = _getD(_balances, getCurrentA());

        require(newD < oldD, NoLosses());
        poolToken.removeTotalSupply(oldD - newD, false, false);

        balances = _balances;
        totalSupply = newD;
    }

    /**
     * @notice This function allows to rebase LPToken by increasing his total supply
     * from the current stableSwap pool by the staking rewards and the swap fee.
     */
    function rebase() external returns (uint256) {
        uint256[] memory _balances = balances;
        uint256 oldD = totalSupply;

        for (uint256 i = 0; i < _balances.length; i++) {
            uint256 balanceI = IERC20(tokens[i]).balanceOf(address(this));
            _balances[i] =
                (balanceI * exchangeRateProviders[i].exchangeRate()) / (10 ** exchangeRateDecimals[i]) * precisions[i];
        }
        uint256 newD = _getD(_balances, getCurrentA());
        if (oldD == newD) return 0;
        balances = _balances;
        totalSupply = newD;
        if (oldD > newD) {
            poolToken.removeTotalSupply(oldD - newD, true, true);
            return 0;
        } else {
            uint256 _amount = newD - oldD;
            poolToken.addTotalSupply(_amount);
            return _amount;
        }
    }

    /**
     * @dev Computes the amount when redeeming pool token to one specific underlying token.
     * @param _amount Amount of pool token to redeem.
     * @param _i Index of the underlying token to redeem to.
     * @return The amount of single token that will be redeemed.
     * @return The amount of pool token charged for redemption fee.
     */
    function getRedeemSingleAmount(uint256 _amount, uint256 _i) external view returns (uint256, uint256) {
        (uint256[] memory _balances, uint256 D) = getUpdatedBalancesAndD();
        require(_amount > 0, ZeroAmount());
        require(_i < _balances.length, InvalidToken());

        uint256 oldBalanceI = _balances[_i];
        uint256 newD = D - _amount;
        uint256 y = _getY(_balances, _i, newD, getCurrentA());
        uint256 dy = (_balances[_i] - y - 1) / precisions[_i];
        uint256 feeAmount = 0;
        if (redeemFee > 0) {
            uint256 xs =
                ((oldBalanceI + y) * exchangeRateProviders[_i].exchangeRate()) / (10 ** exchangeRateDecimals[_i]) / 2;
            uint256 ys = (D + newD) / (_balances.length * 2);
            uint256 dynamicFee = _dynamicFee(xs, ys, redeemFee);
            feeAmount = (dy * (dynamicFee + _volatilityFee(_i, redeemFee))) / FEE_DENOMINATOR;
            dy -= feeAmount;
        }
        uint256 transferAmount = (dy * (10 ** exchangeRateDecimals[_i])) / exchangeRateProviders[_i].exchangeRate();
        return (transferAmount, feeAmount);
    }

    /**
     * @dev Compute the amount of pool token that needs to be redeemed.
     * @param _amounts Unconverted token balances.
     * @return The amount of pool token that needs to be redeemed.
     * @return The amount of pool token charged for redemption fee.
     */
    function getRedeemMultiAmount(uint256[] calldata _amounts) external view returns (uint256, uint256) {
        (uint256[] memory _balances, uint256 oldD) = getUpdatedBalancesAndD();
        require(_amounts.length == balances.length, InputMismatch());

        _balances = _updateBalancesForWithdrawal(_balances, _amounts);
        uint256 newD = _getD(_balances, getCurrentA());

        // newD should be smaller than or equal to oldD
        uint256 redeemAmount = oldD - newD;
        uint256 feeAmount = 0;
        if (redeemFee > 0) {
            uint256 ys = (newD + oldD) / _balances.length;
            uint256[] memory fees = new uint256[](_balances.length);
            for (uint256 i = 0; i < _balances.length; i++) {
                uint256 idealBalance = newD * balances[i] / oldD;
                uint256 difference =
                    idealBalance > _balances[i] ? idealBalance - _balances[i] : _balances[i] - idealBalance;
                uint256 xs = ((balances[i] + _balances[i]) * exchangeRateProviders[i].exchangeRate())
                    / (10 ** exchangeRateDecimals[i]);
                fees[i] =
                    (difference * (_dynamicFee(xs, ys, redeemFee) + _volatilityFee(i, redeemFee))) / FEE_DENOMINATOR;
                _balances[i] -= fees[i];
            }

            newD = _getD(_balances, getCurrentA());
            uint256 prevRedeemAmount = redeemAmount;
            redeemAmount = oldD - newD;
            feeAmount = redeemAmount - prevRedeemAmount;
        }

        return (redeemAmount, feeAmount);
    }

    /**
     * @dev Compute the amount of pool token that can be minted.
     * @param _amounts Unconverted token balances.
     * @return The amount of pool tokens to be minted.
     * @return The amount of fees charged.
     */
    function getMintAmount(uint256[] calldata _amounts) external view returns (uint256, uint256) {
        (uint256[] memory _balances, uint256 oldD) = getUpdatedBalancesAndD();
        require(_amounts.length == _balances.length, InvalidAmount());

        _balances = _updateBalancesForDeposit(_balances, _amounts);
        uint256 newD = _getD(_balances, getCurrentA());
        // newD should be bigger than or equal to oldD
        uint256 mintAmount = newD - oldD;
        uint256 feeAmount = 0;
        if (mintFee > 0 && oldD != 0) {
            uint256 ys = (newD + oldD) / _balances.length;
            uint256[] memory fees = new uint256[](_balances.length);
            for (uint256 i = 0; i < _balances.length; i++) {
                uint256 idealBalance = newD * balances[i] / oldD;
                uint256 difference =
                    idealBalance > _balances[i] ? idealBalance - _balances[i] : _balances[i] - idealBalance;
                uint256 xs = ((balances[i] + _balances[i]) * exchangeRateProviders[i].exchangeRate())
                    / (10 ** exchangeRateDecimals[i]);
                fees[i] = (difference * (_dynamicFee(xs, ys, mintFee) + _volatilityFee(i, mintFee))) / FEE_DENOMINATOR;
                _balances[i] -= fees[i];
            }

            newD = _getD(_balances, getCurrentA());
            mintAmount = newD - oldD;
        }

        return (mintAmount, feeAmount);
    }

    /**
     * @dev Computes the output amount after the swap.
     * @param _i Token index to swap in.
     * @param _j Token index to swap out.
     * @param _dx Unconverted amount of token _i to swap in.
     * @return Unconverted amount of token _j to swap out.
     * @return The amount of fees charged.
     */
    function getSwapAmount(uint256 _i, uint256 _j, uint256 _dx) external view returns (uint256, uint256) {
        require(_i != _j, SameToken());
        require(_dx > 0, InvalidAmount());

        (uint256[] memory _balances, uint256 D) = getUpdatedBalancesAndD();
        require(_i < _balances.length, InvalidIn());
        require(_j < _balances.length, InvalidOut());

        uint256 prevBalanceI = _balances[_i];
        // balance[i] = balance[i] + dx * precisions[i]

        _balances[_i] +=
            (_dx * exchangeRateProviders[_i].exchangeRate() * precisions[_i]) / (10 ** exchangeRateDecimals[_i]);
        uint256 y = _getY(_balances, _j, D, getCurrentA());
        // dy = (balance[j] - y - 1) / precisions[j] in case there was rounding errors
        uint256 dy = (_balances[_j] - y - 1) / precisions[_j];
        uint256 feeAmount = 0;

        if (swapFee > 0) {
            feeAmount = _calcSwapFee(_i, _j, prevBalanceI, _balances[_i], _balances[_j], y, dy);
            dy -= feeAmount;
        }
        uint256 transferAmountJ = (dy * (10 ** exchangeRateDecimals[_j])) / exchangeRateProviders[_j].exchangeRate();
        feeAmount = (feeAmount * (10 ** exchangeRateDecimals[_j])) / exchangeRateProviders[_j].exchangeRate();
        return (transferAmountJ, feeAmount);
    }

    /**
     * @dev Computes the amounts of underlying tokens when redeeming pool token.
     * @param _amount Amount of pool tokens to redeem.
     * @return An array of the amounts of each token to redeem.
     * @return The amount of fee charged
     */
    function getRedeemProportionAmount(uint256 _amount) external view returns (uint256[] memory, uint256) {
        (uint256[] memory _balances, uint256 D) = getUpdatedBalancesAndD();
        require(_amount != 0, ZeroAmount());

        uint256[] memory amounts = new uint256[](_balances.length);
        uint256 feeAmount;
        uint256 redeemAmount = _amount;
        if (redeemFee != 0) {
            feeAmount = (_amount * redeemFee) / FEE_DENOMINATOR;
            redeemAmount = _amount - feeAmount;
        }

        for (uint256 i = 0; i < _balances.length; i++) {
            // We might choose to use poolToken.totalSupply to compute the amount, but decide to use
            // D in case we have multiple minters on the pool token.
            amounts[i] = (_balances[i] * redeemAmount) / D / precisions[i];
            amounts[i] = (amounts[i] * (10 ** exchangeRateDecimals[i])) / exchangeRateProviders[i].exchangeRate();
        }

        return (amounts, feeAmount);
    }

    /**
     * @dev Returns the array of token addresses in the pool.
     */
    function getTokens() external view returns (address[] memory) {
        return tokens;
    }

    /**
     * @dev Get the current A value from the controller if set, or use the local value
     * @return The current A value
     */
    function getCurrentA() public view returns (uint256) {
        if (address(rampAController) != address(0)) {
            try rampAController.getA() returns (uint256 controllerA) {
                return controllerA;
            } catch {
                return A;
            }
        }
        return A;
    }

    /**
     * @dev Updates the fee multiplier for token i if there's a significant rate change.
     */
    function _updateMultiplierForToken(uint256 i) internal {
        uint256 newRate = exchangeRateProviders[i].exchangeRate();
        TokenFeeStatus storage st = feeStatusByToken[i];

        uint256 oldRate = st.lastRate;
        if (oldRate == 0) {
            st.lastRate = newRate;
            return;
        }

        uint256 diff = (newRate > oldRate) ? (newRate - oldRate) : (oldRate - newRate);
        if (diff == 0) {
            st.lastRate = newRate;
            return;
        }

        uint256 ratio = (diff * FEE_DENOMINATOR) / (oldRate > newRate ? oldRate : newRate);
        uint256 candidateMultiplier = FEE_DENOMINATOR + (ratio * exchangeRateFeeFactor) / FEE_DENOMINATOR;
        uint256 currentMult = _currentMultiplier(st);

        if (candidateMultiplier > currentMult) {
            st.multiplier = candidateMultiplier;
            st.raisedAt = block.timestamp;
        }
        st.lastRate = newRate;
    }

    function _syncTotalSupply() internal {
        uint256 newD = _getD(balances, A);

        if (totalSupply > newD) {
            // A decreased
            poolToken.removeTotalSupply(totalSupply - newD, true, false);
            totalSupply = newD;
        } else if (newD > totalSupply) {
            // A increased
            poolToken.addBuffer(newD - totalSupply);
            totalSupply = newD;
        }
    }

    /**
     * @dev Collect fee or yield based on the token balance difference.
     * @param isFee Whether to collect fee or yield.
     * @return The amount of fee or yield collected.
     */
    function collectFeeOrYield(bool isFee) internal returns (uint256) {
        uint256 oldD = totalSupply;

        uint256 newD;
        (balances, newD) = getUpdatedBalancesAndD();
        totalSupply = newD;

        if (oldD > newD) {
            uint256 delta = oldD - newD;
            uint256 margin = isFee ? feeErrorMargin : yieldErrorMargin;

            if (delta < margin) return 0;

            // Cover losses using the buffer
            poolToken.removeTotalSupply(delta, true, true);
            return 0;
        }

        uint256 feeAmount = newD - oldD;
        if (feeAmount == 0) return 0;

        poolToken.addTotalSupply(feeAmount);
        if (isFee) emit FeeCollected(feeAmount, totalSupply);
        else emit YieldCollected(feeAmount, totalSupply);
        return feeAmount;
    }

    /**
     * @dev Computes current multiplier for a given TokenFeeStatus.
     */
    function _currentMultiplier(TokenFeeStatus memory st) internal view returns (uint256) {
        uint256 endTime = st.raisedAt + decayPeriod;
        if (block.timestamp >= endTime) {
            return FEE_DENOMINATOR;
        }
        uint256 timePassed = block.timestamp - st.raisedAt;
        uint256 fraction = (timePassed * 1e6) / decayPeriod;
        if (fraction > 1e6) {
            fraction = 1e6;
        }
        if (st.multiplier <= FEE_DENOMINATOR) {
            return FEE_DENOMINATOR;
        }
        uint256 diff = st.multiplier - FEE_DENOMINATOR;
        uint256 diffReduction = (diff * fraction) / 1e6;
        return st.multiplier - diffReduction;
    }

    function _currentMultiplier(uint256 index) internal view returns (uint256) {
        return _currentMultiplier(feeStatusByToken[index]);
    }

    /**
     * @dev Calculate extra fee from volatility between tokens i, j
     */
    function _volatilityFee(uint256 _i, uint256 _j, uint256 _baseFee) internal view returns (uint256) {
        uint256 multI = _currentMultiplier(_i);
        uint256 multJ = _currentMultiplier(_j);
        uint256 worstMult = (multI > multJ) ? multI : multJ;
        if (worstMult <= FEE_DENOMINATOR) return 0;
        uint256 diff = worstMult - FEE_DENOMINATOR;
        return (_baseFee * diff) / FEE_DENOMINATOR;
    }

    /**
     * @dev Calculate extra fee from volatility for i
     */
    function _volatilityFee(uint256 _i, uint256 _baseFee) internal view returns (uint256) {
        uint256 multI = _currentMultiplier(_i);
        uint256 diff = multI - FEE_DENOMINATOR;
        return (_baseFee * diff) / FEE_DENOMINATOR;
    }

    /**
     * @dev Return the amount of fee that's not collected.
     * @return The balances of underlying tokens.
     * @return The total supply of pool tokens.
     */
    function getUpdatedBalancesAndD() internal view returns (uint256[] memory, uint256) {
        uint256[] memory _balances = balances;

        for (uint256 i = 0; i < _balances.length; i++) {
            uint256 balanceI = IERC20(tokens[i]).balanceOf(address(this));
            _balances[i] =
                (balanceI * exchangeRateProviders[i].exchangeRate()) * precisions[i] / (10 ** exchangeRateDecimals[i]);
        }
        uint256 newD = _getD(_balances, getCurrentA());

        return (_balances, newD);
    }

    /**
     * @notice Updates token balances for a deposit by adding amounts adjusted for exchange rates and precisions.
     * @param _balances Current balances of tokens in the pool.
     * @param _amounts Amounts of tokens to deposit.
     * @return Updated balances after deposit.
     */
    function _updateBalancesForDeposit(
        uint256[] memory _balances,
        uint256[] calldata _amounts
    )
        internal
        view
        returns (uint256[] memory)
    {
        for (uint256 i = 0; i < _balances.length; i++) {
            if (_amounts[i] == 0) continue;
            uint256 bal = (_amounts[i] * exchangeRateProviders[i].exchangeRate()) / (10 ** exchangeRateDecimals[i]);
            _balances[i] += bal * precisions[i];
        }
        return _balances;
    }

    /**
     * @notice Updates token balances for a withdrawal by subtracting amounts adjusted for exchange rates and
     * precisions.
     * @param _balances Current balances of tokens in the pool.
     * @param _amounts Amounts of tokens to withdraw.
     * @return Updated balances after withdrawal.
     */
    function _updateBalancesForWithdrawal(
        uint256[] memory _balances,
        uint256[] calldata _amounts
    )
        internal
        view
        returns (uint256[] memory)
    {
        for (uint256 i = 0; i < _balances.length; i++) {
            if (_amounts[i] == 0) continue;
            uint256 bal = (_amounts[i] * exchangeRateProviders[i].exchangeRate()) / (10 ** exchangeRateDecimals[i]);
            _balances[i] -= bal * precisions[i];
        }
        return _balances;
    }

    /**
     * @notice Calculates the swap fee based on token balances and dynamic fee adjustment.
     * @return Fee amount in output token units (token decimals).
     */
    function _calcSwapFee(
        uint256 i,
        uint256 j,
        uint256 prevBalanceI,
        uint256 newBalanceI,
        uint256 oldBalanceJ,
        uint256 newBalanceJ,
        uint256 dy
    )
        internal
        view
        returns (uint256)
    {
        uint256 volFee = _volatilityFee(i, j, swapFee);
        uint256 dynamicFee = _dynamicFee((prevBalanceI + newBalanceI) / 2, (oldBalanceJ + newBalanceJ) / 2, swapFee);
        return (dy * (dynamicFee + volFee)) / FEE_DENOMINATOR;
    }

    /**
     * @dev Calculates the dynamic fee based on liquidity imbalances.
     * @param xpi The liquidity before or first asset liqidity.
     * @param xpj The liqduity after or second asset liquidity.
     * @param _fee The base fee value.
     * @return The dynamically adjusted fee.
     */
    function _dynamicFee(uint256 xpi, uint256 xpj, uint256 _fee) internal view returns (uint256) {
        if (offPegFeeMultiplier <= FEE_DENOMINATOR) return _fee;
        uint256 xps2 = (xpi + xpj) * (xpi + xpj);
        return (offPegFeeMultiplier * _fee)
            / (((offPegFeeMultiplier - FEE_DENOMINATOR) * 4 * xpi * xpj) / xps2 + FEE_DENOMINATOR);
    }

    /**
     * @dev Computes D given token balances.
     * @param _balances Normalized balance of each token.
     * @return D The SelfPeggingAsset invariant.
     */
    function _getD(uint256[] memory _balances, uint256 _A) internal pure returns (uint256) {
        uint256 sum = 0;
        uint256 Ann = _A;
        uint256 length = _balances.length;
        bool allZero = true;
        for (uint256 i = 0; i < length; i++) {
            uint256 bal = _balances[i];
            if (bal != 0) allZero = false;
            else bal = 1;
            sum += bal;
            Ann *= length;
        }
        if (allZero) return 0;

        uint256 D = sum;
        for (uint256 i = 0; i < 255; i++) {
            uint256 pD = D;
            for (uint256 j = 0; j < length; j++) {
                pD = (pD * D) / (_balances[j] * length);
            }
            uint256 prevD = D;
            D = ((Ann * sum + pD * length) * D) / ((Ann - 1) * D + (length + 1) * pD);
            if (D > prevD && D - prevD <= 1 || D <= prevD && prevD - D <= 1) break;
        }
        return D;
    }

    /**
     * @dev Computes token balance given D.
     * @param _balances Converted balance of each token except token with index _j.
     * @param _j Index of the token to calculate balance.
     * @param _D The target D value.
     * @return Converted balance of the token with index _j.
     */
    function _getY(uint256[] memory _balances, uint256 _j, uint256 _D, uint256 _A) internal pure returns (uint256) {
        uint256 c = _D;
        uint256 S_ = 0;
        uint256 Ann = _A;
        uint256 length = _balances.length;
        for (uint256 i = 0; i < length; i++) {
            Ann *= length;
            if (i == _j) continue;
            S_ += _balances[i];
            c = (c * _D) / (_balances[i] * length);
        }
        c = (c * _D) / (Ann * length);
        uint256 b = S_ + (_D / Ann);
        uint256 y = _D;
        for (uint256 i = 0; i < 255; i++) {
            uint256 prevY = y;
            y = (y * y + c) / (y * 2 + b - _D);
            if (y > prevY && y - prevY <= 1 || y <= prevY && prevY - y <= 1) break;
        }
        return y;
    }
}
