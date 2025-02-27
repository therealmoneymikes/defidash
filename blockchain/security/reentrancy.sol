// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Import OpenZeppelin's ReentrancyGuard
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title SecureContract
 * @dev Example contract demonstrating the use of OpenZeppelin's ReentrancyGuard.
 * @author Michael Roberts
 */
contract SecureContract is ReentrancyGuard {
    // State variable to track balances
    mapping(address => uint256) private _balances;

    /**
     * @dev Deposit funds into the contract.
     * This function is protected against reentrancy attacks.
     */
    function deposit() external payable nonReentrant {
        require(msg.value > 0, "Deposit value must be greater than 0");
        _balances[msg.sender] += msg.value;
    }

    /**
     * @dev Withdraw funds from the contract.
     * This function is protected against reentrancy attacks.
     */
    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0, "Withdrawal amount must be greater than 0");
        require(_balances[msg.sender] >= amount, "Insufficient balance");

        // Update balance before transferring funds
        _balances[msg.sender] -= amount;

        // Transfer funds to the caller
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
    }

    /**
     * @dev Get the balance of a specific address.
     */
    function getBalance(address account) external view returns (uint256) {
        return _balances[account];
    }
}