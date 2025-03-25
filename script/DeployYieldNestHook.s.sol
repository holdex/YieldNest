// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {IPoolManager, YieldNestHook } from "../src/YieldNestHook.sol";

import { Create2Deployer } from "../src/mock/Create2Deployer.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "@uniswap/v4-periphery/src/utils/HookMiner.sol";

contract DeployYieldNestHook is Script {
    address constant CREATE2_DEPLOYER = address(0x8d44F1fA24e98Fe0540D1A6cE0e439Fd7e6583dA);

    function run() public {
        // Retrieve parameters from environment variables.
        // You can also set these directly if needed.
        address poolManagerAddress = vm.envAddress("POOL_MANAGER_ADDRESS");
        address feeCollector = vm.envAddress("FEE_COLLECTOR_ADDRESS");
        uint256 commission = vm.envUint("COMMISSION"); // e.g., 50 for 0.5%

         // Retrieve the deployer's private key.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address governor = vm.addr(deployerPrivateKey);

        // Cast the pool manager address to the IPoolManager interface.
        IPoolManager poolManager = IPoolManager(poolManagerAddress);

        // Define the permissions flags needed for your hook.
        uint160 flags = uint160(
            Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
        );

        // Mine a salt to get a suitable deployment address.
        bytes memory constructorArgs = abi.encode(poolManager, governor, feeCollector, commission);
        (address predictedHookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER,
            flags,
            type(YieldNestHook).creationCode,
            constructorArgs
        );

        console.log("Predicted hook address:", predictedHookAddress);
        console.logBytes32(salt);

        // Deploy the hook using CREATE2
        // Start broadcasting transactions to the network.
        vm.startBroadcast(deployerPrivateKey);
        // Deploy the YieldNestHook contract.

        Create2Deployer create2Deployer = Create2Deployer(CREATE2_DEPLOYER);

        Create2Deployer.FunctionCall[] memory calls = new Create2Deployer.FunctionCall[](0);

        address yieldNestHook = create2Deployer.deploy(
            abi.encodePacked(type(YieldNestHook).creationCode, constructorArgs),
            uint256(salt), 
            calls
        );
        // Stop broadcasting transactions.
        vm.stopBroadcast();
        // console.log("Predicted hook address:", address(yieldNestHook));
        require(yieldNestHook == predictedHookAddress, "YieldNestHook: hook address mismatch");
    }
}
