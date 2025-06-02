// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { TimelockControllerUpgradeable } from
    "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";

/**
 * @title Tapio Timelock Contract
 * @author NUTS Finance (hello@pike.finance)
 */
contract Timelock is TimelockControllerUpgradeable {
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the contract
     * @param admin Address of timelock contract admin
     * @param protocolOwner Address of the protocol owner
     * @param minDelay minDelay of queue period
     * @param proposers array of proposers that are able to schedule an action
     * @param executors array of executes that are able to execute an action
     */
    function initialize(
        address admin,
        address protocolOwner,
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors
    )
        public
        initializer
    {
        __TimelockController_init(minDelay, proposers, executors, admin);
        _grantRole(CANCELLER_ROLE, protocolOwner);
    }
}
