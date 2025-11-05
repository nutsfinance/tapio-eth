// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./interfaces/IExchangeRateProvider.sol";
import "./interfaces/ISPAToken.sol";
import "./interfaces/IRampAController.sol";
import "./periphery/RampAController.sol";

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

    uint16 private constant RATE_DENOMINATOR = 10 ** 4;
    /**
     *  @dev This is the maximum error margin for calculating transaction fees in the SelfPeggingAsset contract.
     */
    uint256 private constant DEFAULT_FEE_ERROR_MARGIN = 100_000;

    /**
     *  @dev This is the maximum error margin for calculating transaction yield in the SelfPeggingAsset contract.
     */
    uint256 private constant DEFAULT_YIELD_ERROR_MARGIN = 10_000;

    /**
     * @dev This is the maximum value of the amplification coefficient A.
     */
    uint256 private constant MAX_A = 10 ** 6;

    /**
     *  @dev This is minimum initial mint
     */
    uint256 private constant INITIAL_MINT_MIN = 100_000;

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
    ISPAToken public poolToken;

    /**
     * @dev The total supply of pool token minted by the swap.
     * It might be different from the pool token supply as the pool token can have multiple minters.
     */
    uint256 public totalSupply;

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
     * @notice (deprecated) the time (in seconds) after which the multiplier is skipped when the rate is changed.
     */
    uint256 public rateChangeSkipPeriod;

    /**
     * @dev (deprecated) Tracks the last time a transaction occurred in the SelfPeggingAsset contract.
     */
    uint256 public lastActivity;

    /**
     * @notice Mapping of token index -> TokenFeeStatus
     */
    mapping(uint256 => TokenFeeStatus) public feeStatusByToken;

    /**
     * @notice Mapping of aggregator to
     */
    mapping(address => uint16) public wholesalerRate;

    /**
     * @notice This event is emitted when a token swap occurs.
     * @param buyer is the address of the account that made the swap.
     * @param swapAmount is the amount of the token swapped by the buyer.
     * @param amounts is an array containing the amounts of each token received by the buyer.
     * @param feeAmount is the amount of transaction fee charged for the swap.
     * @param discount is the amount of swap fee discounted for using the wholesaler address.
     */
    event TokenSwapped(
        address indexed buyer, uint256 swapAmount, uint256[] amounts, uint256 feeAmount, uint256 discount
    );

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
     * @param totalSupply is the total supply of SPA token.
     */
    event FeeCollected(uint256 feeAmount, uint256 totalSupply);

    /**
     * @dev This event is emitted when yield is collected by the SelfPeggingAsset contract.
     * @param feeAmount is the amount of yield collected.
     * @param totalSupply is the total supply of SPA token.
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
     * @dev This event is emitted when the pool is paused.
     */
    event PoolPaused();

    /**
     * @dev This event is emitted when the pool is unpaused.
     */
    event PoolUnpaused();

    /**
     * @dev Emitted when new rate is set for a wholesaler
     */
    event WholesalerRateUpdated(address indexed wholesaler, uint16 oldRate, uint16 newRate);

    /// @notice Error thrown when the input parameters do not match the expected values.
    error InputMismatch();

    error NotWholesaler();

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

    /// @notice Error thrown when there is no loss
    error NoLosses();

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
     * @param _poolToken The address of the pool token.
     * @param _A The initial value of the amplification coefficient A for the pool.
     * @param _exchangeRateProviders The exchange rate providers for the tokens.
     * @param _rampAController The address of the RampAController contract.
     */
    function initialize(
        address[] memory _tokens,
        uint256[] memory _precisions,
        uint256[] memory _fees,
        address[] memory _wholesalers,
        uint16[] memory _rates,
        ISPAToken _poolToken,
        uint256 _A,
        IExchangeRateProvider[] memory _exchangeRateProviders,
        address _rampAController,
        address _keeper
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
        _setWholesalerRates(_wholesalers, _rates);
        require(address(_poolToken) != address(0), PoolTokenNotSet());
        require(_A > 0 && _A < MAX_A, ANotSet());

        __ReentrancyGuard_init();
        __Ownable_init(_keeper);

        tokens = _tokens;
        precisions = _precisions;
        mintFee = _fees[0];
        swapFee = _fees[1];
        redeemFee = _fees[2];
        poolToken = _poolToken;
        exchangeRateProviders = _exchangeRateProviders;

        rampAController = IRampAController(_rampAController);

        A = _A;
        feeErrorMargin = DEFAULT_FEE_ERROR_MARGIN;
        yieldErrorMargin = DEFAULT_YIELD_ERROR_MARGIN;

        paused = false;
    }

    function setWholesalerRates(address[] memory wholesalers, uint16[] memory rates) external onlyOwner {
        _setWholesalerRates(wholesalers, rates);
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
        require(!paused, Paused());
        require(balances.length == _amounts.length, InvalidAmount());

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
            uint256[] memory fees = new uint256[](_balances.length);
            for (uint256 i = 0; i < _balances.length; i++) {
                uint256 idealBalance = newD * balances[i] / oldD;
                uint256 difference =
                    idealBalance > _balances[i] ? idealBalance - _balances[i] : _balances[i] - idealBalance;
                fees[i] = difference * mintFee / FEE_DENOMINATOR;
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
        (uint256 dy, uint256[] memory _balances) = _swapPreFee(_i, _j, _dx);

        if (swapFee > 0) {
            uint256 fee = (dy * swapFee) / FEE_DENOMINATOR;
            dy -= fee;
        }

        return _swapPostFee(_i, _j, _dx, dy, _minDy, _balances, 0);
    }

    /**
     * @dev Exchange between two underlying tokens with a discount for the whitelisted wholesalers.
     * @param _i Token index to swap in.
     * @param _j Token index to swap out.
     * @param _dx Unconverted amount of token _i to swap in.
     * @param _minDy Minimum token _j to swap out in converted balance.
     * @return Amount of swap out.
     */
    function swapWholesale(
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
        (uint256 dy, uint256[] memory _balances) = _swapPreFee(_i, _j, _dx);
        require(wholesalerRate[msg.sender] != 0, NotWholesaler());

        uint256 discount;
        if (swapFee > 0) {
            uint256 feeAmount = (dy * swapFee) / FEE_DENOMINATOR;
            discount = wholesalerRate[msg.sender] / RATE_DENOMINATOR;
            dy -= (feeAmount - discount);
        }

        return _swapPostFee(_i, _j, _dx, dy, _minDy, _balances, discount);
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
        require(!paused, Paused());
        require(_amount != 0, ZeroAmount());
        require(balances.length == _minRedeemAmounts.length, InvalidMins());

        collectFeeOrYield(false);
        uint256[] memory _balances = balances;
        uint256 D = totalSupply;
        uint256[] memory amounts = new uint256[](_balances.length);

        for (uint256 i = 0; i < _balances.length; i++) {
            // We might choose to use poolToken.totalSupply to compute the amount, but decide to use
            // D in case we have multiple minters on the pool token.
            uint256 tokenAmount = (_balances[i] * _amount) / D;
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
        uint256 feeAmount = collectFeeOrYield(true);
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
        require(!paused, Paused());
        require(_amount > 0, ZeroAmount());
        require(_i < balances.length, InvalidToken());

        collectFeeOrYield(false);
        uint256[] memory _balances = balances;
        uint256 oldD = totalSupply;

        uint256 newD = oldD - _amount;
        // y is converted(18 decimals)
        uint256 y = _getY(_balances, _i, newD, A);
        // dy is not converted
        // dy = (balance[i] - y - 1) / precisions[i] in case there was rounding errors
        uint256 dy = (_balances[_i] - y - 1) / precisions[_i];
        uint256 feeAmount = 0;
        if (redeemFee > 0) {
            dy -= (dy * redeemFee) / FEE_DENOMINATOR;
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
        require(!paused, Paused());

        collectFeeOrYield(false);
        uint256[] memory _balances = balances;
        uint256 oldD = totalSupply;
        _balances = _updateBalancesForWithdrawal(_balances, _amounts);
        uint256 newD = _getD(_balances, A);

        // newD should be smaller than or equal to oldD
        uint256 redeemAmount = oldD - newD;
        uint256 feeAmount = 0;
        if (redeemFee > 0) {
            uint256[] memory fees = new uint256[](_balances.length);
            for (uint256 i = 0; i < _balances.length; i++) {
                uint256 idealBalance = newD * balances[i] / oldD;
                uint256 difference =
                    idealBalance > _balances[i] ? idealBalance - _balances[i] : _balances[i] - idealBalance;
                fees[i] = (difference * redeemFee) / FEE_DENOMINATOR;
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
     * @dev Pause mint/swap/redeem actions. Can unpause later.
     */
    function pause() external onlyOwner {
        require(!paused, Paused());

        paused = true;
        emit PoolPaused();
    }

    /**
     * @dev Unpause mint/swap/redeem actions.
     */
    function unpause() external onlyOwner {
        require(paused, NotPaused());

        paused = false;
        emit PoolUnpaused();
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
        poolToken.addBuffer(donationAmount, true);

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
                (balanceI * exchangeRateProviders[i].exchangeRate() * precisions[i]) / (10 ** exchangeRateDecimals[i]);
        }
        uint256 newD = _getD(_balances, getCurrentA());

        require(newD < oldD, NoLosses());
        poolToken.removeTotalSupply(oldD - newD, false, false);

        balances = _balances;
        totalSupply = newD;
    }

    /**
     * @notice This function allows to rebase SPAToken by increasing his total supply
     * from the current stableSwap pool by the staking rewards and the swap fee.
     */
    function rebase() external syncRamping returns (uint256) {
        uint256[] memory _balances = balances;
        uint256 oldD = totalSupply;

        for (uint256 i = 0; i < _balances.length; i++) {
            uint256 balanceI = IERC20(tokens[i]).balanceOf(address(this));
            _balances[i] =
                (balanceI * exchangeRateProviders[i].exchangeRate() * precisions[i]) / (10 ** exchangeRateDecimals[i]);
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

        uint256 newD = D - _amount;
        uint256 y = _getY(_balances, _i, newD, getCurrentA());
        uint256 dy = (_balances[_i] - y - 1) / precisions[_i];
        uint256 feeAmount = 0;
        if (redeemFee > 0) {
            feeAmount = (dy * redeemFee) / FEE_DENOMINATOR;
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
            uint256[] memory fees = new uint256[](_balances.length);
            for (uint256 i = 0; i < _balances.length; i++) {
                uint256 idealBalance = newD * balances[i] / oldD;
                uint256 difference =
                    idealBalance > _balances[i] ? idealBalance - _balances[i] : _balances[i] - idealBalance;
                fees[i] = (difference * redeemFee) / FEE_DENOMINATOR;
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
            uint256[] memory fees = new uint256[](_balances.length);
            for (uint256 i = 0; i < _balances.length; i++) {
                uint256 idealBalance = newD * balances[i] / oldD;
                uint256 difference =
                    idealBalance > _balances[i] ? idealBalance - _balances[i] : _balances[i] - idealBalance;
                fees[i] = (difference * mintFee) / FEE_DENOMINATOR;
                feeAmount += fees[i];
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

        // balance[i] = balance[i] + dx * precisions[i]

        _balances[_i] +=
            (_dx * exchangeRateProviders[_i].exchangeRate() * precisions[_i]) / (10 ** exchangeRateDecimals[_i]);
        uint256 y = _getY(_balances, _j, D, getCurrentA());
        // dy = (balance[j] - y - 1) / precisions[j] in case there was rounding errors
        uint256 dy = (_balances[_j] - y - 1) / precisions[_j];
        uint256 feeAmount = 0;

        if (swapFee > 0) {
            feeAmount = (dy * swapFee) / FEE_DENOMINATOR;
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
     */
    function getRedeemProportionAmount(uint256 _amount) external view returns (uint256[] memory) {
        (uint256[] memory _balances, uint256 D) = getUpdatedBalancesAndD();
        require(_amount != 0, ZeroAmount());

        uint256[] memory amounts = new uint256[](_balances.length);
        uint256 redeemAmount = _amount;

        for (uint256 i = 0; i < _balances.length; i++) {
            // We might choose to use poolToken.totalSupply to compute the amount, but decide to use
            // D in case we have multiple minters on the pool token.
            amounts[i] = (_balances[i] * redeemAmount) / D / precisions[i];
            amounts[i] = (amounts[i] * (10 ** exchangeRateDecimals[i])) / exchangeRateProviders[i].exchangeRate();
        }

        return (amounts);
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

    function _syncTotalSupply() internal {
        uint256 newD;
        (balances, newD) = getUpdatedBalancesAndD();

        if (totalSupply > newD) {
            // A decreased
            poolToken.removeTotalSupply(totalSupply - newD, true, false);
            totalSupply = newD;
        } else if (newD > totalSupply) {
            // A increased
            poolToken.addBuffer(newD - totalSupply, false);
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

    function _setWholesalerRates(address[] memory _wholesalers, uint16[] memory _rates) private {
        require(_wholesalers.length == _rates.length, InputMismatch());

        for (uint256 i = 0; i < _wholesalers.length; i++) {
            require(_rates[i] < RATE_DENOMINATOR, InvalidAmount());
            uint16 oldRate = wholesalerRate[_wholesalers[i]];
            wholesalerRate[_wholesalers[i]] = _rates[i];
            emit WholesalerRateUpdated(_wholesalers[i], oldRate, _rates[i]);
        }
    }

    function _swapPreFee(
        uint256 _i,
        uint256 _j,
        uint256 _dx
    )
        private
        returns (uint256 dy, uint256[] memory _balances)
    {
        require(!paused, Paused());
        require(_i != _j, SameToken());
        require(_i < balances.length, InvalidIn());
        require(_j < balances.length, InvalidOut());
        require(_dx != 0, InvalidAmount());

        collectFeeOrYield(false);

        _balances = balances;
        _balances[_i] +=
            (_dx * exchangeRateProviders[_i].exchangeRate() * precisions[_i]) / (10 ** exchangeRateDecimals[_i]);

        uint256 y = _getY(_balances, _j, totalSupply, A);
        dy = (_balances[_j] - y - 1) / precisions[_j];

        // update balances in storage
        balances[_j] = y;
        balances[_i] = _balances[_i];
    }

    function _swapPostFee(
        uint256 _i,
        uint256 _j,
        uint256 _dx,
        uint256 dy,
        uint256 _minDy,
        uint256[] memory _balances,
        uint256 discount
    )
        private
        returns (uint256)
    {
        _minDy = (_minDy * exchangeRateProviders[_j].exchangeRate()) / (10 ** exchangeRateDecimals[_j]);
        if (dy < _minDy) revert InsufficientSwapOutAmount(dy, _minDy);

        IERC20(tokens[_i]).safeTransferFrom(msg.sender, address(this), _dx);

        uint256 transferAmountJ = (dy * (10 ** exchangeRateDecimals[_j])) / exchangeRateProviders[_j].exchangeRate();
        IERC20(tokens[_j]).safeTransfer(msg.sender, transferAmountJ);

        uint256[] memory amounts = new uint256[](_balances.length);
        amounts[_i] = _dx;
        amounts[_j] = transferAmountJ;

        uint256 feeAmountActual = collectFeeOrYield(true);
        emit TokenSwapped(msg.sender, transferAmountJ, amounts, feeAmountActual, discount);

        return transferAmountJ;
    }
}
