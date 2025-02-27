// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../core/BridgeStorage.sol";

contract TokenLocker is Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    //Bridge Storage Contract
    BridgeStorage private _bridgeStorage;
    // Bridge Operator Address
    address private _bridgeOperator;
    // Mapping of chain address to chains (EVM for now)
    mapping(address => bool) private _validTargetChains;



    event TokensLocked(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 depositId,
        address targetChain
    );
    event TokensUnlocked(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 depositId,
        address sourceChain
    );
    event BridgeStorageUpdated(address newStorage);
    event TargetChainUpdated(address chain, bool isValid);

    //Modifer to ensure only the bridge operator not any caller
    modifier onlyBridgeOperator() {
        require(msg.sender == _bridgeOperator, "TokenLocker: unauthorized");
        _;
    }

    constructor(address storageContract, address bridgeOperator) {
        require(storageContract != address(0), "TokenLocker: invalid storage");
        require(bridgeOperator != address(0), "TokenLocker: invalid operator");
        _bridgeStorage = BridgeStorage(storageContract);
        _bridgeOperator = bridgeOperator;
    }

    function lockTokens(
        address token,
        uint256 amount,
        address targetChain
    ) external nonReentrant whenNotPaused {
        require(amount > 0, "TokenLocker: zero amount");
        require(_validTargetChains[targetChain], "TokenLocker: invalid chain");
        
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        uint256 depositId = _bridgeStorage.createDeposit(
            msg.sender,
            token,
            amount,
            targetChain
        );

        emit TokensLocked(msg.sender, token, amount, depositId, targetChain);
    }

    function unlockTokens(
        uint256 depositId,
        address sourceChain
    ) external nonReentrant onlyBridgeOperator {
        BridgeStorage.DepositInfo memory deposit = _bridgeStorage.getDeposit(depositId);
        require(!deposit.withdrawn, "TokenLocker: already withdrawn");
        require(_validTargetChains[sourceChain], "TokenLocker: invalid source");

        _bridgeStorage.markWithdrawn(depositId);
        IERC20(deposit.token).safeTransfer(deposit.depositor, deposit.amount);

        emit TokensUnlocked(
            deposit.depositor,
            deposit.token,
            deposit.amount,
            depositId,
            sourceChain
        );
    }

    // Administrative functions for Bridge Storage Handling
    function updateBridgeStorage(address newStorage) external onlyBridgeOperator {
        require(newStorage != address(0), "TokenLocker: invalid address");
        _bridgeStorage = BridgeStorage(newStorage);
        emit BridgeStorageUpdated(newStorage);
    }

    function setTargetChain(address chain, bool isValid) external onlyBridgeOperator {
        _validTargetChains[chain] = isValid;
        emit TargetChainUpdated(chain, isValid);
    }

    // Emergency Withdraw Function
    function emergencyWithdraw(
        address token,
        address to,
        uint256 amount
    ) external onlyBridgeOperator {
        IERC20(token).safeTransfer(to, amount);
    }
}