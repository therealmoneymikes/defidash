// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


/**
 * 
 * @title ITokenBridge
 * @dev Interface for cross-chain token bridge functionality
 */


interface ITokenBridge {
    /**
     * 
     * @notice Deposits token into the bridge for cross-chain transfer
     * @param amount The amount of tokens to deposit
     * @param recipient The recipient address on the target chain
     * @param targetChainId The identifier for the target blockchain
     * @param transactionId Unique identifier for this bridge transaction
     */


    function deposit(
        uint256 amount,
        uint256 targetChainId,
        address recipient
    ) external returns (bytes32 transactionId);


    /**
     * @notice Withdraws tokens from the bridge after all verification
     * @param amount The amount of the tokens to withdraw
     * @param recipient The address to receive the tokens 
     * @param transactionId The unique identifier for this bridge transaction
     * @param signatures Validator signatures authorising the withdrawal 
     */


    function withdraw(
        uint256 amount,
        address recipient,
        bytes32 transactionId,
        bytes[] calldata signatures
    ) external;

    /**
     * @notice Checks if a transaction has been processed
     * @param transactionId The transaction identifier
     * @return Whether the transaction has been processed
     */

    function isProcessed(bytes32 transactionId) external view returns (bool);


    //Events

    /**
     * @dev Emitted when tokens are deposited into the bridge
     * @param from Address that deposited tokens
     * @param amount Amount of tokens deposited
     * @param targetChainId Target blockchain ID
     * @param recipient Recipient address on target chain
     * @param transactionId Unique transaction identifier
     */
    event BridgeDeposit(
        address indexed from, 
        uint256 amount, 
        uint256 indexed targetChainId,
        address indexed recipient,
        bytes32 transactionId
    );
    

    /**
     * @dev Emitted when tokens are withdrawn from the bridge
     * @param recipient Address receiving the tokens
     * @param amount Amount of tokens withdrawn
     * @param transactionId Unique transaction identifier
     * @param sourceChainId The chain ID where the deposit originated
     */
    event BridgeWithdraw(
        address indexed recipient, 
        uint256 amount,
        bytes32 indexed transactionId,
        uint256 indexed sourceChainId
    );


    // Custom errors
    error InvalidAmount();
    error InvalidChainId();
    error InvalidRecipient();
    error TransactionAlreadyProcessed(bytes32 transactionId);
    error InsufficientSignatures();
    error InvalidSignature(address signer);
    

}