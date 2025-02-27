// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../access/Pausable.sol";
import "../access/Multisig.sol";
import "../interfaces/ITokenBridge.sol";
import "../interfaces/IERC20.sol";
import "../security/Reentrancy.sol";
import "../core/BridgeStorage.sol";
import "../core/TokenLocker.sol";
import "../core/TokenMinter.sol";
import "../security/TimeLock.sol";
import "../utils/TransactionVerifier.sol";

/**
 * @title Bridge
 * @dev Main contract for cross-chain token transfers.
 */
contract Bridge is IBridge, Reentrancy, Pausable, MultisigControl, TimeLock, TransactionVerifier {
    TokenLocker public tokenLocker;
    TokenMinter public tokenMinter;
    BridgeStorage public bridgeStorage;

    event TokenLocked(address indexed user, address indexed token, uint256 amount, uint256 destinationChain);
    event TokenUnlocked(address indexed user, address indexed token, uint256 amount);
    event TokenMinted(address indexed user, address indexed token, uint256 amount);
    event TokenBurned(address indexed user, address indexed token, uint256 amount);
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);

    /**
     * @notice Initializes the bridge contract with required components.
     * @param _tokenLocker Address of the TokenLocker contract.
     * @param _tokenMinter Address of the TokenMinter contract.
     * @param _bridgeStorage Address of the BridgeStorage contract.
     */
    constructor(
        address _tokenLocker,
        address _tokenMinter,
        address _bridgeStorage
    ) {
        require(_tokenLocker != address(0), "Bridge: Invalid TokenLocker address");
        require(_tokenMinter != address(0), "Bridge: Invalid TokenMinter address");
        require(_bridgeStorage != address(0), "Bridge: Invalid BridgeStorage address");

        tokenLocker = TokenLocker(_tokenLocker);
        tokenMinter = TokenMinter(_tokenMinter);
        bridgeStorage = BridgeStorage(_bridgeStorage);
    }

    /**
     * @notice Locks tokens on the source chain for cross-chain transfer.
     * @param token Address of the ERC20 token.
     * @param amount Amount of tokens to lock.
     * @param destinationChain ID of the destination chain.
     */
    function lockTokens(address token, uint256 amount, uint256 destinationChain) external whenNotPaused nonReentrant {
        require(amount > 0, "Bridge: Amount must be greater than zero");
        IERC20(token).transferFrom(msg.sender, address(tokenLocker), amount);
        tokenLocker.lockTokens(msg.sender, token, amount);

        emit TokenLocked(msg.sender, token, amount, destinationChain);
    }

    /**
     * @notice Unlocks tokens that were locked on this chain.
     * @param token Address of the ERC20 token.
     * @param amount Amount of tokens to unlock.
     * @param signature A signature proving the unlock request is valid.
     */
    function unlockTokens(address token, uint256 amount, bytes memory signature) external whenNotPaused nonReentrant {
        bytes32 messageHash = keccak256(abi.encodePacked(msg.sender, token, amount));
        require(verifySignature(admin(), messageHash, signature), "Bridge: Invalid unlock signature");

        tokenLocker.unlockTokens(msg.sender, token, amount);
        IERC20(token).transfer(msg.sender, amount);

        emit TokenUnlocked(msg.sender, token, amount);
    }

    /**
     * @notice Mints tokens on the destination chain.
     * @param token Address of the ERC20 token.
     * @param amount Amount of tokens to mint.
     * @param signature A signature verifying the mint request.
     */
    function mintTokens(address token, uint256 amount, bytes memory signature) external whenNotPaused nonReentrant {
        bytes32 messageHash = keccak256(abi.encodePacked(msg.sender, token, amount));
        require(verifySignature(admin(), messageHash, signature), "Bridge: Invalid mint signature");

        tokenMinter.mintTokens(msg.sender, token, amount);
        emit TokenMinted(msg.sender, token, amount);
    }

    /**
     * @notice Burns tokens on the source chain before transferring to another chain.
     * @param token Address of the ERC20 token.
     * @param amount Amount of tokens to burn.
     */
    function burnTokens(address token, uint256 amount) external whenNotPaused nonReentrant {
        require(amount > 0, "Bridge: Amount must be greater than zero");

        tokenMinter.burnTokens(msg.sender, token, amount);
        emit TokenBurned(msg.sender, token, amount);
    }

    /**
     * @notice Allows the admin to change the admin address.
     * @param newAdmin The new admin address.
     */
    function changeAdmin(address newAdmin) external onlyMultisig {
        require(newAdmin != address(0), "Bridge: Invalid admin address");
        emit AdminChanged(admin(), newAdmin);
        setAdmin(newAdmin);
    }
}
