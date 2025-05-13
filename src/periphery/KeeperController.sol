// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import {SelfPeggingAsset} from "../SelfPeggingAsset.sol";
import {IRampAController} from "../interfaces/IRampAController.sol";


/*
 _   __                            _____             _             _ _           
| | / /                           /  __ \           | |           | | |          
| |/ /  ___  ___ _ __   ___ _ __  | /  \/ ___  _ __ | |_ _ __ ___ | | | ___ _ __ 
|    \ / _ \/ _ \ '_ \ / _ \ '__| | |    / _ \| '_ \| __| '__/ _ \| | |/ _ \ '__|
| |\  \  __/  __/ |_) |  __/ |    | \__/\ (_) | | | | |_| | | (_) | | |  __/ |   
\_| \_/\___|\___| .__/ \___|_|     \____/\___/|_| |_|\__|_|  \___/|_|_|\___|_|   
                | |                                                              
                |_|            
*/

/// @title KeeperController
/// @notice Factory/Governance bootstraps; Keepers tune A & fees.
contract KeeperController is AccessControl {
    
       
    //   ____            _              
    //  |  _ \    ___   | |   ___   ___ 
    //  | |_) |  / _ \  | |  / _ \ / __|
    //  |  _ <  | (_) | | | |  __/ \__ \
    //  |_| \_\  \___/  |_|  \___| |___/

    
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant FACTORY_ROLE    = keccak256("FACTORY_ROLE");
    bytes32 public constant KEEPER_ROLE     = keccak256("KEEPER_ROLE");
    
    
    //   ____    _             _             __     __                 _           _       _              
    //  / ___|  | |_    __ _  | |_    ___    \ \   / /   __ _   _ __  (_)   __ _  | |__   | |   ___   ___ 
    //  \___ \  | __|  / _` | | __|  / _ \    \ \ / /   / _` | | '__| | |  / _` | | '_ \  | |  / _ \ / __|
    //   ___) | | |_  | (_| | | |_  |  __/     \ V /   | (_| | | |    | | | (_| | | |_) | | | |  __/ \__ \
    //  |____/   \__|  \__,_|  \__|  \___|      \_/     \__,_| |_|    |_|  \__,_| |_.__/  |_|  \___| |___/
    
    /// @dev This is the denominator used for calculating transaction fees in the SelfPeggingAsset contract.
    uint256 private constant FEE_DENOMINATOR = 10 ** 10;

    address public factory;
    address public rampAController;
    address public spa;

    uint256 public swapFeeMin;
    uint256 public swapFeeMax;
    


    //  _____                _       
    // |  ___|              | |      
    // | |____   _____ _ __ | |_ ___ 
    // |  __\ \ / / _ \ '_ \| __/ __|
    // | |___\ V /  __/ | | | |_\__ \
    // \____/ \_/ \___|_| |_|\__|___/
                              
                            
    event SpaAddressSet(address indexed spa);
    event ControllerSet(address indexed controller);    
    event SwapFeeCapUpdated(uint256 swapFeeCapMin, uint256 swapFeeCapMax);

    // ___  ___          _ _  __ _               
    // |  \/  |         | (_)/ _(_)              
    // | .  . | ___   __| |_| |_ _  ___ _ __ ___ 
    // | |\/| |/ _ \ / _` | |  _| |/ _ \ '__/ __|
    // | |  | | (_) | (_| | | | | |  __/ |  \__ \
    // \_|  |_/\___/ \__,_|_|_| |_|\___|_|  |___/
          
    modifier onlyFactoryOrGov() {
        require(
            hasRole(FACTORY_ROLE, msg.sender) ||
            hasRole(GOVERNANCE_ROLE, msg.sender),
            "Not factory or governance"
        );
        _;
    }

    // custom errors
    
    /// @notice Error thrown when the caps limits are reached when setter fee params
    error CapExceeded();
    /// @notice Error thrown when the cap is under the value
    error CapUnderValue();
    /// @notice Error thrown when the cap is over the value
    error CapOverValue();
    /// @notice Error thrown when the limit is exceeded. 
    error LimitExceeded();


    constructor(address _governance, address _factory) {
        _grantRole(DEFAULT_ADMIN_ROLE, _governance);
        _grantRole(GOVERNANCE_ROLE,   _governance);

        factory = _factory;
        _grantRole(FACTORY_ROLE, _factory);

        // Governance administers all roles
        _setRoleAdmin(FACTORY_ROLE, GOVERNANCE_ROLE);
        _setRoleAdmin(KEEPER_ROLE,  GOVERNANCE_ROLE);
    }

    //  ___         _                               _     __  __         _     _               _      
    // | __| __ __ | |_   ___   _ _   _ _    __ _  | |   |  \/  |  ___  | |_  | |_    ___   __| |  ___
    // | _|  \ \ / |  _| / -_) | '_| | ' \  / _` | | |   | |\/| | / -_) |  _| | ' \  / _ \ / _` | (_-<
    // |___| /_\_\  \__| \___| |_|   |_||_| \__,_| |_|   |_|  |_| \___|  \__| |_||_| \___/ \__,_| /__/
                                                                                                   
    
    /// @notice Point at the SPA instance.
    function setSpa(address _spa) external onlyFactoryOrGov {
        spa = _spa;
        emit SpaAddressSet(_spa);
    }

    /// @notice Point at the ramp‑A controller.
    function setRampAController(address _controller)
        external onlyFactoryOrGov
    {
        rampAController = _controller;
        emit ControllerSet(_controller);
    }

    /// @notice Adds a new keeper
    /// @param _keeper Address to be authorized as keeper
    /// @param authorized True if the keeper should be authorized
    function setKeeper(address _keeper,bool authorized) external onlyRole(GOVERNANCE_ROLE) {
        if (authorized) {
            _grantRole(KEEPER_ROLE, _keeper);
        } else {
            _revokeRole(KEEPER_ROLE, _keeper);
        }        
        
    }

    function setSwapFeeCap(uint256 _swapFeeMin, uint256 _swapFeeMax) external onlyRole(GOVERNANCE_ROLE) {
        require(_swapFeeMin < FEE_DENOMINATOR, LimitExceeded());
        require(_swapFeeMax < FEE_DENOMINATOR, LimitExceeded());

        swapFeeMin = _swapFeeMin;
        swapFeeMax = _swapFeeMax;
        emit SwapFeeCapUpdated(_swapFeeMin, _swapFeeMax);
    }


    function isKeeper(address _keeper) public view returns (bool) {
        return hasRole(KEEPER_ROLE, _keeper);
    }

    /// @notice Calls rampA on the external controller contract
    /// @param newA New value of the A parameter
    /// @param futureTime Timestamp when the new A should take effect
    function rampA(uint256 newA, uint256 futureTime)
        external onlyRole(KEEPER_ROLE)
    {
        IRampAController(rampAController).rampA(newA, futureTime);
    }

    function setSwapFee(uint256 _swapFee) external onlyRole(KEEPER_ROLE) {
        require(_swapFee>swapFeeMax,CapOverValue());
        require(_swapFee<swapFeeMin,CapUnderValue());
        SelfPeggingAsset(spa).setSwapFee(_swapFee);
    }

}

