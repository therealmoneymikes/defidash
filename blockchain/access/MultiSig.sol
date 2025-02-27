// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MultisigControl
 * @author Michael Roberts
 * @dev Implements a multi-signature approval mechanism for secure contract management.
 * Requires a specified number of approvals from a set of trusted signers before executing actions.
 */
contract MultisigControl {
    // Events
    event SignerAdded(address indexed signer);
    event SignerRemoved(address indexed signer);
    event RequiredApprovalsChanged(uint256 previousRequired, uint256 newRequired);
    event ApprovalReceived(bytes32 indexed operationId, address indexed signer, uint256 approvalsCount);
    event ApprovalRevoked(bytes32 indexed operationId, address indexed signer, uint256 approvalsCount);
    event OperationCreated(bytes32 indexed operationId, address indexed creator, bytes data, uint256 expiration);
    event OperationExecuted(bytes32 indexed operationId, address indexed executor, bool success);
    event OperationCancelled(bytes32 indexed operationId, address indexed canceller);

    // Custom errors for gas optimization
    error NotSigner();
    error AlreadySigner();
    error AlreadyApproved();
    error NotApproved();
    error InvalidSigners();
    error InvalidApprovalThreshold();
    error OperationAlreadyExecuted();
    error OperationExpired();
    error InsufficientApprovals();
    error ExecutionFailed();
    
    // Operation data structure
    struct Operation {
        bytes data;
        bool executed;
        uint256 approvalsCount;
        uint256 expiration;
        address[] approvers;
    }
    
    // State variables
    mapping(address => bool) public isSigner;
    mapping(bytes32 => Operation) public operations;
    mapping(bytes32 => mapping(address => bool)) public hasApproved;
    
    address[] public signers;
    uint256 public requiredApprovals;
    
    /**
     * @dev Modifier to restrict access to only designated signers.
     */
    modifier onlySigner() {
        if (!isSigner[msg.sender]) revert NotSigner();
        _;
    }
    
    /**
     * @dev Constructor to initialize signers and required approvals.
     * @param _signers List of initial signers.
     * @param _requiredApprovals Number of approvals required for execution.
     */
    constructor(address[] memory _signers, uint256 _requiredApprovals) {
        if (_signers.length == 0) revert InvalidSigners();
        if (_requiredApprovals == 0 || _requiredApprovals > _signers.length) revert InvalidApprovalThreshold();
        
        // Check for duplicate signers
        for (uint256 i = 0; i < _signers.length; i++) {
            if (_signers[i] == address(0)) revert InvalidSigners();
            if (isSigner[_signers[i]]) revert AlreadySigner();
            
            isSigner[_signers[i]] = true;
            signers.push(_signers[i]);
            
            emit SignerAdded(_signers[i]);
        }
        
        requiredApprovals = _requiredApprovals;
        emit RequiredApprovalsChanged(0, _requiredApprovals);
    }
    
    /**
     * @notice Creates a new operation for approval.
     * @param data The calldata to execute when approved.
     * @param expiration Timestamp after which operation can't be executed (0 for no expiration).
     * @return operationId The unique identifier for the operation.
     */
    function createOperation(bytes calldata data, uint256 expiration) external onlySigner returns (bytes32) {
        bytes32 operationId = keccak256(abi.encodePacked(block.number, data, expiration, msg.sender));
        
        operations[operationId].data = data;
        operations[operationId].expiration = expiration;
        
        emit OperationCreated(operationId, msg.sender, data, expiration);
        
        // Auto-approve for creator
        _approveOperation(operationId);
        
        return operationId;
    }
    
    /**
     * @notice Approves an operation identified by a unique hash.
     * @param operationId The unique identifier for the operation.
     */
    function approveOperation(bytes32 operationId) external onlySigner {
        _approveOperation(operationId);
    }
    
    /**
     * @notice Internal function to approve operations.
     */
    function _approveOperation(bytes32 operationId) internal {
        Operation storage op = operations[operationId];
        
        if (op.data.length == 0) revert InsufficientApprovals();
        if (op.executed) revert OperationAlreadyExecuted();
        if (op.expiration > 0 && block.timestamp > op.expiration) revert OperationExpired();
        if (hasApproved[operationId][msg.sender]) revert AlreadyApproved();
        
        hasApproved[operationId][msg.sender] = true;
        op.approvers.push(msg.sender);
        op.approvalsCount++;
        
        emit ApprovalReceived(operationId, msg.sender, op.approvalsCount);
    }
    
    /**
     * @notice Revokes approval for an operation.
     * @param operationId The unique identifier for the operation.
     */
    function revokeApproval(bytes32 operationId) external onlySigner {
        Operation storage op = operations[operationId];
        
        if (op.executed) revert OperationAlreadyExecuted();
        if (!hasApproved[operationId][msg.sender]) revert NotApproved();
        
        hasApproved[operationId][msg.sender] = false;
        
        // Remove approver from array
        for (uint256 i = 0; i < op.approvers.length; i++) {
            if (op.approvers[i] == msg.sender) {
                // Replace with last element and pop
                op.approvers[i] = op.approvers[op.approvers.length - 1];
                op.approvers.pop();
                break;
            }
        }
        
        op.approvalsCount--;
        
        emit ApprovalRevoked(operationId, msg.sender, op.approvalsCount);
    }
    
    /**
     * @notice Executes an operation once it has received enough approvals.
     * @param operationId The unique identifier for the operation.
     * @return success Whether the execution was successful.
     */
    function executeOperation(bytes32 operationId) external onlySigner returns (bool success) {
        Operation storage op = operations[operationId];
        
        if (op.executed) revert OperationAlreadyExecuted();
        if (op.expiration > 0 && block.timestamp > op.expiration) revert OperationExpired();
        if (op.approvalsCount < requiredApprovals) revert InsufficientApprovals();
        
        op.executed = true;
        
        // Execute the operation
        (success, ) = address(this).call(op.data);
        
        if (!success) revert ExecutionFailed();
        
        emit OperationExecuted(operationId, msg.sender, success);
        return success;
    }
    
    /**
     * @notice Cancels an operation that hasn't been executed yet.
     * @param operationId The unique identifier for the operation.
     */
    function cancelOperation(bytes32 operationId) external onlySigner {
        Operation storage op = operations[operationId];
        
        if (op.executed) revert OperationAlreadyExecuted();
        if (op.data.length == 0) revert InsufficientApprovals();
        
        delete operations[operationId];
        
        emit OperationCancelled(operationId, msg.sender);
    }
    
    /**
     * @notice Adds a new signer. Must be called through executeOperation.
     * @param newSigner The address to add as a signer.
     */
    function addSigner(address newSigner) external {
        if (msg.sender != address(this)) revert NotSigner();
        if (newSigner == address(0)) revert InvalidSigners();
        if (isSigner[newSigner]) revert AlreadySigner();
        
        isSigner[newSigner] = true;
        signers.push(newSigner);
        
        emit SignerAdded(newSigner);
    }
    
    /**
     * @notice Removes a signer. Must be called through executeOperation.
     * @param signerToRemove The address to remove.
     */
    function removeSigner(address signerToRemove) external {
        if (msg.sender != address(this)) revert NotSigner();
        if (!isSigner[signerToRemove]) revert NotSigner();
        
        // Ensure we maintain minimum signers for required approvals
        if (signers.length <= requiredApprovals) revert InvalidSigners();
        
        isSigner[signerToRemove] = false;
        
        // Remove from array
        for (uint256 i = 0; i < signers.length; i++) {
            if (signers[i] == signerToRemove) {
                signers[i] = signers[signers.length - 1];
                signers.pop();
                break;
            }
        }
        
        emit SignerRemoved(signerToRemove);
    }
    
    /**
     * @notice Changes the required approval threshold. Must be called through executeOperation.
     * @param newRequiredApprovals The new approval threshold.
     */
    function changeRequiredApprovals(uint256 newRequiredApprovals) external {
        if (msg.sender != address(this)) revert NotSigner();
        if (newRequiredApprovals == 0 || newRequiredApprovals > signers.length) revert InvalidApprovalThreshold();
        
        uint256 oldRequiredApprovals = requiredApprovals;
        requiredApprovals = newRequiredApprovals;
        
        emit RequiredApprovalsChanged(oldRequiredApprovals, newRequiredApprovals);
    }
    
    /**
     * @notice Returns the list of all signers.
     * @return Array of signer addresses.
     */
    function getSigners() external view returns (address[] memory) {
        return signers;
    }
    
    /**
     * @notice Returns the approvers for a specific operation.
     * @param operationId The operation identifier.
     * @return Array of approver addresses.
     */
    function getApprovers(bytes32 operationId) external view returns (address[] memory) {
        return operations[operationId].approvers;
    }
}