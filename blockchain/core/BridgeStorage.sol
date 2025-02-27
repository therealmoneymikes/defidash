// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract BridgeStorage is AccessControl, Pausable {
    /**
     * @notice Bridge Storage Contract stores info of bridge operations
     * @dev 
     */
    enum DepositStatus { Pending, Withdrawn, Cancelled }

    //Bridge Operator Role
    bytes32 public constant BRIDGE_OPERATOR_ROLE = keccak256("BRIDGE_OPERATOR_ROLE");
    //Bridge Controller Role
    bytes32 public constant BRIDGE_CONTROLLER_ROLE = keccak256("BRIDGE_CONTROLLER_ROLE");

    //Deposit Info Struct
    struct DepositInfo {
        address depositor;
        address token;
        uint256 amount;
        address targetChain;
        uint64 timestamp;
        DepositStatus status;
    }
    
    //Deposit Value to Deposit Info mapping
    mapping(uint256 => DepositInfo) private _deposits;
    //Deposit Count
    uint256 private _depositCount;
    //Authorised Controllers Mapping 
    mapping(address => bool) private _authorizedControllers;

    event DepositCreated(uint256 depositId, address indexed depositor, address indexed token, 
                        uint256 amount, address indexed targetChain);
    event DepositUpdated(uint256 depositId, DepositStatus status);
    event ControllerUpdated(address controller, bool authorized);

    modifier onlyController() {
        require(_authorizedControllers[msg.sender], "Unauthorized controller");
        _;
    }

    constructor(address initialOperator) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(BRIDGE_OPERATOR_ROLE, initialOperator);
    }

    function createDeposit(
        address depositor,
        address token,
        uint256 amount,
        address targetChain
    ) external onlyController whenNotPaused returns (uint256 depositId) {
        require(depositor != address(0), "Invalid depositor");
        require(token != address(0), "Invalid token");
        require(targetChain != address(0), "Invalid chain");
        require(amount > 0, "Invalid amount");

        depositId = ++_depositCount;
        _deposits[depositId] = DepositInfo({
            depositor: depositor,
            token: token,
            amount: amount,
            targetChain: targetChain,
            timestamp: uint64(block.timestamp),
            status: DepositStatus.Pending
        });

        emit DepositCreated(depositId, depositor, token, amount, targetChain);
    }

    function updateDepositStatus(uint256 depositId, DepositStatus status) 
        external onlyRole(BRIDGE_OPERATOR_ROLE) {
        require(depositId <= _depositCount, "Invalid deposit ID");
        require(_deposits[depositId].status == DepositStatus.Pending, "Deposit not pending");
        
        _deposits[depositId].status = status;
        emit DepositUpdated(depositId, status);
    }

    function getDeposit(uint256 depositId) external view returns (DepositInfo memory) {
        require(depositId <= _depositCount, "Invalid deposit ID");
        return _deposits[depositId];
    }

    function depositCount() external view returns (uint256) {
        return _depositCount;
    }

    function updateController(address controller, bool authorized) 
        external onlyRole(DEFAULT_ADMIN_ROLE) {
        _authorizedControllers[controller] = authorized;
        emit ControllerUpdated(controller, authorized);
    }

    function pause() external onlyRole(BRIDGE_OPERATOR_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}