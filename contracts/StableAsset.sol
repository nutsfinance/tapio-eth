// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./misc/IERC20MintableBurnable.sol";
import "./interfaces/IExchangeRateProvider.sol";
import "./interfaces/ITapETH.sol";

/**
 * @title StableAsset swap
 * @author Nuts Finance Developer
 * @notice The StableAsset pool provides a way to swap between different tokens
 * @dev The StableAsset contract allows users to trade between different tokens, with prices determined algorithmically based on the current supply and demand of each token
 */
contract StableAsset is Initializable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /**
     * @notice This event is emitted when a token swap occurs.
     * @param buyer is the address of the account that made the swap.
     * @param amounts is an array containing the amounts of each token received by the buyer.
     * @param feeAmount is the amount of transaction fee charged for the swap.
     */
    event TokenSwapped(
        address indexed buyer,
        uint256 swapAmount,
        uint256[] amounts,
        bool[] amountPositive,
        uint256 feeAmount
    );
    /**
     * @notice This event is emitted when liquidity is added to the StableAsset contract.
     * @param provider is the address of the liquidity provider.
     * @param mintAmount is the amount of liquidity tokens minted to the provider in exchange for their contribution.
     * @param amounts is an array containing the amounts of each token contributed by the provider.
     * @param feeAmount is the amount of transaction fee charged for the liquidity provision.
     */
    event Minted(
        address indexed provider,
        uint256 mintAmount,
        uint256[] amounts,
        uint256 feeAmount
    );
    /**
     * @dev This event is emitted when liquidity is removed from the StableAsset contract.
     * @param provider is the address of the liquidity provider.
     * @param redeemAmount is the amount of liquidity tokens redeemed by the provider.
     * @param amounts is an array containing the amounts of each token received by the provider.
     * @param feeAmount is the amount of transaction fee charged for the liquidity provision.
     */
    event Redeemed(
        address indexed provider,
        uint256 redeemAmount,
        uint256[] amounts,
        uint256 feeAmount
    );
    /**
     * @dev This event is emitted when transaction fees are collected by the StableAsset contract.
     * @param feeAmount is the amount of fee collected.
     * @param totalSupply is the total supply of LP token.
     */
    event FeeCollected(uint256 feeAmount, uint256 totalSupply);
    /**
     * @dev This event is emitted when yield is collected by the StableAsset contract.
     * @param amounts is an array containing the amounts of each token the yield receives.
     * @param feeAmount is the amount of yield collected.
     * @param totalSupply is the total supply of LP token.
     */
    event YieldCollected(
        uint256[] amounts,
        uint256 feeAmount,
        uint256 totalSupply
    );
    /**
     * @dev This event is emitted when the A parameter is modified.
     * @param futureA is the new value of the A parameter.
     * @param futureABlock is the block number at which the new value of the A parameter will take effect.
     */
    event AModified(uint256 futureA, uint256 futureABlock);

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
     * @dev This event is emitted when the fee recipient is modified.
     * @param recipient is the new value of the recipient.
     */
    event FeeRecipientModified(address recipient);

    /**
     * @dev This event is emitted when the yield recipient is modified.
     * @param recipient is the new value of the recipient.
     */
    event YieldRecipientModified(address recipient);

    /**
     * @dev This event is emitted when the governance is modified.
     * @param governance is the new value of the governance.
     */
    event GovernanceModified(address governance);

    /**
     * @dev This event is emitted when the governance is modified.
     * @param governance is the new value of the governance.
     */
    event GovernanceProposed(address governance);

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
     * @dev This event is emitted when the max delta D is modified.
     * @param delta is the new value of the delta.
     */
    event MaxDeltaDModified(uint256 delta);

    /**
     * @dev This is the denominator used for calculating transaction fees in the StableAsset contract.
     */
    uint256 public constant FEE_DENOMINATOR = 10 ** 10;
    /**
     *  @dev This is the maximum error margin for calculating transaction fees in the StableAsset contract.
     */
    uint256 private constant DEFAULT_FEE_ERROR_MARGIN = 100000;

    /**
     *  @dev This is the maximum error margin for calculating transaction yield in the StableAsset contract.
     */
    uint256 private constant DEFAULT_YIELD_ERROR_MARGIN = 10000;

    /**
     *  @dev This is the maximum error margin for updating A in the StableAsset contract.
     */
    uint256 private constant DEFAULT_MAX_DELTA_D = 100000;
    /**
     * @dev This is the maximum value of the amplification coefficient A.
     */
    uint256 public constant MAX_A = 10 ** 6;

    /**
     * @dev This is an array of addresses representing the tokens currently supported by the StableAsset contract.
     */
    address[] public tokens;
    /**
     * @dev This is an array of uint256 values representing the precisions of each token in the StableAsset contract.
     * The precision of each token is calculated as 10 ** (18 - token decimals).
     */
    uint256[] public precisions;
    /**
     * @dev This is an array of uint256 values representing the current balances of each token in the StableAsset contract.
     * The balances are converted to the standard token unit (10 ** 18).
     */
    uint256[] public balances;
    /**
     * @dev This is the fee charged for adding liquidity to the StableAsset contract.
     */
    uint256 public mintFee;
    /**
     * @dev This is the fee charged for trading assets in the StableAsset contract.
     * swapFee = swapFee * FEE_DENOMINATOR
     */
    uint256 public swapFee;
    /**
     * @dev This is the fee charged for removing liquidity from the StableAsset contract.
     * redeemFee = redeemFee * FEE_DENOMINATOR
     */
    uint256 public redeemFee;
    /**
     * @dev This is the account which receives transaction fees collected by the StableAsset contract.
     */
    address public feeRecipient;
    /**
     * @dev This is the account which receives yield generated by the StableAsset contract.
     */
    address public yieldRecipient;
    /**
     * @dev This is the address of the ERC20 token contract that represents the StableAsset pool token.
     */
    ITapETH public poolToken;
    /**
     * @dev The total supply of pool token minted by the swap.
     * It might be different from the pool token supply as the pool token can have multiple minters.
     */
    uint256 public totalSupply;
    /**
     * @dev This is the account that has governance control over the StableAsset contract.
     */
    address public governance;
    /**
     * @dev This is a mapping of accounts that have administrative privileges over the StableAsset contract.
     */
    mapping(address => bool) public admins;
    /**
     * @dev This is a state variable that represents whether or not the StableAsset contract is currently paused.
     */
    bool public paused;

    /**
     * @dev These is a state variables that represents the initial amplification coefficient A.
     */
    uint256 public initialA;
    /**
     * @dev These is a state variables that represents the initial block number when A is set.
     */
    uint256 public initialABlock;
    /**
     * @dev These is a state variables that represents the future amplification coefficient A.
     */
    uint256 public futureA;
    /**
     * @dev These is a state variables that represents the future block number when A is set.
     */
    uint256 public futureABlock;
    /**
     * @dev Exchange rate provider for token at exchangeRateTokenIndex.
     */
    IExchangeRateProvider public exchangeRateProvider;
    /**
     * @dev Index of tokens array for IExchangeRateProvider.
     */
    uint256 public exchangeRateTokenIndex;

    /**
     * @dev Fee error margin.
     */
    uint256 public feeErrorMargin;

    /**
     * @dev Yield error margin.
     */
    uint256 public yieldErrorMargin;

    /**
     * @dev Max delta D.
     */
    uint256 public maxDeltaD;

    /**
     * @dev Pending governance address,
     */
    address public pendingGovernance;

    /**
     * @dev Initializes the StableAsset contract with the given parameters.
     * @param _tokens The tokens in the pool.
     * @param _precisions The precisions of each token (10 ** (18 - token decimals)).
     * @param _fees The fees for minting, swapping, and redeeming.
     * @param _feeRecipient The address that collects the fees.
     * @param _yieldRecipient The address that receives yield farming rewards.
     * @param _poolToken The address of the pool token.
     * @param _A The initial value of the amplification coefficient A for the pool.
     */
    function initialize(
        address[] memory _tokens,
        uint256[] memory _precisions,
        uint256[] memory _fees,
        address _feeRecipient,
        address _yieldRecipient,
        ITapETH _poolToken,
        uint256 _A,
        IExchangeRateProvider _exchangeRateProvider,
        uint256 _exchangeRateTokenIndex
    ) public initializer {
        require(
            _tokens.length >= 2 && _tokens.length == _precisions.length,
            "input mismatch"
        );
        require(_fees.length == 3, "no fees");
        for (uint256 i = 0; i < 3; i++) {
            require(_fees[i] < FEE_DENOMINATOR, "fee percentage too large");
        }
        for (uint256 i = 0; i < _tokens.length; i++) {
            require(_tokens[i] != address(0x0), "token not set");
            // query tokens decimals
            uint256 _decimals = ERC20Upgradeable(_tokens[i]).decimals();
            require(
                _precisions[i] != 0 && _precisions[i] == 10 ** (18 - _decimals),
                "precision not set"
            );
            require(_precisions[i] != 0, "precision not set");
            balances.push(0);
        }
        require(_feeRecipient != address(0x0), "fee recipient not set");
        require(_yieldRecipient != address(0x0), "yield recipient not set");
        require(address(_poolToken) != address(0x0), "pool token not set");
        require(_A > 0 && _A < MAX_A, "A not set");
        require(
            address(_exchangeRateProvider) != address(0x0),
            "exchangeRate not set"
        );
        require(
            _exchangeRateTokenIndex < _tokens.length,
            "exchange rate token index out of range"
        );
        __ReentrancyGuard_init();

        governance = msg.sender;
        feeRecipient = _feeRecipient;
        yieldRecipient = _yieldRecipient;
        tokens = _tokens;
        precisions = _precisions;
        mintFee = _fees[0];
        swapFee = _fees[1];
        redeemFee = _fees[2];
        poolToken = _poolToken;
        exchangeRateProvider = _exchangeRateProvider;
        exchangeRateTokenIndex = _exchangeRateTokenIndex;

        initialA = _A;
        futureA = _A;
        initialABlock = block.number;
        futureABlock = block.number;
        feeErrorMargin = DEFAULT_FEE_ERROR_MARGIN;
        yieldErrorMargin = DEFAULT_YIELD_ERROR_MARGIN;
        maxDeltaD = DEFAULT_MAX_DELTA_D;

        // The swap must start with paused state!
        paused = true;
    }

    /**
     * @dev Returns the current value of A. This method might be updated in the future.
     * @return The current value of A.
     */
    function getA() public view returns (uint256) {
        uint256 currentBlock = block.number;
        if (currentBlock < futureABlock) {
            uint256 blockDiff = currentBlock - initialABlock;
            uint256 blockDiffDiv = futureABlock - initialABlock;
            if (futureA > initialA) {
                uint256 diff = futureA - initialA;
                uint256 amount = (diff * blockDiff) / blockDiffDiv;
                return initialA + amount;
            } else {
                uint256 diff = initialA - futureA;
                uint256 amount = (diff * blockDiff) / blockDiffDiv;
                return initialA - amount;
            }
        } else {
            return futureA;
        }
    }

    /**
     * @dev Computes D given token balances.
     * @param _balances Normalized balance of each token.
     * @param _A Amplification coefficient from getA().
     * @return D The StableAsset invariant.
     */
    function _getD(
        uint256[] memory _balances,
        uint256 _A
    ) internal pure returns (uint256) {
        uint256 sum = 0;
        uint256 i = 0;
        uint256 Ann = _A;
        /*
         * We choose to implement n*n instead of n*(n-1) because it's
         * clearer in code and A value across pool is comparable.
         */
        for (i = 0; i < _balances.length; i++) {
            sum = sum + _balances[i];
            Ann = Ann * _balances.length;
        }
        if (sum == 0) return 0;

        uint256 prevD = 0;
        uint256 D = sum;
        for (i = 0; i < 255; i++) {
            uint256 pD = D;
            for (uint256 j = 0; j < _balances.length; j++) {
                pD = (pD * D) / (_balances[j] * _balances.length);
            }
            prevD = D;
            D =
                ((Ann * sum + pD * _balances.length) * D) /
                ((Ann - 1) * D + (_balances.length + 1) * pD);
            if (D > prevD) {
                if (D - prevD <= 1) break;
            } else {
                if (prevD - D <= 1) break;
            }
        }
        if (i == 255) {
            revert("doesn't converge");
        }
        return D;
    }

    /**
     * @dev Computes token balance given D.
     * @param _balances Converted balance of each token except token with index _j.
     * @param _j Index of the token to calculate balance.
     * @param _D The target D value.
     * @param _A Amplification coeffient.
     * @return Converted balance of the token with index _j.
     */
    function _getY(
        uint256[] memory _balances,
        uint256 _j,
        uint256 _D,
        uint256 _A
    ) internal pure returns (uint256) {
        uint256 c = _D;
        uint256 S_ = 0;
        uint256 Ann = _A;
        uint256 i = 0;
        for (i = 0; i < _balances.length; i++) {
            Ann = Ann * _balances.length;
            if (i == _j) continue;
            S_ = S_ + _balances[i];
            c = (c * _D) / (_balances[i] * _balances.length);
        }
        c = (c * _D) / (Ann * _balances.length);
        uint256 b = S_ + (_D / Ann);
        uint256 prevY = 0;
        uint256 y = _D;

        // 255 since the result is 256 digits
        for (i = 0; i < 255; i++) {
            prevY = y;
            // y = (y * y + c) / (2 * y + b - D)
            y = (y * y + c) / (y * 2 + b - _D);
            if (y > prevY) {
                if (y - prevY <= 1) break;
            } else {
                if (prevY - y <= 1) break;
            }
        }
        if (i == 255) {
            revert("doesn't converge");
        }
        return y;
    }

    /**
     * @dev Compute the amount of pool token that can be minted.
     * @param _amounts Unconverted token balances.
     * @return The amount of pool tokens to be minted.
     * @return The amount of fees charged.
     */
    function getMintAmount(
        uint256[] calldata _amounts
    ) external view returns (uint256, uint256) {
        uint256[] memory _balances;
        uint256 _totalSupply;
        (_balances, _totalSupply) = getPendingYieldAmount();
        require(_amounts.length == _balances.length, "invalid amount");

        uint256 A = getA();
        uint256 oldD = _totalSupply;
        uint256 i = 0;
        for (i = 0; i < _balances.length; i++) {
            if (_amounts[i] == 0) continue;
            uint256 balanceAmount = _amounts[i];
            if (i == exchangeRateTokenIndex) {
                balanceAmount =
                    (balanceAmount * exchangeRateProvider.exchangeRate()) /
                    (10 ** exchangeRateProvider.exchangeRateDecimals());
            }
            // balance = balance + amount * precision
            _balances[i] = _balances[i] + (balanceAmount * precisions[i]);
        }
        uint256 newD = _getD(_balances, A);
        // newD should be bigger than or equal to oldD
        uint256 mintAmount = newD - oldD;
        uint256 feeAmount = 0;

        if (mintFee > 0) {
            feeAmount = (mintAmount * mintFee) / FEE_DENOMINATOR;
            mintAmount = mintAmount - feeAmount;
        }

        return (mintAmount, feeAmount);
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
    ) external nonReentrant returns (uint256) {
        // If swap is paused, only admins can mint.
        require(!paused || admins[msg.sender], "paused");
        require(balances.length == _amounts.length, "invalid amounts");

        collectFeeOrYield(false);
        uint256[] memory _balances = balances;
        uint256 A = getA();
        uint256 oldD = totalSupply;
        uint256 i = 0;
        for (i = 0; i < _balances.length; i++) {
            if (_amounts[i] == 0) {
                // Initial deposit requires all tokens provided!
                require(oldD > 0, "zero amount");
                continue;
            }
            uint256 balanceAmount = _amounts[i];
            if (i == exchangeRateTokenIndex) {
                balanceAmount =
                    (balanceAmount * exchangeRateProvider.exchangeRate()) /
                    (10 ** exchangeRateProvider.exchangeRateDecimals());
            }
            _balances[i] = _balances[i] + (balanceAmount * precisions[i]);
        }
        uint256 newD = _getD(_balances, A);
        // newD should be bigger than or equal to oldD
        uint256 mintAmount = newD - oldD;

        uint256 feeAmount = 0;
        if (mintFee > 0) {
            feeAmount = (mintAmount * mintFee) / FEE_DENOMINATOR;
            mintAmount = mintAmount - feeAmount;
        }
        require(mintAmount >= _minMintAmount, "fewer than expected");

        // Transfer tokens into the swap
        for (i = 0; i < _amounts.length; i++) {
            if (_amounts[i] == 0) continue;
            // Update the balance in storage
            balances[i] = _balances[i];
            IERC20Upgradeable(tokens[i]).safeTransferFrom(
                msg.sender,
                address(this),
                _amounts[i]
            );
        }
        totalSupply = newD;
        poolToken.mintShares(msg.sender, mintAmount);
        if (feeAmount != 0) {
            poolToken.setTotalSupply(feeAmount);
        }
        collectFeeOrYield(true);
        emit Minted(msg.sender, mintAmount, _amounts, feeAmount);
        return mintAmount;
    }

    /**
     * @dev Computes the output amount after the swap.
     * @param _i Token index to swap in.
     * @param _j Token index to swap out.
     * @param _dx Unconverted amount of token _i to swap in.
     * @return Unconverted amount of token _j to swap out.
     * @return The amount of fees charged.
     */
    function getSwapAmount(
        uint256 _i,
        uint256 _j,
        uint256 _dx
    ) external view returns (uint256, uint256) {
        uint256[] memory _balances;
        uint256 _totalSupply;
        (_balances, _totalSupply) = getPendingYieldAmount();
        require(_i != _j, "same token");
        require(_i < _balances.length, "invalid in");
        require(_j < _balances.length, "invalid out");
        require(_dx > 0, "invalid amount");

        uint256 A = getA();
        uint256 D = _totalSupply;
        uint256 balanceAmount = _dx;
        if (_i == exchangeRateTokenIndex) {
            balanceAmount =
                (balanceAmount * exchangeRateProvider.exchangeRate()) /
                (10 ** exchangeRateProvider.exchangeRateDecimals());
        }
        // balance[i] = balance[i] + dx * precisions[i]
        _balances[_i] = _balances[_i] + (balanceAmount * precisions[_i]);
        uint256 y = _getY(_balances, _j, D, A);
        // dy = (balance[j] - y - 1) / precisions[j] in case there was rounding errors
        uint256 dy = (_balances[_j] - y - 1) / precisions[_j];
        uint256 feeAmount = 0;

        if (swapFee > 0) {
            feeAmount = (dy * swapFee) / FEE_DENOMINATOR;
            dy = dy - feeAmount;
        }

        uint256 transferAmountJ = dy;
        uint256 feeAmountReturn = feeAmount;
        if (_j == exchangeRateTokenIndex) {
            transferAmountJ =
                (transferAmountJ *
                    (10 ** exchangeRateProvider.exchangeRateDecimals())) /
                exchangeRateProvider.exchangeRate();
            feeAmountReturn =
                (feeAmountReturn *
                    (10 ** exchangeRateProvider.exchangeRateDecimals())) /
                exchangeRateProvider.exchangeRate();
        }

        return (transferAmountJ, feeAmountReturn);
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
    ) external nonReentrant returns (uint256) {
        // If swap is paused, only admins can swap.
        require(!paused || admins[msg.sender], "paused");
        require(_i != _j, "same token");
        require(_i < balances.length, "invalid in");
        require(_j < balances.length, "invalid out");
        require(_dx > 0, "invalid amount");

        collectFeeOrYield(false);
        uint256[] memory _balances = balances;
        uint256 A = getA();
        uint256 D = totalSupply;
        uint256 balanceAmount = _dx;
        if (_i == exchangeRateTokenIndex) {
            balanceAmount =
                (balanceAmount * exchangeRateProvider.exchangeRate()) /
                (10 ** exchangeRateProvider.exchangeRateDecimals());
        }
        // balance[i] = balance[i] + dx * precisions[i]
        _balances[_i] = _balances[_i] + (balanceAmount * precisions[_i]);
        uint256 y = _getY(_balances, _j, D, A);
        // dy = (balance[j] - y - 1) / precisions[j] in case there was rounding errors
        uint256 dy = (_balances[_j] - y - 1) / precisions[_j];
        // Update token balance in storage
        balances[_j] = y;
        balances[_i] = _balances[_i];

        uint256 feeAmount = 0;
        if (swapFee > 0) {
            feeAmount = (dy * swapFee) / FEE_DENOMINATOR;
            dy = dy - feeAmount;
        }
        if (_j == exchangeRateTokenIndex) {
            _minDy =
                (_minDy * exchangeRateProvider.exchangeRate()) /
                (10 ** exchangeRateProvider.exchangeRateDecimals());
        }
        require(dy >= _minDy, "fewer than expected");

        IERC20Upgradeable(tokens[_i]).safeTransferFrom(
            msg.sender,
            address(this),
            _dx
        );
        // Important: When swap fee > 0, the swap fee is charged on the output token.
        // Therefore, balances[j] < tokens[j].balanceOf(this)
        // Since balances[j] is used to compute D, D is unchanged.
        // collectFees() is used to convert the difference between balances[j] and tokens[j].balanceOf(this)
        // into pool token as fees!
        uint256 transferAmountJ = dy;
        if (_j == exchangeRateTokenIndex) {
            transferAmountJ =
                (transferAmountJ *
                    (10 ** exchangeRateProvider.exchangeRateDecimals())) /
                exchangeRateProvider.exchangeRate();
        }
        IERC20Upgradeable(tokens[_j]).safeTransfer(msg.sender, transferAmountJ);

        uint256[] memory amounts = new uint256[](_balances.length);
        bool[] memory amountPositive = new bool[](_balances.length);
        amounts[_i] = _dx;
        amounts[_j] = transferAmountJ;
        amountPositive[_i] = false;
        amountPositive[_j] = true;

        feeAmount = collectFeeOrYield(true);
        emit TokenSwapped(
            msg.sender,
            transferAmountJ,
            amounts,
            amountPositive,
            feeAmount
        );
        return transferAmountJ;
    }

    /**
     * @dev Computes the amounts of underlying tokens when redeeming pool token.
     * @param _amount Amount of pool tokens to redeem.
     * @return An array of the amounts of each token to redeem.
     * @return The amount of fee charged
     */
    function getRedeemProportionAmount(
        uint256 _amount
    ) external view returns (uint256[] memory, uint256) {
        uint256[] memory _balances;
        uint256 _totalSupply;
        (_balances, _totalSupply) = getPendingYieldAmount();
        require(_amount > 0, "zero amount");

        uint256 D = _totalSupply;
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
            amounts[i] = (_balances[i] * redeemAmount) / D / precisions[i];
            uint256 transferAmount = amounts[i];
            if (i == exchangeRateTokenIndex) {
                transferAmount =
                    (transferAmount *
                        (10 ** exchangeRateProvider.exchangeRateDecimals())) /
                    exchangeRateProvider.exchangeRate();
            }
            amounts[i] = transferAmount;
        }

        return (amounts, feeAmount);
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
    ) external nonReentrant returns (uint256[] memory) {
        // If swap is paused, only admins can redeem.
        require(!paused || admins[msg.sender], "paused");
        require(_amount > 0, "zero amount");
        require(balances.length == _minRedeemAmounts.length, "invalid mins");

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
            uint256 minRedeemAmount = _minRedeemAmounts[i];
            if (i == exchangeRateTokenIndex) {
                minRedeemAmount =
                    (minRedeemAmount * exchangeRateProvider.exchangeRate()) /
                    (10 ** exchangeRateProvider.exchangeRateDecimals());
            }
            require(amounts[i] >= minRedeemAmount, "fewer than expected");
            // Updates the balance in storage
            balances[i] = _balances[i] - tokenAmount;
            uint256 transferAmount = amounts[i];
            if (i == exchangeRateTokenIndex) {
                transferAmount =
                    (transferAmount *
                        (10 ** exchangeRateProvider.exchangeRateDecimals())) /
                    exchangeRateProvider.exchangeRate();
            }
            amounts[i] = transferAmount;
            IERC20Upgradeable(tokens[i]).safeTransfer(
                msg.sender,
                transferAmount
            );
        }

        totalSupply = D - _amount;
        // After reducing the redeem fee, the remaining pool tokens are burned!
        uint256 _sharesAmount = poolToken.getPooledEthByShares(_amount);
        poolToken.burnSharesFrom(msg.sender, _sharesAmount);

        feeAmount = collectFeeOrYield(true);
        emit Redeemed(msg.sender, _amount, amounts, feeAmount);
        return amounts;
    }

    /**
     * @dev Computes the amount when redeeming pool token to one specific underlying token.
     * @param _amount Amount of pool token to redeem.
     * @param _i Index of the underlying token to redeem to.
     * @return The amount of single token that will be redeemed.
     * @return The amount of pool token charged for redemption fee.
     */
    function getRedeemSingleAmount(
        uint256 _amount,
        uint256 _i
    ) external view returns (uint256, uint256) {
        uint256[] memory _balances;
        uint256 _totalSupply;
        (_balances, _totalSupply) = getPendingYieldAmount();

        require(_amount > 0, "zero amount");
        require(_i < _balances.length, "invalid token");

        uint256 A = getA();
        uint256 D = _totalSupply;
        uint256 feeAmount = 0;
        uint256 redeemAmount = _amount;
        if (redeemFee > 0) {
            feeAmount = (_amount * redeemFee) / FEE_DENOMINATOR;
            redeemAmount = _amount - feeAmount;
        }
        // The pool token amount becomes D - redeemAmount
        uint256 y = _getY(_balances, _i, D - redeemAmount, A);
        // dy = (balance[i] - y - 1) / precisions[i] in case there was rounding errors
        uint256 dy = (_balances[_i] - y - 1) / precisions[_i];
        uint256 transferAmount = dy;
        if (_i == exchangeRateTokenIndex) {
            transferAmount =
                (transferAmount *
                    (10 ** exchangeRateProvider.exchangeRateDecimals())) /
                exchangeRateProvider.exchangeRate();
        }

        return (transferAmount, feeAmount);
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
    ) external nonReentrant returns (uint256) {
        // If swap is paused, only admins can redeem.
        require(!paused || admins[msg.sender], "paused");
        require(_amount > 0, "zero amount");
        require(_i < balances.length, "invalid token");

        collectFeeOrYield(false);
        uint256[] memory _balances = balances;
        uint256 A = getA();
        uint256 D = totalSupply;
        uint256 feeAmount = 0;
        uint256 redeemAmount = _amount;
        if (redeemFee > 0) {
            feeAmount = (_amount * redeemFee) / FEE_DENOMINATOR;
            redeemAmount = _amount - feeAmount;
        }
        if (_i == exchangeRateTokenIndex) {
            _minRedeemAmount =
                (_minRedeemAmount * exchangeRateProvider.exchangeRate()) /
                (10 ** exchangeRateProvider.exchangeRateDecimals());
        }

        // y is converted(18 decimals)
        uint256 y = _getY(_balances, _i, D - redeemAmount, A);
        // dy is not converted
        // dy = (balance[i] - y - 1) / precisions[i] in case there was rounding errors
        uint256 dy = (_balances[_i] - y - 1) / precisions[_i];
        require(dy >= _minRedeemAmount, "fewer than expected");
        // Updates token balance in storage
        balances[_i] = y;
        uint256[] memory amounts = new uint256[](_balances.length);
        uint256 transferAmount = dy;
        if (_i == exchangeRateTokenIndex) {
            transferAmount =
                (transferAmount *
                    (10 ** exchangeRateProvider.exchangeRateDecimals())) /
                exchangeRateProvider.exchangeRate();
        }
        amounts[_i] = transferAmount;
        IERC20Upgradeable(tokens[_i]).safeTransfer(msg.sender, transferAmount);
        totalSupply = D - _amount;
        uint256 _sharesAmount = poolToken.getPooledEthByShares(_amount);
        poolToken.burnSharesFrom(msg.sender, _sharesAmount);
        feeAmount = collectFeeOrYield(true);
        emit Redeemed(msg.sender, _amount, amounts, feeAmount);
        return transferAmount;
    }

    /**
     * @dev Compute the amount of pool token that needs to be redeemed.
     * @param _amounts Unconverted token balances.
     * @return The amount of pool token that needs to be redeemed.
     * @return The amount of pool token charged for redemption fee.
     */
    function getRedeemMultiAmount(
        uint256[] calldata _amounts
    ) external view returns (uint256, uint256) {
        uint256[] memory _balances;
        uint256 _totalSupply;
        (_balances, _totalSupply) = getPendingYieldAmount();
        require(_amounts.length == balances.length, "length not match");

        uint256 A = getA();
        uint256 oldD = _totalSupply;
        for (uint256 i = 0; i < _balances.length; i++) {
            if (_amounts[i] == 0) continue;
            // balance = balance + amount * precision
            uint256 balanceAmount = _amounts[i];
            if (i == exchangeRateTokenIndex) {
                balanceAmount =
                    (balanceAmount * exchangeRateProvider.exchangeRate()) /
                    10 ** exchangeRateProvider.exchangeRateDecimals();
            }
            _balances[i] = _balances[i] - (balanceAmount * precisions[i]);
        }
        uint256 newD = _getD(_balances, A);

        // newD should be smaller than or equal to oldD
        uint256 redeemAmount = oldD - newD;
        uint256 feeAmount = 0;
        if (redeemFee > 0) {
            redeemAmount =
                (redeemAmount * FEE_DENOMINATOR) /
                (FEE_DENOMINATOR - redeemFee);
            feeAmount = redeemAmount - (oldD - newD);
        }

        return (redeemAmount, feeAmount);
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
    ) external nonReentrant returns (uint256[] memory) {
        require(_amounts.length == balances.length, "length not match");
        // If swap is paused, only admins can redeem.
        require(!paused || admins[msg.sender], "paused");

        collectFeeOrYield(false);
        uint256[] memory _balances = balances;
        uint256 A = getA();
        uint256 oldD = totalSupply;
        uint256 i = 0;
        for (i = 0; i < _balances.length; i++) {
            if (_amounts[i] == 0) continue;
            uint256 balanceAmount = _amounts[i];
            if (i == exchangeRateTokenIndex) {
                balanceAmount =
                    (balanceAmount * exchangeRateProvider.exchangeRate()) /
                    10 ** exchangeRateProvider.exchangeRateDecimals();
            }
            // balance = balance + amount * precision
            _balances[i] = _balances[i] - (balanceAmount * precisions[i]);
        }
        uint256 newD = _getD(_balances, A);

        // newD should be smaller than or equal to oldD
        uint256 redeemAmount = oldD - newD;
        uint256 feeAmount = 0;
        if (redeemFee > 0) {
            redeemAmount =
                (redeemAmount * FEE_DENOMINATOR) /
                (FEE_DENOMINATOR - redeemFee);
            feeAmount = redeemAmount - (oldD - newD);
        }
        require(redeemAmount <= _maxRedeemAmount, "more than expected");

        // Updates token balances in storage.
        balances = _balances;
        totalSupply = oldD - redeemAmount;
        uint256 _sharesAmount = poolToken.getPooledEthByShares(redeemAmount);
        poolToken.burnSharesFrom(msg.sender, _sharesAmount);
        uint256[] memory amounts = _amounts;
        for (i = 0; i < _balances.length; i++) {
            if (_amounts[i] == 0) continue;
            IERC20Upgradeable(tokens[i]).safeTransfer(msg.sender, _amounts[i]);
        }

        feeAmount = collectFeeOrYield(true);
        emit Redeemed(msg.sender, redeemAmount, amounts, feeAmount);
        return amounts;
    }

    /**
     * @dev Return the amount of fee that's not collected.
     * @return The balances of underlying tokens.
     * @return The total supply of pool tokens.
     */
    function getPendingYieldAmount()
        internal
        view
        returns (uint256[] memory, uint256)
    {
        uint256[] memory _balances = balances;
        uint256 A = getA();

        for (uint256 i = 0; i < _balances.length; i++) {
            uint256 balanceI = IERC20Upgradeable(tokens[i]).balanceOf(
                address(this)
            );
            if (i == exchangeRateTokenIndex) {
                balanceI =
                    (balanceI * exchangeRateProvider.exchangeRate()) /
                    (10 ** exchangeRateProvider.exchangeRateDecimals());
            }
            _balances[i] = balanceI * precisions[i];
        }
        uint256 newD = _getD(_balances, A);

        return (_balances, newD);
    }

    /**
     * @dev Collect fee or yield based on the token balance difference.
     * @param isFee Whether to collect fee or yield.
     * @return The amount of fee or yield collected.
     */
    function collectFeeOrYield(bool isFee) internal returns (uint256) {
        uint256[] memory oldBalances = balances;
        uint256[] memory _balances = balances;
        uint256 A = getA();
        uint256 oldD = totalSupply;

        for (uint256 i = 0; i < _balances.length; i++) {
            uint256 balanceI = IERC20Upgradeable(tokens[i]).balanceOf(
                address(this)
            );
            if (i == exchangeRateTokenIndex) {
                balanceI =
                    (balanceI * (exchangeRateProvider.exchangeRate())) /
                    (10 ** exchangeRateProvider.exchangeRateDecimals());
            }
            _balances[i] = balanceI * precisions[i];
        }
        uint256 newD = _getD(_balances, A);

        balances = _balances;
        totalSupply = newD;

        if (isFee) {
            if (oldD > newD && (oldD - newD) < feeErrorMargin) {
                return 0;
            } else if (oldD > newD) {
                revert("pool imbalanced");
            }
        } else {
            if (oldD > newD && (oldD - newD) < yieldErrorMargin) {
                return 0;
            } else if (oldD > newD) {
                revert("pool imbalanced");
            }
        }
        uint256 feeAmount = newD - oldD;
        if (feeAmount == 0) {
            return 0;
        }
        poolToken.setTotalSupply(feeAmount);

        if (isFee) {
            //address recipient = feeRecipient;
            emit FeeCollected(feeAmount, totalSupply);
        } else {
            //address recipient = yieldRecipient;
            uint256[] memory amounts = new uint256[](_balances.length);
            for (uint256 i = 0; i < _balances.length; i++) {
                amounts[i] = _balances[i] - oldBalances[i];
            }
            emit YieldCollected(amounts, feeAmount, totalSupply);
        }
        return feeAmount;
    }

    /**
     * @dev Propose the govenance address.
     * @param _governance Address of the new governance.
     */
    function proposeGovernance(address _governance) public {
        require(msg.sender == governance, "not governance");
        pendingGovernance = _governance;
        emit GovernanceProposed(_governance);
    }

    /**
     * @dev Accept the govenance address.
     */
    function acceptGovernance() public {
        require(msg.sender == pendingGovernance, "not pending governance");
        governance = pendingGovernance;
        pendingGovernance = address(0);
        emit GovernanceModified(governance);
    }

    /**
     * @dev Updates the mint fee.
     * @param _mintFee The new mint fee.
     */
    function setMintFee(uint256 _mintFee) external {
        require(msg.sender == governance, "not governance");
        require(_mintFee < FEE_DENOMINATOR, "exceed limit");
        mintFee = _mintFee;
        emit MintFeeModified(_mintFee);
    }

    /**
     * @dev Updates the swap fee.
     * @param _swapFee The new swap fee.
     */
    function setSwapFee(uint256 _swapFee) external {
        require(msg.sender == governance, "not governance");
        require(_swapFee < FEE_DENOMINATOR, "exceed limit");
        swapFee = _swapFee;
        emit SwapFeeModified(_swapFee);
    }

    /**
     * @dev Updates the redeem fee.
     * @param _redeemFee The new redeem fee.
     */
    function setRedeemFee(uint256 _redeemFee) external {
        require(msg.sender == governance, "not governance");
        require(_redeemFee < FEE_DENOMINATOR, "exceed limit");
        redeemFee = _redeemFee;
        emit RedeemFeeModified(_redeemFee);
    }

    /**
     * @dev Updates the recipient of mint/swap/redeem fees.
     * @param _feeRecipient The new recipient of mint/swap/redeem fees.
     */
    function setFeeRecipient(address _feeRecipient) external {
        require(msg.sender == governance, "not governance");
        require(_feeRecipient != address(0x0), "fee recipient not set");
        feeRecipient = _feeRecipient;
        emit FeeRecipientModified(_feeRecipient);
    }

    /**
     * @dev Updates the recipient of yield.
     * @param _yieldRecipient The new recipient of yield.
     */
    function setYieldRecipient(address _yieldRecipient) external {
        require(msg.sender == governance, "not governance");
        require(_yieldRecipient != address(0x0), "fee recipient not set");
        yieldRecipient = _yieldRecipient;
        emit YieldRecipientModified(_yieldRecipient);
    }

    /**
     * @dev Pause mint/swap/redeem actions. Can unpause later.
     */
    function pause() external {
        require(msg.sender == governance, "not governance");
        require(!paused, "paused");

        paused = true;
    }

    /**
     * @dev Unpause mint/swap/redeem actions.
     */
    function unpause() external {
        require(msg.sender == governance, "not governance");
        require(paused, "not paused");

        paused = false;
    }

    /**
     * @dev Updates the admin role for the address.
     * @param _account Address to update admin role.
     * @param _allowed Whether the address is granted the admin role.
     */
    function setAdmin(address _account, bool _allowed) external {
        require(msg.sender == governance, "not governance");
        require(_account != address(0x0), "account not set");

        admins[_account] = _allowed;
    }

    /**
     * @dev Update the A value.
     * @param _futureA The new A value.
     * @param _futureABlock The block number to update A value.
     */
    function updateA(uint256 _futureA, uint256 _futureABlock) external {
        require(msg.sender == governance, "not governance");
        require(_futureA > 0 && _futureA < MAX_A, "A not set");
        require(_futureABlock > block.number, "block in the past");

        initialA = getA();
        initialABlock = block.number;
        futureA = _futureA;
        futureABlock = _futureABlock;

        uint256 newD = _getD(balances, futureA);
        uint256 absolute = totalSupply > newD
            ? totalSupply - newD
            : newD - totalSupply;
        require(absolute < maxDeltaD, "Pool imbalanced");

        emit AModified(_futureA, _futureABlock);
    }

    /**
     * @dev update fee error margin.
     */
    function updateFeeErrorMargin(uint256 newValue) external {
        require(msg.sender == governance, "not governance");
        feeErrorMargin = newValue;
        emit FeeMarginModified(newValue);
    }

    /**
     * @dev update yield error margin.
     */
    function updateYieldErrorMargin(uint256 newValue) external {
        require(msg.sender == governance, "not governance");
        yieldErrorMargin = newValue;
        emit YieldMarginModified(newValue);
    }

    /**
     * @dev update yield error margin.
     */
    function updateMaxDeltaDMargin(uint256 newValue) external {
        require(msg.sender == governance, "not governance");
        maxDeltaD = newValue;
        emit MaxDeltaDModified(newValue);
    }

    /**
     * @dev Returns the array of token addresses in the pool.
     */
    function getTokens() public view returns (address[] memory) {
        return tokens;
    }

    /**
     * @notice This function allows to rebase TapETH by increasing his total supply
     * from the current stableSwap pool by the staking rewards and the swap fee.
     */
    function rebase() external returns (uint256) {
        uint256[] memory _balances = balances;
        uint256 A = getA();
        uint256 oldD = totalSupply;

        for (uint256 i = 0; i < _balances.length; i++) {
            uint256 balanceI = IERC20Upgradeable(tokens[i]).balanceOf(
                address(this)
            );
            if (i == exchangeRateTokenIndex) {
                balanceI =
                    (balanceI * (exchangeRateProvider.exchangeRate())) /
                    (10 ** exchangeRateProvider.exchangeRateDecimals());
            }
            _balances[i] = balanceI * precisions[i];
        }
        uint256 newD = _getD(_balances, A);

        if (oldD > newD) {
            return 0;
        } else {
            balances = _balances;
            totalSupply = newD;
            uint256 _amount = newD - oldD;
            poolToken.setTotalSupply(_amount);
            return _amount;
        }
    }
}
