// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract NanoChai {
    using ECDSA for bytes32;

    uint256 public constant LOCK_DURATION = 30 minutes;

    IERC20 public token;

    struct Deposit {
        uint256 amount;
        uint256 unlockTime;
    }

    struct Service {
        string name;
        address restaker;
        bool exists;
    }

    struct Restaker {
        uint256 totalStake;
        mapping(address => uint256) allocations;
        mapping(address => uint256) pendingReductions;
        mapping(address => uint256) reductionUnlockTime;
    }

    struct WithdrawWithSignaturesArgs {
        address[] users;
        uint256[] amounts;
        uint256[] nonces;
        uint256[] timestamps;
        bytes[] userSigs;
        bytes[] restakerSigs;
    }

    mapping(address => Deposit) public deposits;
    mapping(address => Service) public services;
    mapping(address => Restaker) public restakers;
    mapping(address => mapping(address => uint256)) public userNonces; // userNonces[service][user]

    event Deposited(address indexed user, uint256 amount, uint256 unlockTime);
    event WithdrawalInitiated(address indexed user, uint256 unlockTime);
    event Withdrawn(address indexed user, uint256 amount);
    event ServiceRegistered(address indexed service, string name, address restaker);
    event ServiceWithdrawn(address indexed service, uint256 totalAmount);
    event RestakerSlashed(address indexed restaker, uint256 slashedAmount);
    event Restaked(address indexed restaker, uint256 amount);
    event Allocated(address indexed restaker, address indexed service, uint256 amount);
    event AllocationReductionInitiated(address indexed restaker, address indexed service, uint256 amount, uint256 unlockTime);
    event AllocationReductionFinished(address indexed restaker, address indexed service, uint256 amount);

    constructor(IERC20 _token) {
        token = _token;
    }

    // Deposit funds to the contract
    function deposit(uint256 amount) external {
        require(amount > 0, "Deposit amount must be greater than 0");
        Deposit storage userDeposit = deposits[msg.sender];
        userDeposit.amount += amount;
        userDeposit.unlockTime = 0; // Reset unlock time on new deposit

        require(token.transferFrom(msg.sender, address(this), amount), "Token transfer failed");

        emit Deposited(msg.sender, amount, userDeposit.unlockTime);
    }

    // Initiate withdrawal process by setting the unlock time
    function initiateWithdrawal() external {
        Deposit storage userDeposit = deposits[msg.sender];
        require(userDeposit.amount > 0, "No funds to withdraw");
        require(userDeposit.unlockTime == 0, "Withdrawal already initiated");
        userDeposit.unlockTime = block.timestamp + LOCK_DURATION;

        emit WithdrawalInitiated(msg.sender, userDeposit.unlockTime);
    }

    // Finish withdrawal after 30-minute lock period
    function finishWithdrawal(uint256 amount) external {
        Deposit storage userDeposit = deposits[msg.sender];
        require(userDeposit.unlockTime > 0, "Withdrawal not initiated");
        require(block.timestamp >= userDeposit.unlockTime, "Funds are still locked");
        require(amount > 0 && amount <= userDeposit.amount, "Invalid withdrawal amount");

        userDeposit.amount -= amount;
        if (userDeposit.amount == 0) {
            userDeposit.unlockTime = 0;
        }
        require(token.transfer(msg.sender, amount), "Token transfer failed");

        emit Withdrawn(msg.sender, amount);
    }

    // Register a service with its name and associated restaker
    function registerService(string calldata name, address restaker) external {
        require(!services[msg.sender].exists, "Service already registered");
        require(restaker != address(0), "Invalid restaker address");

        services[msg.sender] = Service({name: name, restaker: restaker, exists: true});
        emit ServiceRegistered(msg.sender, name, restaker);
    }

    // Restake funds and allocate them to various services
    function restake(uint256 amount) external {
        require(amount > 0, "Restake amount must be greater than 0");
        Restaker storage restaker = restakers[msg.sender];
        restaker.totalStake += amount;

        require(token.transferFrom(msg.sender, address(this), amount), "Token transfer failed");

        emit Restaked(msg.sender, amount);
    }

    // Withdraw total stake for a restaker
    function withdrawTotalStake(uint256 amount) external {
        Restaker storage restaker = restakers[msg.sender];
        require(amount > 0 && amount <= restaker.totalStake, "Invalid withdrawal amount");

        restaker.totalStake -= amount;
        require(token.transfer(msg.sender, amount), "Token transfer failed");
    }

    function allocateToService(address service, uint256 amount) external {
        require(services[service].exists, "Service not registered");
        Restaker storage restaker = restakers[msg.sender];
        require(amount > 0 && amount <= restaker.totalStake, "Invalid allocation amount");

        restaker.totalStake -= amount;
        restaker.allocations[service] += amount;

        emit Allocated(msg.sender, service, amount);
    }

    // Initiate allocation reduction by setting a pending reduction amount with a delay
    function initiateAllocationReduction(address service, uint256 amount) external {
        require(services[service].exists, "Service not registered");
        Restaker storage restaker = restakers[msg.sender];
        require(amount > 0 && amount <= restaker.allocations[service], "Invalid reduction amount");

        restaker.pendingReductions[service] += amount;
        restaker.reductionUnlockTime[service] = block.timestamp + LOCK_DURATION;

        emit AllocationReductionInitiated(msg.sender, service, amount, restaker.reductionUnlockTime[service]);
    }

    // Finish allocation reduction by actually reducing the allocation after delay
    function finishAllocationReduction(address service) external {
        require(services[service].exists, "Service not registered");
        Restaker storage restaker = restakers[msg.sender];
        uint256 amount = restaker.pendingReductions[service];
        require(amount > 0, "No pending reduction to finalize");
        require(block.timestamp >= restaker.reductionUnlockTime[service], "Reduction period not yet finished");

        restaker.allocations[service] -= amount;
        restaker.totalStake += amount;
        restaker.pendingReductions[service] = 0;
        restaker.reductionUnlockTime[service] = 0;

        emit AllocationReductionFinished(msg.sender, service, amount);
    }
    
    // Verify and process multiple user + restaker signatures off-chain, then allow services to withdraw
    function withdrawWithSignatures(
        WithdrawWithSignaturesArgs calldata args
    ) external {
        require(
            args.users.length == args.amounts.length &&
            args.users.length == args.nonces.length &&
            args.users.length == args.timestamps.length &&
            args.users.length == args.userSigs.length &&
            args.users.length == args.restakerSigs.length,
            "Input arrays must have the same length"
        );

        uint256 totalAmount = 0;
        address service = msg.sender;
        require(services[service].exists, "Service not registered");
        Restaker storage restakerData = restakers[services[service].restaker];
        require(restakerData.allocations[service] > 0, "No allocation available for service");

        for (uint256 i = 0; i < args.users.length; i++) {
            uint256 verifiedAmount = _verifyUserSignature(args.users[i], args.amounts[i], args.nonces[i], args.timestamps[i], args.userSigs[i], service);
            uint256 processedAmount = _processRestakerSignature(args.users[i], verifiedAmount, args.restakerSigs[i], service);
            totalAmount += processedAmount;
        }

        require(token.transfer(service, totalAmount), "Token transfer failed");
        emit ServiceWithdrawn(service, totalAmount);
    }

    function _verifyUserSignature(
        address user,
        uint256 amount,
        uint256 nonce,
        uint256 timestamp,
        bytes calldata userSig,
        address service
    ) internal view returns (uint256) {
        bytes32 messageHash = keccak256(abi.encodePacked(service, amount, timestamp, nonce, block.chainid));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        // Verify user signature
        require(recoverSigner(ethSignedMessageHash, userSig) == user, "Invalid user signature");
        return amount;
    }

    function _processRestakerSignature(
        address user,
        uint256 amount,
        bytes calldata restakerSig,
        address service
    ) internal returns (uint256) {
        bytes32 messageHash = keccak256(abi.encodePacked(service, amount, userNonces[service][user], block.chainid));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        // Verify restaker signature
        require(recoverSigner(ethSignedMessageHash, restakerSig) == services[service].restaker, "Invalid restaker signature");

        // Increment nonce
        userNonces[service][user] += 1;

        // Check user balance
        Deposit storage userDeposit = deposits[user];
        if (userDeposit.amount < amount) {
            uint256 slashAmount = amount - userDeposit.amount;
            require(slashAmount < restakers[services[service].restaker].allocations[service], "Slash amount exceeds allocation");

            restakers[services[service].restaker].allocations[service] -= slashAmount;
            emit RestakerSlashed(services[service].restaker, slashAmount);
            return slashAmount;
        } else {
            userDeposit.amount -= amount;
            return amount;
        }
    }

    function getEthSignedMessageHash(bytes32 messageHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
    }

    function recoverSigner(bytes32 ethSignedMessageHash, bytes memory signature) internal pure returns (address) {
        return ethSignedMessageHash.recover(signature);
    }
}
