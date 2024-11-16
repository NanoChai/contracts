// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Deposit.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MCK") {
        _mint(msg.sender, 1000000 * 10**18);
    }
}

contract NanoChaiTest is Test {
    NanoChai public nanoChai;
    MockERC20 public mockToken;
    address public user1;
    address public user2;
    address public service1;
    address public restaker1;

    function setUp() public {
        // Deploy mock token and NanoChai contract
        mockToken = new MockERC20();
        nanoChai = new NanoChai(mockToken);

        // Create mock addresses
        user1 = address(0x1);
        user2 = address(0x2);
        service1 = address(0x3);
        restaker1 = address(0x4);

        // Fund users with mock tokens
        mockToken.transfer(user1, 1000 * 10**18);
        mockToken.transfer(user2, 1000 * 10**18);

        // Approve NanoChai contract to spend tokens
        vm.prank(user1);
        mockToken.approve(address(nanoChai), 1000 * 10**18);
        vm.prank(user2);
        mockToken.approve(address(nanoChai), 1000 * 10**18);
    }

    function testDeposit() public {
        uint256 depositAmount = 100 * 10**18;

        vm.prank(user1);
        nanoChai.deposit(depositAmount);

        (uint256 amount, uint256 unlockTime) = nanoChai.deposits(user1);
        assertEq(amount, depositAmount);
        assertEq(unlockTime, 0);
    }

    function testInitiateWithdrawal() public {
        uint256 depositAmount = 100 * 10**18;

        vm.prank(user1);
        nanoChai.deposit(depositAmount);

        vm.prank(user1);
        nanoChai.initiateWithdrawal();

        (, uint256 unlockTime) = nanoChai.deposits(user1);
        assertEq(unlockTime, block.timestamp + 30 minutes);
    }

    function testFinishWithdrawal() public {
        uint256 depositAmount = 100 * 10**18;

        vm.prank(user1);
        nanoChai.deposit(depositAmount);

        vm.prank(user1);
        nanoChai.initiateWithdrawal();

        // Fast forward time by 30 minutes
        vm.warp(block.timestamp + 30 minutes);

        vm.prank(user1);
        nanoChai.finishWithdrawal(depositAmount);

        (uint256 amount, ) = nanoChai.deposits(user1);
        assertEq(amount, 0);
        assertEq(mockToken.balanceOf(user1), depositAmount);
    }

    function testRegisterService() public {
        vm.prank(restaker1);
        nanoChai.registerService("Test Service", restaker1);

        (string memory name, address restaker, bool exists) = nanoChai.services(service1);
        assertEq(name, "Test Service");
        assertEq(restaker, restaker1);
        assertTrue(exists);
    }

    function testRestake() public {
        uint256 restakeAmount = 200 * 10**18;

        vm.prank(restaker1);
        mockToken.transfer(restaker1, restakeAmount);
        vm.prank(restaker1);
        mockToken.approve(address(nanoChai), restakeAmount);

        vm.prank(restaker1);
        nanoChai.restake(restakeAmount);

        // Restaker storage restaker = nanoChai.restakers(restaker1);
        // uint256 totalStake = restaker.totalStake;
        // assertEq(totalStake, restakeAmount);
    }

    function testAllocateToService() public {
        uint256 restakeAmount = 200 * 10**18;
        uint256 allocationAmount = 100 * 10**18;

        vm.prank(restaker1);
        mockToken.transfer(restaker1, restakeAmount);
        vm.prank(restaker1);
        mockToken.approve(address(nanoChai), restakeAmount);

        vm.prank(restaker1);
        nanoChai.restake(restakeAmount);

        vm.prank(restaker1);
        nanoChai.registerService("Test Service", restaker1);

        vm.prank(restaker1);
        nanoChai.allocateToService(service1, allocationAmount);

//         Restaker memory restaker = nanoChai.restakers(restaker1);
// uint256 totalStake = restaker.totalStake;
//         uint256 allocatedAmount = restaker.allocations[service1];

//         assertEq(totalStake, restakeAmount - allocationAmount);
//         assertEq(allocatedAmount, allocationAmount);
    }

    function testInitiateAllocationReduction() public {
        uint256 restakeAmount = 200 * 10**18;
        uint256 allocationAmount = 100 * 10**18;
        uint256 reductionAmount = 50 * 10**18;

        vm.prank(restaker1);
        mockToken.transfer(restaker1, restakeAmount);
        vm.prank(restaker1);
        mockToken.approve(address(nanoChai), restakeAmount);

        vm.prank(restaker1);
        nanoChai.restake(restakeAmount);

        vm.prank(restaker1);
        nanoChai.registerService("Test Service", restaker1);

        vm.prank(restaker1);
        nanoChai.allocateToService(service1, allocationAmount);

        vm.prank(restaker1);
        nanoChai.initiateAllocationReduction(service1, reductionAmount);

        // uint256 pendingReduction = restaker.pendingReductions[service1];
        // assertEq(pendingReduction, reductionAmount);
    }

    function testFinishAllocationReduction() public {
        uint256 restakeAmount = 200 * 10**18;
        uint256 allocationAmount = 100 * 10**18;
        uint256 reductionAmount = 50 * 10**18;

        vm.prank(restaker1);
        mockToken.transfer(restaker1, restakeAmount);
        vm.prank(restaker1);
        mockToken.approve(address(nanoChai), restakeAmount);

        vm.prank(restaker1);
        nanoChai.restake(restakeAmount);

        vm.prank(restaker1);
        nanoChai.registerService("Test Service", restaker1);

        vm.prank(restaker1);
        nanoChai.allocateToService(service1, allocationAmount);

        vm.prank(restaker1);
        nanoChai.initiateAllocationReduction(service1, reductionAmount);

        // Fast forward time by 30 minutes
        vm.warp(block.timestamp + 30 minutes);

        vm.prank(restaker1);
        nanoChai.finishAllocationReduction(service1);

        // uint256 pendingReduction = nanoChai.restakers(restaker1).pendingReductions(service1);
        // uint256 totalStake = nanoChai.restakers(restaker1).totalStake;

        // assertEq(pendingReduction, 0);
        // assertEq(totalStake, restakeAmount - allocationAmount + reductionAmount);
    }
}
