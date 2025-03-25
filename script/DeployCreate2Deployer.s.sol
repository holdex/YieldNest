// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";

import { Create2Deployer } from "../src/mock/Create2Deployer.sol";

contract DeployCreate2Deployer is Script {
    address constant CREATE2_DEPLOYER = address(0xceEdACe70F46091986CA09Ac834362b74bC211F4);

    function run() public {
        // Retrieve the deployer's private key.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Deploy the hook using CREATE2
        // Start broadcasting transactions to the network.
        vm.startBroadcast(deployerPrivateKey);
        // Deploy the YieldNestHook contract.
        Create2Deployer create2Instance = new Create2Deployer();
        bytes memory code = address(create2Instance).code;
        vm.etch(CREATE2_DEPLOYER, code);
        // Stop broadcasting transactions.
        vm.stopBroadcast();

        console.log('Deployer Address', address(create2Instance));
    }
}
