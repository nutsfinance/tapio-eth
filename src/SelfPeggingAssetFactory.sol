// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./SelfPeggingAsset.sol";
import "./LPToken.sol";
import "./WLPToken.sol";
import "./misc/ConstantExchangeRateProvider.sol";
import "./misc/ERC4626ExchangeRate.sol";
import "./misc/OracleExchangeRate.sol";
import "./interfaces/IExchangeRateProvider.sol";

/**
 * @title SelfPeggingAsset Application
 * @author Nuts Finance Developer
 * @notice The StableSwap Application provides an interface for users to interact with StableSwap pool contracts
 * @dev The StableSwap Application contract allows users to mint pool tokens, swap between different tokens, and redeem
 * pool tokens to underlying tokens.
 * This contract should never store assets.
 */
contract SelfPeggingAssetFactory is UUPSUpgradeable, OwnableUpgradeable {
    /// @notice Token type enum
    enum TokenType {
        Standard,
        Oracle,
        Rebasing,
        ERC4626
    }

    /// @notice Parameters for creating a new pool
    struct CreatePoolArgument {
        /// @notice Address of token A
        address tokenA;
        /// @notice Address of token B
        address tokenB;
        /// @notice Type of token A
        TokenType tokenAType;
        /// @notice Address of the oracle for token A
        address tokenAOracle;
        /// @notice Rate function signature for token A
        bytes tokenARateFunctionSig;
        /// @notice Decimals function signature for token A
        bytes tokenADecimalsFunctionSig;
        /// @notice Type of token B
        TokenType tokenBType;
        /// @notice Address of the oracle for token B
        address tokenBOracle;
        /// @notice Rate function signature for token B
        bytes tokenBRateFunctionSig;
        /// @notice Decimals function signature for token B
        bytes tokenBDecimalsFunctionSig;
    }

    /**
     * @dev This is the account that has governor control over the protocol.
     */
    address public governor;

    /**
     * @dev Default mint fee for the pool.
     */
    uint256 public mintFee;

    /**
     * @dev Default swap fee for the pool.
     */
    uint256 public swapFee;

    /**
     * @dev Default redeem fee for the pool.
     */
    uint256 public redeemFee;

    /**
     * @dev Default off peg fee multiplier for the pool.
     */
    uint256 public offPegFeeMultiplier;

    /**
     * @dev Default A parameter for the pool.
     */
    uint256 public A;

    /**
     * @dev Beacon for the SelfPeggingAsset implementation.
     */
    address public selfPeggingAssetBeacon;

    /**
     * @dev Beacon for the LPToken implementation.
     */
    address public lpTokenBeacon;

    /**
     * @dev Beacon for the WLPToken implementation.
     */
    address public wlpTokenBeacon;

    /**
     * @dev Constant exchange rate provider.
     */
    ConstantExchangeRateProvider public constantExchangeRateProvider;

    /**
     * @dev This event is emitted when the governor is modified.
     * @param governor is the new value of the governor.
     */
    event GovernorModified(address governor);

    /**
     * @dev This event is emitted when a new pool is created.
     * @param poolToken is the pool token created.
     */
    event PoolCreated(address poolToken, address selfPeggingAsset, address wrappedPoolToken);

    /**
     * @dev This event is emitted when the mint fee is updated.
     * @param mintFee is the new value of the mint fee.
     */
    event MintFeeModified(uint256 mintFee);

    /**
     * @dev This event is emitted when the swap fee is updated.
     * @param swapFee is the new value of the swap fee.
     */
    event SwapFeeModified(uint256 swapFee);

    /**
     * @dev This event is emitted when the redeem fee is updated.
     * @param redeemFee is the new value of the redeem fee.
     */
    event RedeemFeeModified(uint256 redeemFee);

    /**
     * @dev This event is emitted when the off peg fee multiplier is updated.
     * @param offPegFeeMultiplier is the new value of the off peg fee multiplier.
     */
    event OffPegFeeMultiplierModified(uint256 offPegFeeMultiplier);

    /**
     * @dev This event is emitted when the A parameter is updated.
     * @param A is the new value of the A parameter.
     */
    event AModified(uint256 A);

    /// @dev Error thrown when the address is invalid
    error InvalidAddress();

    /// @dev Error thrown when the value is invalid
    error InvalidValue();

    /// @dev Error thrown when the oracle is invalid
    error InvalidOracle();

    /// @dev Error thrown when the function signature is invalid
    error InvalidFunctionSig();

    /**
     * @dev Initializes the StableSwap Application contract.
     */
    function initialize(
        address _governor,
        uint256 _mintFee,
        uint256 _swapFee,
        uint256 _redeemFee,
        uint256 _offPegFeeMultiplier,
        uint256 _A,
        address _selfPeggingAssetBeacon,
        address _lpTokenBeacon,
        address _wlpTokenBeacon,
        ConstantExchangeRateProvider _constantExchangeRateProvider
    )
        public
        initializer
    {
        require(_governor != address(0), InvalidAddress());
        require(_A > 0, InvalidValue());
        require(_selfPeggingAssetBeacon != address(0), InvalidAddress());
        require(_lpTokenBeacon != address(0), InvalidAddress());
        require(_wlpTokenBeacon != address(0), InvalidAddress());
        require(address(_constantExchangeRateProvider) != address(0), InvalidAddress());

        __Ownable_init(msg.sender);

        governor = _governor;

        selfPeggingAssetBeacon = _selfPeggingAssetBeacon;
        lpTokenBeacon = _lpTokenBeacon;
        wlpTokenBeacon = _wlpTokenBeacon;
        constantExchangeRateProvider = _constantExchangeRateProvider;

        mintFee = _mintFee;
        swapFee = _swapFee;
        redeemFee = _redeemFee;
        A = _A;
        offPegFeeMultiplier = _offPegFeeMultiplier;
    }

    /**
     * @dev Set the govenance address.
     */
    function setGovernor(address _governor) external onlyOwner {
        require(_governor != address(0), InvalidAddress());
        governor = _governor;
        emit GovernorModified(governor);
    }

    /**
     * @dev Set the mint fee.
     */
    function setMintFee(uint256 _mintFee) external onlyOwner {
        mintFee = _mintFee;
        emit MintFeeModified(_mintFee);
    }

    /**
     * @dev Set the swap fee.
     */
    function setSwapFee(uint256 _swapFee) external onlyOwner {
        swapFee = _swapFee;
        emit SwapFeeModified(_swapFee);
    }

    /**
     * @dev Set the redeem fee.
     */
    function setRedeemFee(uint256 _redeemFee) external onlyOwner {
        redeemFee = _redeemFee;
        emit RedeemFeeModified(_redeemFee);
    }

    /**
     * @dev Set the off peg fee multiplier.
     */
    function setOffPegFeeMultiplier(uint256 _offPegFeeMultiplier) external onlyOwner {
        offPegFeeMultiplier = _offPegFeeMultiplier;
        emit OffPegFeeMultiplierModified(_offPegFeeMultiplier);
    }

    /**
     * @dev Set the A parameter.
     */
    function setA(uint256 _A) external onlyOwner {
        require(_A > 0, InvalidValue());
        A = _A;
        emit AModified(_A);
    }

    /**
     * @dev Create a new pool.
     */
    function createPool(CreatePoolArgument memory argument) external {
        require(argument.tokenA != address(0), InvalidAddress());
        require(argument.tokenB != address(0), InvalidAddress());
        require(argument.tokenA != argument.tokenB, InvalidValue());

        string memory symbolA = ERC20Upgradeable(argument.tokenA).symbol();
        string memory symbolB = ERC20Upgradeable(argument.tokenB).symbol();
        string memory symbol = string.concat(string.concat(string.concat("SPA-", symbolA), "-"), symbolB);
        string memory name = string.concat(string.concat(string.concat("Self Pegging Asset ", symbolA), " "), symbolB);
        bytes memory lpTokenInit = abi.encodeCall(LPToken.initialize, (name, symbol));
        BeaconProxy lpTokenProxy = new BeaconProxy(lpTokenBeacon, lpTokenInit);

        address[] memory tokens = new address[](2);
        uint256[] memory precisions = new uint256[](2);
        uint256[] memory fees = new uint256[](3);
        tokens[0] = argument.tokenA;
        tokens[1] = argument.tokenB;
        precisions[0] = 10 ** (18 - ERC20Upgradeable(argument.tokenA).decimals());
        precisions[1] = 10 ** (18 - ERC20Upgradeable(argument.tokenB).decimals());
        fees[0] = mintFee;
        fees[1] = swapFee;
        fees[2] = redeemFee;

        IExchangeRateProvider[] memory exchangeRateProviders = new IExchangeRateProvider[](2);

        if (argument.tokenAType == TokenType.Standard || argument.tokenAType == TokenType.Rebasing) {
            exchangeRateProviders[0] = IExchangeRateProvider(constantExchangeRateProvider);
        } else if (argument.tokenAType == TokenType.Oracle) {
            require(argument.tokenAOracle != address(0), InvalidOracle());
            require(bytes(argument.tokenARateFunctionSig).length > 0, InvalidFunctionSig());
            require(bytes(argument.tokenADecimalsFunctionSig).length > 0, InvalidFunctionSig());
            OracleExchangeRate oracleExchangeRate = new OracleExchangeRate(
                argument.tokenAOracle, argument.tokenARateFunctionSig, argument.tokenADecimalsFunctionSig
            );
            exchangeRateProviders[0] = IExchangeRateProvider(oracleExchangeRate);
        } else if (argument.tokenAType == TokenType.ERC4626) {
            ERC4626ExchangeRate erc4626ExchangeRate = new ERC4626ExchangeRate(IERC4626(argument.tokenA));
            exchangeRateProviders[0] = IExchangeRateProvider(erc4626ExchangeRate);
        }

        if (argument.tokenBType == TokenType.Standard || argument.tokenBType == TokenType.Rebasing) {
            exchangeRateProviders[1] = IExchangeRateProvider(constantExchangeRateProvider);
        } else if (argument.tokenBType == TokenType.Oracle) {
            require(argument.tokenBOracle != address(0), InvalidOracle());
            require(bytes(argument.tokenBRateFunctionSig).length > 0, InvalidFunctionSig());
            require(bytes(argument.tokenBDecimalsFunctionSig).length > 0, InvalidFunctionSig());
            OracleExchangeRate oracleExchangeRate = new OracleExchangeRate(
                argument.tokenBOracle, argument.tokenBRateFunctionSig, argument.tokenBDecimalsFunctionSig
            );
            exchangeRateProviders[1] = IExchangeRateProvider(oracleExchangeRate);
        } else if (argument.tokenBType == TokenType.ERC4626) {
            ERC4626ExchangeRate erc4626ExchangeRate = new ERC4626ExchangeRate(IERC4626(argument.tokenB));
            exchangeRateProviders[1] = IExchangeRateProvider(erc4626ExchangeRate);
        }

        bytes memory selfPeggingAssetInit = abi.encodeCall(
            SelfPeggingAsset.initialize,
            (tokens, precisions, fees, offPegFeeMultiplier, LPToken(address(lpTokenProxy)), A, exchangeRateProviders)
        );
        BeaconProxy selfPeggingAssetProxy = new BeaconProxy(selfPeggingAssetBeacon, selfPeggingAssetInit);
        SelfPeggingAsset selfPeggingAsset = SelfPeggingAsset(address(selfPeggingAssetProxy));
        LPToken lpToken = LPToken(address(lpTokenProxy));

        selfPeggingAsset.setAdmin(governor, true);
        selfPeggingAsset.transferOwnership(governor);
        lpToken.addPool(address(selfPeggingAsset));
        lpToken.transferOwnership(governor);

        bytes memory wlpTokenInit = abi.encodeCall(WLPToken.initialize, (ILPToken(lpToken)));
        BeaconProxy wlpTokenProxy = new BeaconProxy(wlpTokenBeacon, wlpTokenInit);

        emit PoolCreated(address(lpTokenProxy), address(selfPeggingAssetProxy), address(wlpTokenProxy));
    }

    /**
     * @dev Authorisation to upgrade the implementation of the contract.
     */
    function _authorizeUpgrade(address) internal override onlyOwner { }
}
