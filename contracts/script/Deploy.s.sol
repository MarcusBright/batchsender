// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/Disperse.sol";

/*
# Deploy and verify using account-based authentication
forge script -vvvv \
    --account $DEPLOYER \
    --sender $DEPLOYER_ADDRESS \
    -f $RPC_URL \
    --broadcast \
    --verify \
    script/Deploy.s.sol:DeployDisperse
*/
contract DeployDisperse is Script {
    function run() external returns (Disperse) {
        vm.startBroadcast();
        
        Disperse disperse = new Disperse();
        
        vm.stopBroadcast();

        console.log("=== Deployment Summary ===");
        console.log("Disperse deployed at:", address(disperse));
        console.log("==========================");

        return disperse;
    }
}
