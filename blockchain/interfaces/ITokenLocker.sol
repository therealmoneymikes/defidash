// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ITokenLocker
 * @dev Interface for locking and unlocking tokens with time restrictions
 */
interface ITokenLocker {
    /**
     * @notice Lock tokens for a specified period
     * @param token Address of the ERC20 token to lock
     * @param amount Amount of tokens to lock
     * @param unlockTime Timestamp when tokens become unlockable
     * @return lockId Unique identifier for this lock
     */
    function lockTokens(
        address token,
        uint256 amount,
        uint256 unlockTime
    ) external returns (bytes32 lockId);
    
    /**
     * @notice Unlock tokens after the lock period has expired
     * @param lockId Unique identifier for the lock
     * @return amount Amount of tokens unlocked
     */
    function unlockTokens(bytes32 lockId) external returns (uint256 amount);
    
    /**
     * @notice Extend the lock time for existing locked tokens
     * @param lockId Unique identifier for the lock
     * @param newUnlockTime New timestamp when tokens become unlockable
     */
    function extendLockTime(bytes32 lockId, uint256 newUnlockTime) external;
    
    /**
     * @notice Get information about a specific lock
     * @param lockId Unique identifier for the lock
     * @return token Token address
     * @return amount Locked amount
     * @return unlockTime Time when tokens can be unlocked
     * @return owner Address that created the lock
     * @return isUnlocked Whether the lock has been released
     */
    function getLockInfo(bytes32 lockId) external view returns (
        address token,
        uint256 amount,
        uint256 unlockTime,
        address owner,
        bool isUnlocked
    );
    
    /**
     * @notice Get all lock IDs belonging to an address
     * @param owner Address to query locks for
     * @return lockIds Array of lock identifiers
     */
    function getUserLocks(address owner) external view returns (bytes32[] memory lockIds);

    /**
     * @dev Emitted when tokens are locked
     * @param lockId Unique identifier for the lock
     * @param token Address of the locked token
     * @param locker Address that locked the tokens
     * @param amount Amount of tokens locked
     * @param unlockTime Timestamp when tokens become unlockable
     */
    event TokensLocked(
        bytes32 indexed lockId,
        address indexed token,
        address indexed locker,
        uint256 amount,
        uint256 unlockTime
    );
    
    /**
     * @dev Emitted when tokens are unlocked
     * @param lockId Unique identifier for the lock
     * @param token Address of the unlocked token
     * @param locker Address that receives the tokens
     * @param amount Amount of tokens unlocked
     */
    event TokensUnlocked(
        bytes32 indexed lockId,
        address indexed token,
        address indexed locker,
        uint256 amount
    );
    
    /**
     * @dev Emitted when lock time is extended
     * @param lockId Unique identifier for the lock
     * @param oldUnlockTime Previous unlock timestamp
     * @param newUnlockTime New unlock timestamp
     */
    event LockTimeExtended(
        bytes32 indexed lockId,
        uint256 oldUnlockTime,
        uint256 newUnlockTime
    );
    
    // Errors
    error LockNotFound(bytes32 lockId);
    error LockNotExpired(bytes32 lockId, uint256 currentTime, uint256 unlockTime);
    error Unauthorized(address caller, address owner);
    error InvalidUnlockTime(uint256 unlockTime);
    error AlreadyUnlocked(bytes32 lockId);
}