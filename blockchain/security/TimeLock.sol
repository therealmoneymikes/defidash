// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title Time Lock Contract
 * @author Michael Roberts
 * @dev Time Lock Contract Inherits from Access Control from 
 * 
 */
contract TimeLock is AccessControl {
    using Address for address;

    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");

    struct TimelockedTransaction {
        address target;
        address proposer;
        uint256 value;
        bytes data;
        uint40 scheduledAt;
        uint40 executeAfter;
        bool executed;
        bool canceled;
    }

    uint256 public minDelay;
    uint256 public nonce;
    mapping(bytes32 => TimelockedTransaction) public timelockedTransactions;

    event TransactionScheduled(
        bytes32 indexed txId,
        address indexed target,
        address indexed proposer,
        uint256 value,
        uint40 scheduledAt,
        uint40 executeAfter
    );
    event TransactionExecuted(
        bytes32 indexed txId,
        address indexed target,
        uint256 value
    );
    event TransactionCanceled(bytes32 indexed txId);
    event MinDelayUpdated(uint256 newDelay, uint40 effectiveAfter);

    modifier onlyExecutor() {
        require(hasRole(EXECUTOR_ROLE, msg.sender), "Access denied");
        _;
    }

    constructor(uint256 initialDelay, address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PROPOSER_ROLE, admin);
        _grantRole(EXECUTOR_ROLE, admin);
        _updateMinDelay(initialDelay);
    }

    function scheduleTransaction(
        address target,
        uint256 value,
        bytes calldata data
    ) external onlyRole(PROPOSER_ROLE) returns (bytes32 txId) {
        require(target.isContract(), "Target not contract");

        txId = keccak256(
            abi.encode(block.chainid, target, value, data, nonce++)
        );

        uint40 scheduledAt = uint40(block.timestamp);
        uint40 executeAfter = uint40(block.timestamp + minDelay);

        timelockedTransactions[txId] = TimelockedTransaction({
            target: target,
            proposer: msg.sender,
            value: value,
            data: data,
            scheduledAt: scheduledAt,
            executeAfter: executeAfter,
            executed: false,
            canceled: false
        });

        emit TransactionScheduled(
            txId,
            target,
            msg.sender,
            value,
            scheduledAt,
            executeAfter
        );
    }

    function executeTransaction(bytes32 txId) external onlyExecutor {
        TimelockedTransaction storage tx = timelockedTransactions[txId];

        require(tx.executeAfter > 0, "Transaction unknown");
        require(block.timestamp >= tx.executeAfter, "Delay not met");
        require(!tx.executed, "Already executed");
        require(!tx.canceled, "Transaction canceled");

        tx.executed = true;

        (bool success, ) = tx.target.call{value: tx.value}(tx.data);
        require(success, "Execution failed");

        emit TransactionExecuted(txId, tx.target, tx.value);
    }

    function cancelTransaction(
        bytes32 txId
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        TimelockedTransaction storage tx = timelockedTransactions[txId];
        require(!tx.executed, "Already executed");
        require(!tx.canceled, "Already canceled");

        tx.canceled = true;
        emit TransactionCanceled(txId);
    }

    function updateMinDelay(
        uint256 newDelay
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newDelay != minDelay, "Delay unchanged");
        require(
            newDelay > 1 hours && newDelay < 30 days,
            "Delay out of bounds"
        );
        _updateMinDelay(newDelay);
    }

    function _updateMinDelay(uint256 newDelay) internal {
        minDelay = newDelay;
        emit MinDelayUpdated(newDelay, uint40(block.timestamp + minDelay));
    }

    receive() external payable {}
}
