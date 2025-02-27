// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

/**
 * 
 * @title IERC20 Interface
 * @dev ERC20 token interface 
 */


interface IERC20 {

    /**
     * 
     * @dev Returns the total token supply.
     */

    function totalSupply() external view returns (uint256);

    /**
     * 
     * @dev Returns the token balance for a given account
     * @param account Address to query balance for
     * @return Token balance of the account
     * 
     */

    function balanceOf(address account) external view returns (uint256);
    /**
     * @dev Trasnfer tokens from the contract caller to the sender
     * @param recipient Address receiving the tokens
     * @param amount Amount of tokens to transfer
     * @return Boolean indicating if the transfer was successful
     */
    function transfer(address recipient, uint256 amount) external returns (bool);
    /**
     * @dev Returns remaining allowance for spender from owner.
     * @param owner Address that approved the allowance
     * @param spender Address authorised to spend the tokens
     * @return Remaining token allowance
     */

    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Set allowance for spender to spend caller's tokens
     * @param spender Address of the authorised spender
     * @param amount Amount of tokens authorized
     * @return Boolean indicating if the approval was successful  
     */

    function approve(address spender, uint256 amount) external returns (bool);
    /**
     * 
     * @dev Transfer tokens from sender to recipient using the allowance mechanism
     * @param sender Address sending the tokens
     * @param recipient Address receiving the tokens
     * @param amount Amount of tokens to transfer
     * @return Boolean indicating if the transfer was successful
     */

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * 
     * @dev Returns the name of the token
     */

    function name() external view returns (string memory);

    /**
     * 
     * @dev Returns the decimals of the token (Default is 18)
     */

    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals of the token.
     */

    function decimals() external view returns (uint8);

    /**
     * @dev Decimals is emitted when tokens are transferred
     */


    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when allowance is set.
     * 
     */

    event Approval(address indexed owner, address indexed spender, uint256 value);


    //Custom errors for better gas efficiency
    error InsufficientBalance(address account, uint256 required, uint256 available);
    error InsufficientAllowance(address spender, uint256 required, uint256 available);

}