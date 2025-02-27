// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ITokenMinter
 * @dev Interface for minting and burning tokens in a cross-chain bridge system
 * @author Michael Roberts
 */
interface ITokenMinter {
    /**
     * @notice Mints new tokens to the specified account
     * @param account The address that will receive the minted tokens
     * @param amount The number of tokens to mint
     * @param originChainId The chain ID where the request originated
     * @param nonce A unique identifier for this mint operation
     * @return success Whether the mint operation was successful
     */
    function mint(
        address account, 
        uint256 amount,
        uint256 originChainId,
        uint256 nonce
    ) external returns (bool success);

    /**
     * @notice Burns tokens from the specified account
     * @param account The address from which tokens will be burned
     * @param amount The number of tokens to burn
     * @param targetChainId The chain ID where tokens will be minted
     * @param nonce A unique identifier for this burn operation
     * @return success Whether the burn operation was successful
     */
    function burn(
        address account, 
        uint256 amount,
        uint256 targetChainId,
        uint256 nonce
    ) external returns (bool success);
    
    /**
     * @notice Checks if a specific minting operation has been processed
     * @param originChainId Chain ID where the request originated
     * @param nonce Unique identifier for the operation
     * @return Whether the operation has been processed
     */
    function isMintProcessed(uint256 originChainId, uint256 nonce) external view returns (bool);
    
    /**
     * @notice Checks if a specific burning operation has been processed
     * @param targetChainId Chain ID where tokens will be minted
     * @param nonce Unique identifier for the operation
     * @return Whether the operation has been processed
     */
    function isBurnProcessed(uint256 targetChainId, uint256 nonce) external view returns (bool);
    
    /**
     * @notice Returns the total amount minted minus burned (total supply)
     * @return The current total supply
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Emitted when tokens are minted
     * @param to Address receiving the minted tokens
     * @param amount Amount of tokens minted
     * @param originChainId Chain ID where the request originated
     * @param nonce Unique identifier for this operation
     * @param executor Address that executed the mint
     */
    event Mint(
        address indexed to, 
        uint256 amount,
        uint256 indexed originChainId,
        uint256 nonce,
        address indexed executor
    );
    
    /**
     * @dev Emitted when tokens are burned
     * @param from Address from which tokens are burned
     * @param amount Amount of tokens burned
     * @param targetChainId Chain ID where tokens will be minted
     * @param nonce Unique identifier for this operation
     * @param executor Address that executed the burn
     */
    event Burn(
        address indexed from, 
        uint256 amount,
        uint256 indexed targetChainId,
        uint256 nonce,
        address indexed executor
    );
    
    // Custom errors
    error Unauthorized(address caller);
    error InsufficientBalance(address account, uint256 required, uint256 available);
    error OperationAlreadyProcessed(uint256 chainId, uint256 nonce);
    error MintingCapExceeded(uint256 amount, uint256 remainingCap);
    error InvalidAmount();
}