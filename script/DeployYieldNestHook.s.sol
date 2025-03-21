// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {IPoolManager, YieldNestHook } from "../src/YieldNestHook.sol";

contract DeployYieldNestHook is Script {
    function run() external {
        // Retrieve parameters from environment variables.
        // You can also set these directly if needed.
        address poolManagerAddress = vm.envAddress("POOL_MANAGER_ADDRESS");
        address feeCollector = vm.envAddress("FEE_COLLECTOR_ADDRESS");
        uint256 commission = vm.envUint("COMMISSION"); // e.g., 50 for 0.5%

         // Retrieve the deployer's private key.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Cast the pool manager address to the IPoolManager interface.
        IPoolManager poolManager = IPoolManager(poolManagerAddress);

        // Start broadcasting transactions to the network.
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the YieldNestHook contract.
        YieldNestHook yieldNestHook = new YieldNestHook(poolManager, feeCollector, commission);

        // Stop broadcasting transactions.
        vm.stopBroadcast();

        // Log the deployed contract address.
        console.log("YieldNestHook deployed at:", address(yieldNestHook));
    }
}
