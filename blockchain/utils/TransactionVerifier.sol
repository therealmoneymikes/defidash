// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title TransactionVerifier
 * @author Michael Roberts
 * @dev Utility contract to verify and validate off-chain signed transactions.
 */
contract TransactionVerifier {
    // Custom errors for gas efficiency
    error InvalidSigner();
    error InvalidSignatureLength();
    error InvalidSignatureValues();
    error ExpiredSignature();
    error UsedSignature();
    
    // Mapping to track used signatures to prevent replay attacks
    mapping(bytes32 => bool) private _usedSignatures;
    
    // Curve order for EIP-2 validation
    uint256 private constant _HALF_CURVE_ORDER = 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0;
    
    event TransactionVerified(address indexed signer, bytes32 indexed messageHash, uint256 timestamp);
    
    /**
     * @notice Verifies if a transaction was signed by the expected signer and records usage.
     * @param signer The expected signer of the message.
     * @param messageHash The hash of the message being verified.
     * @param signature The ECDSA signature.
     * @param deadline Optional timestamp after which the signature is invalid (0 for no deadline).
     * @return True if the signature is valid and was signed by `signer`, otherwise false.
     */
    function verifyAndRecordSignature(
        address signer,
        bytes32 messageHash,
        bytes calldata signature,
        uint256 deadline
    ) external returns (bool) {
        // Check deadline
        if (deadline > 0 && block.timestamp > deadline) {
            revert ExpiredSignature();
        }
        
        // Check if signature was already used
        bytes32 signatureHash = keccak256(abi.encodePacked(messageHash, signature));
        if (_usedSignatures[signatureHash]) {
            revert UsedSignature();
        }
        
        // Verify signature
        bool isValid = _verifySignature(signer, messageHash, signature);
        
        if (isValid) {
            // Record signature as used
            _usedSignatures[signatureHash] = true;
            emit TransactionVerified(signer, messageHash, block.timestamp);
        }
        
        return isValid;
    }
    
    /**
     * @notice Verifies if a transaction was signed by the expected signer (view-only version).
     * @param signer The expected signer of the message.
     * @param messageHash The hash of the message being verified.
     * @param signature The ECDSA signature.
     * @return True if the signature is valid and was signed by `signer`, otherwise false.
     */
    function verifySignature(
        address signer,
        bytes32 messageHash,
        bytes calldata signature
    ) public pure returns (bool) {
        return _verifySignature(signer, messageHash, signature);
    }
    
    /**
     * @notice Internal pure function to verify signature.
     */
    function _verifySignature(
        address signer,
        bytes32 messageHash,
        bytes memory signature
    ) internal pure returns (bool) {
        if (signer == address(0)) revert InvalidSigner();
        
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        address recoveredSigner = recoverSigner(ethSignedMessageHash, signature);
        
        return recoveredSigner == signer;
    }

    /**
     * @notice Generates an Ethereum Signed Message hash.
     * @param messageHash The original message hash.
     * @return The hashed message formatted as per EIP-191.
     */
    function getEthSignedMessageHash(bytes32 messageHash) public pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
    }

    /**
     * @notice Recovers the address of the signer from a signature.
     * @param ethSignedMessageHash The Ethereum signed message hash.
     * @param signature The ECDSA signature.
     * @return The address of the signer.
     */
    function recoverSigner(bytes32 ethSignedMessageHash, bytes memory signature)
        public
        pure
        returns (address)
    {
        if (signature.length != 65) revert InvalidSignatureLength();

        bytes32 r;
        bytes32 s;
        uint8 v;
        
        // Extract r, s, and v from the signature
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }
        
        // EIP-2: s should be in the lower half of the curve order
        if (uint256(s) > _HALF_CURVE_ORDER) revert InvalidSignatureValues();
        
        // EIP-155 compatibility
        if (v < 27) {
            v += 27;
        }
        
        if (v != 27 && v != 28) revert InvalidSignatureValues();
        
        address signer = ecrecover(ethSignedMessageHash, v, r, s);
        if(signer == address(0)) revert InvalidSignatureValues();
        
        return signer;
    }
    
    /**
     * @notice Checks if a signature has been used.
     * @param messageHash The hash of the message.
     * @param signature The signature.
     * @return True if the signature has been used before.
     */
    function isSignatureUsed(bytes32 messageHash, bytes calldata signature) external view returns (bool) {
        bytes32 signatureHash = keccak256(abi.encodePacked(messageHash, signature));
        return _usedSignatures[signatureHash];
    }
}