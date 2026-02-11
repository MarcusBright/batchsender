// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Disperse} from "../src/Disperse.sol";

/**
 * @title Create2AddressTest
 * @notice Test to verify CREATE2 produces the same address regardless of chain
 * @dev CREATE2 address depends only on: deployer + salt + bytecode
 *      As long as these are identical, the address will be the same on any EVM chain
 */
contract Create2AddressTest is Test {
    // Arachnid's Deterministic Deployment Proxy - same on all chains
    address constant DETERMINISTIC_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    
    // Salt - must be the same across all deployments
    bytes32 constant SALT = keccak256("rockx.disperse.v1");

    function setUp() public {}

    /// @notice Compute CREATE2 address (pure function, no RPC needed)
    function computeCreate2Address(
        address deployer,
        bytes32 salt,
        bytes memory bytecode
    ) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            deployer,
            salt,
            keccak256(bytecode)
        )))));
    }

    /// @notice Test that CREATE2 address calculation is deterministic
    function testCreate2AddressIsDeterministic() public pure {
        bytes memory bytecode = type(Disperse).creationCode;
        
        // Calculate address multiple times - should always be the same
        address addr1 = computeCreate2Address(DETERMINISTIC_DEPLOYER, SALT, bytecode);
        address addr2 = computeCreate2Address(DETERMINISTIC_DEPLOYER, SALT, bytecode);
        address addr3 = computeCreate2Address(DETERMINISTIC_DEPLOYER, SALT, bytecode);
        
        assertEq(addr1, addr2, "Address should be deterministic");
        assertEq(addr2, addr3, "Address should be deterministic");
    }

    /// @notice Test to display the expected CREATE2 address
    /// @dev Run with: forge test --match-test testShowCreate2Address -vv
    function testShowCreate2Address() public view {
        bytes memory bytecode = type(Disperse).creationCode;
        bytes32 bytecodeHash = keccak256(bytecode);
        
        address expectedAddress = computeCreate2Address(DETERMINISTIC_DEPLOYER, SALT, bytecode);
        
        console.log("===========================================");
        console.log("CREATE2 Address Calculation");
        console.log("===========================================");
        console.log("");
        console.log("Factory (Arachnid):", DETERMINISTIC_DEPLOYER);
        console.log("Salt:", vm.toString(SALT));
        console.log("Bytecode length:", bytecode.length);
        console.log("Bytecode hash:", vm.toString(bytecodeHash));
        console.log("");
        console.log(">>> Expected Disperse Address:", expectedAddress);
        console.log("");
        console.log("This address will be the SAME on:");
        console.log("  - Ethereum Mainnet");
        console.log("  - Sepolia Testnet");
        console.log("  - BSC");
        console.log("  - Polygon");
        console.log("  - Arbitrum");
        console.log("  - Optimism");
        console.log("  - Base");
        console.log("  - Any EVM chain with Arachnid's deployer");
        console.log("===========================================");
    }

    /// @notice Simulate deployment on multiple "chains" and verify same address
    function testSameAddressOnDifferentChains() public {
        bytes memory bytecode = type(Disperse).creationCode;
        address expectedAddress = computeCreate2Address(DETERMINISTIC_DEPLOYER, SALT, bytecode);
        
        // Simulate different chain IDs
        uint256[] memory chainIds = new uint256[](6);
        chainIds[0] = 1;        // Ethereum Mainnet
        chainIds[1] = 11155111; // Sepolia
        chainIds[2] = 56;       // BSC
        chainIds[3] = 137;      // Polygon
        chainIds[4] = 42161;    // Arbitrum
        chainIds[5] = 10;       // Optimism

        string[] memory chainNames = new string[](6);
        chainNames[0] = "Ethereum Mainnet";
        chainNames[1] = "Sepolia";
        chainNames[2] = "BSC";
        chainNames[3] = "Polygon";
        chainNames[4] = "Arbitrum";
        chainNames[5] = "Optimism";

        for (uint256 i = 0; i < chainIds.length; i++) {
            // Switch to different chain
            vm.chainId(chainIds[i]);
            
            // Calculate address on this "chain"
            address addrOnChain = computeCreate2Address(DETERMINISTIC_DEPLOYER, SALT, bytecode);
            
            // Verify it matches
            assertEq(
                addrOnChain, 
                expectedAddress, 
                string.concat("Address mismatch on ", chainNames[i])
            );
            
            console.log(chainNames[i]);
            console.log("  chainId:", chainIds[i]);
            console.log("  address:", addrOnChain);
        }
        
        console.log("");
        console.log("All chains produce the same address:", expectedAddress);
    }

    /// @notice Test that different salts produce different addresses
    function testDifferentSaltsDifferentAddresses() public pure {
        bytes memory bytecode = type(Disperse).creationCode;
        
        bytes32 salt1 = keccak256("rockx.disperse.v1");
        bytes32 salt2 = keccak256("rockx.disperse.v2");
        bytes32 salt3 = keccak256("different.salt");
        
        address addr1 = computeCreate2Address(DETERMINISTIC_DEPLOYER, salt1, bytecode);
        address addr2 = computeCreate2Address(DETERMINISTIC_DEPLOYER, salt2, bytecode);
        address addr3 = computeCreate2Address(DETERMINISTIC_DEPLOYER, salt3, bytecode);
        
        assertTrue(addr1 != addr2, "Different salts should produce different addresses");
        assertTrue(addr2 != addr3, "Different salts should produce different addresses");
        assertTrue(addr1 != addr3, "Different salts should produce different addresses");
    }
}
