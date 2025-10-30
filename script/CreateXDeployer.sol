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
    function deployCreate3(bytes32 salt, bytes memory initCode) external payable returns (address newContract);

    function deployCreate3AndInit(
        bytes32 salt,
        bytes memory initCode,
        bytes memory data,
        Values memory values
    )
        external
        payable
        returns (address newContract);

    function computeCreate3Address(
        bytes32 salt,
        address deployer
    )
        external
        pure
        returns (address computedAddress);

    function computeCreate3Address(bytes32 salt) external view returns (address computedAddress);
}

struct Values {
    uint256 constructorAmount;
    uint256 initCallAmount;
}

abstract contract CreateXDeployer is Script {
    address public constant CREATEX = 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed;

    ICreateX internal createx = ICreateX(CREATEX);

    function generateSalt(address deployer, string memory identifier) internal pure returns (bytes32 salt) {
        bytes32 identifierHash = keccak256(abi.encodePacked(identifier));
        bytes11 entropy = bytes11(identifierHash);

        salt = bytes32(
            abi.encodePacked(
                deployer, // wallet address
                hex"01", // cross-chain
                entropy // unique identifier
            )
        );
    }

    function computeCreate3Address(bytes32 salt, address deployer) internal view returns (address predicted) {
        bytes32 guardedSalt = keccak256(abi.encode(deployer, block.chainid, salt));
        predicted = createx.computeCreate3Address(guardedSalt, CREATEX);
    }

    function deployCreate3(
        bytes32 salt,
        bytes memory initCode,
        string memory identifier
    )
        internal
        returns (address deployed)
    {
        console.log("Identifier:", identifier);
        console.log("Salt:", vm.toString(salt));

        address expected = computeCreate3Address(salt, msg.sender);
        console.log("Expected address:", expected);

        if (expected.code.length > 0) return expected;

        deployed = createx.deployCreate3(salt, initCode);

        require(deployed != address(0), "CreateX: Deployment failed");
        require(deployed.code.length > 0, "CreateX: No code at address");
        require(deployed == expected, "CreateX: Address mismatch");

        console.log("Deployed to:", deployed);
    }

    function deployCreate3AndInit(
        bytes32 salt,
        bytes memory initCode,
        bytes memory initData,
        string memory identifier
    )
        internal
        returns (address deployed)
    {
        console.log("Identifier:", identifier);
        console.log("Salt:", vm.toString(salt));
        address expected = computeCreate3Address(salt, msg.sender);
        console.log("Expected address:", expected);

        if (expected.code.length > 0) return expected;

        Values memory values = Values({ constructorAmount: 0, initCallAmount: 0 });
        deployed = createx.deployCreate3AndInit(salt, initCode, initData, values);

        require(deployed != address(0), "CreateX: Deployment failed");
        require(deployed.code.length > 0, "CreateX: No code at address");
        require(deployed == expected, "CreateX: Address mismatch");

        console.log("Deployed to:", deployed);
    }

    function verifyCreateX() internal view {
        require(CREATEX.code.length > 0, "CreateX not deployed on this chain");
        console.log("CreateX verified at:", CREATEX);
    }
}
