// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Disperse} from "../src/Disperse.sol";

/**
 * @title DeployCreate2
 * @notice Deploy Disperse contract using CREATE2 for deterministic addresses across chains
 * @dev Uses a deterministic deployer factory (like Create2Deployer or Arachnid's deterministic deployer)
 * 
 * Prerequisites:
 * 1. The CREATE2 factory must be deployed at the same address on all target chains
 * 2. Use the same salt on all chains
 * 3. The contract bytecode must be identical (same compiler version and settings)
 * 
 * Recommended CREATE2 Factories (deployed at same address on most EVM chains):
 * - Arachnid's Deterministic Deployment Proxy: 0x4e59b44847b379578588920cA78FbF26c0B4956C
 * - Create2Deployer: 0x13b0D85CcB8bf860b6b79AF3029fCA081AE9beF2
 * 
 * Usage:
 *   forge script script/DeployCreate2.s.sol:DeployCreate2 \
 *     --rpc-url $RPC_URL \
 *     --account $DEPLOYER \
 *     --sender $DEPLOYER_ADDRESS \
 *     --broadcast \
 *     -vvvv
 */

/// @notice Arachnid's Deterministic Deployment Proxy interface
/// @dev Deployed at 0x4e59b44847b379578588920cA78FbF26c0B4956C on most chains
interface IDeterministicDeploymentProxy {
    // This proxy uses raw call data: salt (32 bytes) + bytecode
    // No function interface, just send: abi.encodePacked(salt, bytecode)
}

/// @notice Create2Deployer interface (alternative factory)
interface ICreate2Deployer {
    function deploy(uint256 value, bytes32 salt, bytes memory code) external returns (address);
    function computeAddress(bytes32 salt, bytes32 codeHash) external view returns (address);
}

contract DeployCreate2 is Script {
    // Arachnid's Deterministic Deployment Proxy - deployed on most EVM chains
    address constant DETERMINISTIC_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    
    // Alternative: Create2Deployer factory
    address constant CREATE2_DEPLOYER = 0x13b0D85CcB8bf860b6b79AF3029fCA081AE9beF2;

    // Salt for deterministic deployment - CHANGE THIS to get different addresses
    // Using a descriptive salt helps identify the deployment
    bytes32 constant SALT = keccak256("rockx.disperse.v1");

    function run() external returns (address) {
        // Get the creation bytecode of Disperse
        bytes memory bytecode = type(Disperse).creationCode;
        
        // Compute the expected address before deployment
        address expectedAddress = computeCreate2Address(DETERMINISTIC_DEPLOYER, SALT, bytecode);
        console.log("Expected Disperse address:", expectedAddress);
        console.log("Salt:", vm.toString(SALT));
        console.log("Bytecode hash:", vm.toString(keccak256(bytecode)));

        // Check if already deployed
        if (expectedAddress.code.length > 0) {
            console.log("Contract already deployed at this address!");
            return expectedAddress;
        }

        vm.startBroadcast();

        // Deploy using Arachnid's Deterministic Deployment Proxy
        // The proxy expects: salt (32 bytes) + bytecode
        bytes memory data = abi.encodePacked(SALT, bytecode);
        
        (bool success, ) = DETERMINISTIC_DEPLOYER.call(data);
        require(success, "CREATE2 deployment failed");

        vm.stopBroadcast();

        // Verify deployment
        require(expectedAddress.code.length > 0, "Deployment verification failed");
        console.log("Disperse deployed at:", expectedAddress);

        return expectedAddress;
    }

    /// @notice Compute CREATE2 address
    /// @param deployer The CREATE2 factory address
    /// @param salt The salt value
    /// @param bytecode The contract creation bytecode
    function computeCreate2Address(
        address deployer,
        bytes32 salt,
        bytes memory bytecode
    ) public pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            deployer,
            salt,
            keccak256(bytecode)
        )))));
    }

    /// @notice Preview the deployment address without actually deploying
    function preview() external view {
        bytes memory bytecode = type(Disperse).creationCode;
        address expectedAddress = computeCreate2Address(DETERMINISTIC_DEPLOYER, SALT, bytecode);
        
        console.log("=== CREATE2 Deployment Preview ===");
        console.log("Factory:", DETERMINISTIC_DEPLOYER);
        console.log("Salt:", vm.toString(SALT));
        console.log("Bytecode length:", bytecode.length);
        console.log("Bytecode hash:", vm.toString(keccak256(bytecode)));
        console.log("Expected address:", expectedAddress);
        console.log("");
        console.log("Already deployed:", expectedAddress.code.length > 0);
    }
}

/// @notice Alternative deployment script using Create2Deployer factory
contract DeployCreate2Alt is Script {
    address constant CREATE2_DEPLOYER = 0x13b0D85CcB8bf860b6b79AF3029fCA081AE9beF2;
    bytes32 constant SALT = keccak256("rockx.disperse.v1");

    function run() external returns (address) {
        bytes memory bytecode = type(Disperse).creationCode;
        bytes32 bytecodeHash = keccak256(bytecode);
        
        ICreate2Deployer factory = ICreate2Deployer(CREATE2_DEPLOYER);
        address expectedAddress = factory.computeAddress(SALT, bytecodeHash);
        
        console.log("Expected Disperse address:", expectedAddress);

        if (expectedAddress.code.length > 0) {
            console.log("Contract already deployed!");
            return expectedAddress;
        }

        vm.startBroadcast();
        address deployed = factory.deploy(0, SALT, bytecode);
        vm.stopBroadcast();

        require(deployed == expectedAddress, "Address mismatch");
        console.log("Disperse deployed at:", deployed);

        return deployed;
    }
}
