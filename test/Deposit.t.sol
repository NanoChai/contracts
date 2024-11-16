// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Deposit.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MCK") {
        _mint(msg.sender, 1000000 * 10 ** 18);
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
        mockToken.transfer(user1, 1000 * 10 ** 18);
        mockToken.transfer(user2, 1000 * 10 ** 18);

        // Approve NanoChai contract to spend tokens
        vm.prank(user1);
        mockToken.approve(address(nanoChai), 1000 * 10 ** 18);
        vm.prank(user2);
        mockToken.approve(address(nanoChai), 1000 * 10 ** 18);
    }

    function testDeposit() public {
        uint256 depositAmount = 100 * 10 ** 18;

        vm.prank(user1);
        nanoChai.deposit(depositAmount);

        (uint256 amount, uint256 unlockTime) = nanoChai.deposits(user1);
        assertEq(amount, depositAmount);
        assertEq(unlockTime, 0);
        assertEq(mockToken.balanceOf(user1), 1000 * 10 ** 18 - depositAmount);
        assertEq(mockToken.balanceOf(address(nanoChai)), depositAmount);
    }

    function testInitiateWithdrawal() public {
        uint256 depositAmount = 100 * 10 ** 18;

        vm.prank(user1);
        nanoChai.deposit(depositAmount);

        vm.prank(user1);
        nanoChai.initiateWithdrawal();

        (, uint256 unlockTime) = nanoChai.deposits(user1);
        assertEq(unlockTime, block.timestamp + 30 minutes);
    }

    function testFinishWithdrawal() public {
        uint256 depositAmount = 100 * 10 ** 18;

        vm.prank(user1);
        nanoChai.deposit(depositAmount);

        vm.prank(user1);
        nanoChai.initiateWithdrawal();

        vm.warp(block.timestamp + 30 minutes);

        vm.prank(user1);
        nanoChai.finishWithdrawal(depositAmount);

        (uint256 amount,) = nanoChai.deposits(user1);
        assertEq(amount, 0);
    }

    function testRegisterService() public {
        vm.prank(service1);
        nanoChai.registerService("Test Service", restaker1);

        (string memory name, address restaker, bool exists) = nanoChai.services(service1);
        assertEq(name, "Test Service");
        assertEq(restaker, restaker1);
        assertTrue(exists);
    }

    function testRestake() public {
        uint256 stakeAmount = 100 * 10 ** 18;

        mockToken.transfer(restaker1, stakeAmount);

        vm.startPrank(restaker1);
        mockToken.approve(address(nanoChai), stakeAmount);
        nanoChai.restake(stakeAmount);
        vm.stopPrank();

        uint256 totalStake = nanoChai.getRestakerTotalStake(restaker1);
        assertEq(totalStake, stakeAmount);
    }

    function testWithdrawTotalStake() public {
        uint256 stakeAmount = 100 * 10 ** 18;

        mockToken.transfer(restaker1, stakeAmount);
        vm.startPrank(restaker1);
        mockToken.approve(address(nanoChai), stakeAmount);
        nanoChai.restake(stakeAmount);

        nanoChai.withdrawTotalStake(stakeAmount);
        vm.stopPrank();

        uint256 totalStake = nanoChai.getRestakerTotalStake(restaker1);
        assertEq(totalStake, 0);
    }

    function testAllocateToService() public {
        uint256 stakeAmount = 100 * 10 ** 18;

        vm.prank(service1);
        nanoChai.registerService("Test Service", restaker1);

        mockToken.transfer(restaker1, stakeAmount);
        vm.startPrank(restaker1);
        mockToken.approve(address(nanoChai), stakeAmount);
        nanoChai.restake(stakeAmount);

        nanoChai.allocateToService(service1, stakeAmount);
        vm.stopPrank();

        uint256 allocation = nanoChai.getRestakerAllocations(restaker1, service1);
        assertEq(allocation, stakeAmount);
    }

    function testInitiateAllocationReduction() public {
        uint256 stakeAmount = 100 * 10 ** 18;

        vm.prank(service1);
        nanoChai.registerService("Test Service", restaker1);

        mockToken.transfer(restaker1, stakeAmount);
        vm.startPrank(restaker1);
        mockToken.approve(address(nanoChai), stakeAmount);
        nanoChai.restake(stakeAmount);

        nanoChai.allocateToService(service1, stakeAmount);

        uint256 reductionAmount = 50 * 10 ** 18;
        nanoChai.initiateAllocationReduction(service1, reductionAmount);
        vm.stopPrank();

        uint256 reduction = nanoChai.getRestakerPendingReductions(restaker1, service1);
        assertEq(reduction, reductionAmount);
    }
}
