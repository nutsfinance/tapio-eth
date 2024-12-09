// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";

import "./StableAsset.sol";
import "./TapETH.sol";
import "./misc/ConstantExchangeRateProvider.sol";
import "./misc/ERC4626ExchangeRate.sol";
import "./interfaces/IExchangeRateProvider.sol";

/**
 * @title StableAsset Application
 * @author Nuts Finance Developer
 * @notice The StableSwap Application provides an interface for users to interact with StableSwap pool contracts
 * @dev The StableSwap Application contract allows users to mint pool tokens, swap between different tokens, and redeem
 * pool tokens to underlying tokens.
 * This contract should never store assets.
 */
contract StableAssetFactory is Initializable, ReentrancyGuardUpgradeable {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct CreatePoolArgument {
        address tokenA;
        address tokenB;
        uint256 precisionA;
        uint256 precisionB;
        uint256 mintFee;
        uint256 swapFee;
        uint256 redeemFee;
        uint256 A;
    }

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
     * @dev This event is emitted when a new pool is created.
     * @param poolToken is the pool token created.
     */
    event PoolCreated(address proxyAdmin, address poolToken, address stableAsset);

    /**
     * @dev This is the account that has governance control over the StableAssetApplication contract.
     */
    address public governance;

    /**
     * @dev Pending governance address,
     */
    address public pendingGovernance;

    address public stableAssetImplentation;
    address public tapETHImplentation;
    ConstantExchangeRateProvider public constantExchangeRateProvider;

    /**
     * @dev Initializes the StableSwap Application contract.
     */
    function initialize(address _stableAssetImplentation, address _tapETHImplentation) public initializer {
        __ReentrancyGuard_init();
        governance = msg.sender;
        stableAssetImplentation = _stableAssetImplentation;
        tapETHImplentation = _tapETHImplentation;
        constantExchangeRateProvider = new ConstantExchangeRateProvider();
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

    function createPool(CreatePoolArgument memory argument, IExchangeRateProvider exchangeRateProvider) internal {
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        proxyAdmin.transferOwnership(msg.sender);

        string memory symbolA = ERC20Upgradeable(argument.tokenA).symbol();
        string memory symbolB = ERC20Upgradeable(argument.tokenB).symbol();
        string memory symbol = string.concat(string.concat(string.concat("SA-", symbolA), "-"), symbolB);
        string memory name = string.concat(string.concat(string.concat("Stable Asset ", symbolA), " "), symbolB);
        bytes memory tapETHInit = abi.encodeCall(TapETH.initialize, (address(this), name, symbol));
        TransparentUpgradeableProxy tapETHProxy =
            new TransparentUpgradeableProxy(address(tapETHImplentation), address(proxyAdmin), tapETHInit);

        address[] memory tokens = new address[](2);
        uint256[] memory precisions = new uint256[](2);
        uint256[] memory fees = new uint256[](3);
        tokens[0] = argument.tokenA;
        tokens[1] = argument.tokenB;
        precisions[0] = argument.precisionA;
        precisions[1] = argument.precisionB;
        fees[0] = argument.mintFee;
        fees[1] = argument.swapFee;
        fees[2] = argument.redeemFee;
        uint256 A = argument.A;
        uint256 exchangeRateTokenIndex = 1;

        bytes memory stableAssetInit = abi.encodeCall(
            StableAsset.initialize,
            (tokens, precisions, fees, TapETH(address(tapETHProxy)), A, exchangeRateProvider, exchangeRateTokenIndex)
        );
        TransparentUpgradeableProxy stableAssetProxy =
            new TransparentUpgradeableProxy(address(stableAssetImplentation), address(proxyAdmin), stableAssetInit);
        StableAsset stableAsset = StableAsset(address(stableAssetProxy));
        TapETH tapETH = TapETH(address(tapETHProxy));

        stableAsset.proposeGovernance(msg.sender);
        tapETH.addPool(address(stableAsset));
        tapETH.proposeGovernance(msg.sender);
        emit PoolCreated(address(proxyAdmin), address(tapETHProxy), address(stableAssetProxy));
    }

    function createPoolConstantExchangeRate(CreatePoolArgument calldata argument) public {
        createPool(argument, constantExchangeRateProvider);
    }

    function createPoolERC4626(CreatePoolArgument calldata argument) public {
        ERC4626ExchangeRate exchangeRate = new ERC4626ExchangeRate(IERC4626(argument.tokenB));
        createPool(argument, exchangeRate);
    }
}
