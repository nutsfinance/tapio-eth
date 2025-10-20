// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

/**
 * @title CreateXDeployer
 * @notice Helper for deterministic deployments using CreateX contract across chains.
 * @dev Inherit this contract in your Foundry scripts to deploy with CREATE2 deterministically.
 */
interface ICreateX {
    function deployCreate2(bytes32 salt, bytes memory initCode) external payable returns (address newContract);

    function deployCreate2(bytes memory initCode) external payable returns (address newContract);

    function deployCreate2AndInit(
        bytes32 salt,
        bytes memory initCode,
        bytes memory data,
        Values memory values,
        address refundAddress
    )
        external
        payable
        returns (address newContract);

    function deployCreate2Clone(bytes32 salt, address implementation, bytes memory data)
        external
        payable
        returns (address proxy);

    function computeCreate2Address(bytes32 salt, bytes32 initCodeHash) external view returns (address computedAddress);
}

struct Values {
    uint256 constructorAmount;
    uint256 initCallAmount;
}

abstract contract CreateXDeployer is Script {
    address public constant CREATE_X = 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed;

    ICreateX internal createx = ICreateX(CREATE_X);

    function deployCreate2(bytes32 salt, bytes memory initCode) internal returns (address deployed) {
        deployed = createx.deployCreate2(salt, initCode);
        console.log("Deployed (CREATE2):", deployed);
    }

    function deployCreate2(bytes memory initCode) internal returns (address deployed) {
        deployed = createx.deployCreate2(initCode);
        console.log("Deployed (CREATE2 - random salt):", deployed);
    }

    function deployCreate2AndInit(
        bytes32 salt,
        bytes memory initCode,
        bytes memory initData,
        Values memory values,
        address refundAddress
    )
        internal
        returns (address deployed)
    {
        deployed = createx.deployCreate2AndInit(salt, initCode, initData, values, refundAddress);
        console.log("Deployed + initialized:", deployed);
    }

    function deployCreate2Clone(bytes32 salt, address implementation, bytes memory initData)
        internal
        returns (address clone)
    {
        clone = createx.deployCreate2Clone(salt, implementation, initData);
        console.log("Deployed minimal proxy (clone):", clone);
    }

    // function computeCreate2Address(bytes32 salt, bytes32 initCodeHash)
    // internal
    // view
    // returns (address)
    //{
    // return createx.computeCreate2Address(salt, initCodeHash);
    //}
}
