// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MultisigControl
 * @author Michael Roberts
 * @dev Implements a multi-signature approval mechanism for secure contract management.
 * Requires a specified number of approvals from a set of trusted signers before executing actions.
 * 
 */
contract MultisigControl {
    // List of authorized signers
    address[] private _signers;
    // Minimum number of approvals required
    uint256 private _requiredApprovals;

    // Mapping to track approvals for each operation
    mapping(bytes32 => uint256) private _approvals;
    mapping(bytes32 => mapping(address => bool)) private _hasApproved;

    // Events for approvals and execution
    event ApprovalReceived(bytes32 indexed operation, address indexed signer, uint256 approvalsCount);
    event OperationExecuted(bytes32 indexed operation);

    /**
     * @dev Modifier to restrict access to only designated signers.
     */
    modifier onlySigner() {
        require(isSigner(msg.sender), "MultisigControl: caller is not a signer");
        _;
    }

    /**
     * @dev Constructor to initialize signers and required approvals.
     * @param signers List of initial signers.
     * @param requiredApprovals Number of approvals required for execution.
     */
    constructor(address[] memory signers, uint256 requiredApprovals) {
        require(signers.length > 0, "MultisigControl: signers required");
        require(requiredApprovals > 0 && requiredApprovals <= signers.length, "MultisigControl: invalid approvals count");

        _signers = signers;
        _requiredApprovals = requiredApprovals;
    }

    /**
     * @notice Checks if an address is an authorized signer.
     * @param account The address to check.
     * @return True if the account is a signer, false otherwise.
     */
    function isSigner(address account) public view returns (bool) {
        for (uint256 i = 0; i < _signers.length; i++) {
            if (_signers[i] == account) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Approves an operation identified by a unique hash.
     * @param operation The unique identifier for the operation.
     */
    function approveOperation(bytes32 operation) external onlySigner {
        require(!_hasApproved[operation][msg.sender], "MultisigControl: already approved");

        _hasApproved[operation][msg.sender] = true;
        _approvals[operation]++;

        emit ApprovalReceived(operation, msg.sender, _approvals[operation]);

        // Execute operation if required approvals are met
        if (_approvals[operation] >= _requiredApprovals) {
            _executeOperation(operation);
        }
    }

    /**
     * @notice Executes an operation once it has received enough approvals.
     * @param operation The unique identifier for the operation.
     */
    function _executeOperation(bytes32 operation) internal {
        emit OperationExecuted(operation);
        delete _approvals[operation]; // Reset approval count
    }

    /**
     * @notice Returns the number of approvals required.
     * @return The number of required approvals.
     */
    function requiredApprovals() external view returns (uint256) {
        return _requiredApprovals;
    }
}
