// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title User Roles
 * @author Michael Roberts
 * @dev Implements a RBAC style User Role for controlling contract call abilities
 * Users cannot remove their own admin role
 */
contract UserRoles is AccessControl, Pausable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");
    bytes32 public constant USER_ROLE = keccak256("USER_ROLE");

    // Custom events
    event RolesGranted(address indexed account, bytes32[] roles);
    event RolesRevoked(address indexed account, bytes32[] roles);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Grants a single role to an account
     * @param role The role to grant
     * @param account The account to receive the role
     */
    function grantRole(bytes32 role, address account) public override whenNotPaused onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes a single role from an account
     * @param role The role to revoke
     * @param account The account to lose the role
     */
    function revokeRole(bytes32 role, address account) public override whenNotPaused onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            role != DEFAULT_ADMIN_ROLE || account != msg.sender, 
            "UserRoles: cannot revoke own admin role"
        );
        _revokeRole(role, account);
    }

    /**
     * @dev Grants multiple roles to an account in a single transaction
     * @param roles Array of roles to grant
     * @param account The account to receive the roles
     */
    function grantRoles(bytes32[] calldata roles, address account) external whenNotPaused onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 length = roles.length;
        for (uint256 i = 0; i < length;) {
            _grantRole(roles[i], account);
            unchecked { i++; } // Gas optimization for increment
        }
        emit RolesGranted(account, roles);
    }

    /**
     * @dev Revokes multiple roles from an account in a single transaction
     * @param roles Array of roles to revoke
     * @param account The account to lose the roles
     */
    function revokeRoles(bytes32[] calldata roles, address account) external whenNotPaused onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 length = roles.length;
        for (uint256 i = 0; i < length;) {
            // Prevent revoking own admin role
            if (roles[i] == DEFAULT_ADMIN_ROLE && account == msg.sender) {
                revert("UserRoles: cannot revoke own admin role");
            }
            _revokeRole(roles[i], account);
            unchecked { i++; } // Gas optimization for increment
        }
        emit RolesRevoked(account, roles);
    }

    /**
     * @dev Pauses all role management functions
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses all role management functions
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @dev Checks if an account has moderator privileges (admin or moderator)
     * @param account Address to check
     * @return bool True if account has moderator privileges
     */
    function isModerator(address account) external view returns (bool) {
        return hasRole(ADMIN_ROLE, account) || hasRole(MODERATOR_ROLE, account);
    }
}