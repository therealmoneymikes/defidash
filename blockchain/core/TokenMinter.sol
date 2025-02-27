// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../access/Multisig.sol";


/**
 * @title Token Burning Contract
 * @author Michael Roberts
 * 
 */
interface IBurnable {
    function burn(uint256 amount) external;
}

contract TokenMinter is Pausable, ReentrancyGuard, MultisigControl {
    using SafeERC20 for IERC20;

    struct TokenConfig {
        bool isSupported;
        bool isBurnable;
        uint96 fee;
    }

    mapping(address => TokenConfig) private _tokenConfigs;
    uint256 private _mintNonce;

    event TokenMinted(address indexed recipient, address indexed token, uint256 amount, bytes32 operation);
    event TokenBurned(address indexed user, address indexed token, uint256 amount);
    event TokenSupportUpdated(address indexed token, bool isSupported);

    constructor(address[] memory signers, uint256 requiredApprovals)
        MultisigControl(signers, requiredApprovals)
    {
        require(requiredApprovals <= signers.length, "Invalid threshold");
        require(signers.length >= 3, "Min 3 signers");
    }

    function mint(address recipient, address token, uint256 amount)
        external
        nonReentrant
        validRecipient(recipient)
    {
        bytes32 operation = keccak256(abi.encode(
            block.chainid,
            "MINT",
            recipient,
            token,
            amount,
            _mintNonce++
        ));

        if (!_isApproved(operation)) {
            _approveOperation(operation);
            return;
        }

        _executeMint(recipient, token, amount, operation);
    }

    function _executeMint(address recipient, address token, uint256 amount, bytes32 operation) private {
        TokenConfig memory config = _tokenConfigs[token];
        require(config.isSupported, "Unsupported");
        
        delete _approvals[operation];
        IERC20(token).safeTransfer(recipient, amount);
        
        emit TokenMinted(recipient, token, amount, operation);
    }

    function burn(address token, uint256 amount) external nonReentrant {
        TokenConfig memory config = _tokenConfigs[token];
        require(config.isSupported && config.isBurnable, "Non-burnable");
        require(amount > 0, "Invalid amount");

        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        require(IERC20(token).balanceOf(address(this)) == balanceBefore + amount, "Deflationary");
        
        IBurnable(token).burn(amount);
        emit TokenBurned(msg.sender, token, amount);
    }

    function configureToken(address token, bool isSupported, bool isBurnable, uint96 fee)
        external
        onlyMultisig
    {
        require(token != address(0), "Zero address");
        _tokenConfigs[token] = TokenConfig(isSupported, isBurnable, fee);
        emit TokenSupportUpdated(token, isSupported);
    }

    modifier validRecipient(address recipient) {
        assembly {
            if iszero(recipient) {
                mstore(0x00, 0xeb8ac921)
                revert(0x1c, 0x04)
            }
        }
        _;
    }
}