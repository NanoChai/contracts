// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Deposit.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MCK") {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }
}

contract DeployNanoChai is Script {
    function run() external {

        // Start broadcasting
        vm.startBroadcast();

        // Deploy mock ERC20 token
        MockERC20 mockToken = new MockERC20();

        // Deploy the NanoChai contract with mock token
        NanoChai nanoChai = new NanoChai(mockToken);

        // Stop broadcasting
        vm.stopBroadcast();
    }
}
