// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title User Roles
 * @author Michael Roberts
 * @dev Implements a RBAC style User Role for controlling contract call abilities
 * Not Users cannot remove admin role
 * 
 */
contract UserRoles is AccessControl, Pausable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");
    bytes32 public constant USER_ROLE = keccak256("USER_ROLE");

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function grantRole(bytes32 role, address account) public override whenNotPaused onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) public override whenNotPaused onlyRole(DEFAULT_ADMIN_ROLE) {
        require(role != DEFAULT_ADMIN_ROLE || account != msg.sender, "UserRoles: cannot revoke own admin role");
        _revokeRole(role, account);
    }

    function grantRoles(bytes32[] calldata roles, address account) external whenNotPaused onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < roles.length; i++) {
            _grantRole(roles[i], account);
        }
    }

    function revokeRoles(bytes32[] calldata roles, address account) external whenNotPaused onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < roles.length; i++) {
            _revokeRole(roles[i], account);
        }
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}