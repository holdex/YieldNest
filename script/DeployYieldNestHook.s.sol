// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {IPoolManager, YieldNestHook } from "../src/YieldNestHook.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";

contract DeployYieldNestHook is Script {
    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);

    function run() public {
        // Retrieve parameters from environment variables.
        // You can also set these directly if needed.
        address poolManagerAddress = vm.envAddress("POOL_MANAGER_ADDRESS");
        address feeCollector = vm.envAddress("FEE_COLLECTOR_ADDRESS");
        uint256 commission = vm.envUint("COMMISSION"); // e.g., 50 for 0.5%

         // Retrieve the deployer's private key.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Cast the pool manager address to the IPoolManager interface.
        IPoolManager poolManager = IPoolManager(poolManagerAddress);

        // Define the permissions flags needed for your hook.
        // In this example we require BEFORE_SWAP and BEFORE_ADD_LIQUIDITY.
        uint160 flags = uint160(
            Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
        );

        // Mine a salt to get a suitable deployment address.
        bytes memory constructorArgs = abi.encode(poolManager, feeCollector, commission);
        (address predictedHookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER,
            flags,
            type(YieldNestHook).creationCode,
            constructorArgs
        );

        console.log("Predicted hook address:", predictedHookAddress);
        console.logBytes32(salt);

        // Deploy the hook using CREATE2
        bytes memory bytecode = abi.encodePacked(type(YieldNestHook).creationCode, constructorArgs);
        vm.startBroadcast(deployerPrivateKey);
        address deployedHook;
        assembly {
            deployedHook := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        vm.stopBroadcast();

        // verify proper create2 usage
        console.log("YieldNestHook deployed at:", deployedHook);
        require(deployedHook == predictedHookAddress, "DeployScript: hook address mismatch");

        // // Start broadcasting transactions to the network.
        // vm.startBroadcast(deployerPrivateKey);

        // // Deploy the YieldNestHook contract.
        // YieldNestHook yieldNestHook = new YieldNestHook{salt: salt}(poolManager, feeCollector, commission);

        // // Stop broadcasting transactions.
        // vm.stopBroadcast();

        // console.log("YieldNestHook deployed at:", address(yieldNestHook));
    }
}
