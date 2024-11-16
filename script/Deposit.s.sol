// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Deposit.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

address constant USDC_BASE_SEPOLIA_TOKEN_ADDRESS = 0x2e880FbE609947Cd45D0B4dA22caa1B6777ba9A4;
contract DeployNanoChai is Script {
    function run() external {

        // Start broadcasting'
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        string memory rpcUrl = vm.envString("BASE_SEPOLIA_RPC_URL");
        vm.createSelectFork(rpcUrl);
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the NanoChai contract with mock token
        NanoChai nanoChai = new NanoChai(USDC_BASE_SEPOLIA_TOKEN_ADDRESS);
        console.log("NanoChai contract deployed at address: %s", address(nanoChai));

        // Stop broadcasting
        vm.stopBroadcast();
    }
}
