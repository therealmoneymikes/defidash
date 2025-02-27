// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ChainlinkConsumer.sol";
import "../access/UserRoles.sol";

/**
 * @title PriceOracle
 * @dev A contract that aggregates price data from multiple sources, including Chainlink.
 * Provides a unified interface for price data across the protocol.
 */
contract PriceOracle {
    ChainlinkConsumer public chainlinkConsumer;
    UserRoles public userRoles;
    
    // Cache mechanism to reduce external calls
    mapping(string => PriceData) private priceCache;
    
    // Heartbeat settings for each asset
    mapping(string => uint256) public heartbeats;
    
    struct PriceData {
        int256 price;
        uint256 timestamp;
        uint8 decimals;
    }
    
    event PriceFetched(string indexed symbol, int256 price, uint256 timestamp);
    event PriceUpdated(string indexed symbol, int256 oldPrice, int256 newPrice, address updatedBy);
    event ChainlinkConsumerUpdated(address indexed oldConsumer, address indexed newConsumer);
    event HeartbeatUpdated(string indexed symbol, uint256 heartbeat);
    
    /**
     * @dev Modifier to restrict function access to admins
     */
    modifier onlyAdmin() {
        require(
            userRoles.hasRole(userRoles.ADMIN_ROLE(), msg.sender) || 
            userRoles.hasRole(userRoles.DEFAULT_ADMIN_ROLE(), msg.sender),
            "PriceOracle: Caller is not an admin"
        );
        _;
    }
    
    /**
     * @notice Initializes the PriceOracle with a ChainlinkConsumer and UserRoles.
     * @param _chainlinkConsumer Address of the ChainlinkConsumer contract.
     * @param _userRoles Address of the UserRoles contract.
     */
    constructor(address _chainlinkConsumer, address _userRoles) {
        require(_chainlinkConsumer != address(0), "PriceOracle: Invalid ChainlinkConsumer address");
        require(_userRoles != address(0), "PriceOracle: Invalid UserRoles address");
        
        chainlinkConsumer = ChainlinkConsumer(_chainlinkConsumer);
        userRoles = UserRoles(_userRoles);
    }
    
    /**
     * @notice Fetches the latest price from Chainlink for a specific asset.
     * @param symbol The symbol of the asset to fetch the price for.
     * @return price The latest price from Chainlink.
     * @return timestamp The timestamp of the last update.
     * @return decimals The number of decimals in the price.
     */
    function getLatestPrice(string memory symbol) 
        public 
        view 
        returns (int256 price, uint256 timestamp, uint8 decimals) 
    {
        return chainlinkConsumer.getLatestPrice(symbol);
    }
    
    /**
     * @notice Fetches the normalized price (18 decimals) for a specific asset.
     * @param symbol The symbol of the asset to fetch the price for.
     * @return normalizedPrice The price normalized to 18 decimal places.
     */
    function getNormalizedPrice(string memory symbol) 
        public 
        view 
        returns (int256 normalizedPrice) 
    {
        return chainlinkConsumer.getNormalizedPrice(symbol);
    }
    
    /**
     * @notice Updates and caches the price for a specific asset.
     * @param symbol The symbol of the asset to update.
     * @return success Whether the operation was successful.
     */
    function updatePrice(string memory symbol) public onlyAdmin returns (bool success) {
        // Fetch current cached price
        PriceData storage cachedData = priceCache[symbol];
        int256 oldPrice = cachedData.price;
        
        // Get new price data
        (int256 newPrice, uint256 timestamp, uint8 decimalsValue) = getLatestPrice(symbol);
        
        // Update cache
        cachedData.price = newPrice;
        cachedData.timestamp = timestamp;
        cachedData.decimals = decimalsValue;
        
        emit PriceUpdated(symbol, oldPrice, newPrice, msg.sender);
        emit PriceFetched(symbol, newPrice, timestamp);
        
        return true;
    }
    
    /**
     * @notice Batch updates prices for multiple assets.
     * @param symbols Array of asset symbols to update.
     * @return successCount The number of successful updates.
     */
    function batchUpdatePrices(string[] calldata symbols) 
        external 
        onlyAdmin 
        returns (uint256 successCount) 
    {
        for (uint256 i = 0; i < symbols.length; i++) {
            if (updatePrice(symbols[i])) {
                successCount++;
            }
        }
    }
    
    /**
     * @notice Gets the cached price for an asset, updating it if necessary.
     * @param symbol The symbol of the asset.
     * @param forceUpdate Whether to force an update regardless of the heartbeat.
     * @return price The latest price.
     * @return timestamp The timestamp of the price.
     * @return decimals The number of decimals in the price.
     */
    function getPriceWithCache(string memory symbol, bool forceUpdate) 
        external 
        returns (int256 price, uint256 timestamp, uint8 decimals) 
    {
        PriceData storage cachedData = priceCache[symbol];
        uint256 heartbeat = heartbeats[symbol];
        
        // Check if cache needs update
        bool needsUpdate = forceUpdate || 
                          cachedData.timestamp == 0 || 
                          (heartbeat > 0 && block.timestamp > cachedData.timestamp + heartbeat);
        
        if (needsUpdate && userRoles.hasRole(userRoles.ADMIN_ROLE(), msg.sender)) {
            updatePrice(symbol);
        }
        
        return (cachedData.price, cachedData.timestamp, cachedData.decimals);
    }
    
    /**
     * @notice Sets the heartbeat interval for an asset.
     * @param symbol The symbol of the asset.
     * @param heartbeat The heartbeat interval in seconds (0 to disable).
     */
    function setHeartbeat(string memory symbol, uint256 heartbeat) external onlyAdmin {
        heartbeats[symbol] = heartbeat;
        emit HeartbeatUpdated(symbol, heartbeat);
    }
    
    /**
     * @notice Updates the ChainlinkConsumer contract.
     * @param _newChainlinkConsumer The new ChainlinkConsumer contract address.
     */
    function updateChainlinkConsumer(address _newChainlinkConsumer) external onlyAdmin {
        require(_newChainlinkConsumer != address(0), "PriceOracle: Invalid address");
        
        address oldConsumer = address(chainlinkConsumer);
        chainlinkConsumer = ChainlinkConsumer(_newChainlinkConsumer);
        
        emit ChainlinkConsumerUpdated(oldConsumer, _newChainlinkConsumer);
    }
    
    /**
     * @notice Checks if a cached price is fresh according to the heartbeat.
     * @param symbol The symbol of the asset.
     * @return isFresh Whether the price is considered fresh.
     */
    function isPriceFresh(string memory symbol) public view returns (bool isFresh) {
        PriceData storage cachedData = priceCache[symbol];
        uint256 heartbeat = heartbeats[symbol];
        
        // If heartbeat is 0, no freshness requirement
        if (heartbeat == 0) return true;
        
        // Check if price exists and is within heartbeat period
        return cachedData.timestamp > 0 && 
               block.timestamp <= cachedData.timestamp + heartbeat;
    }
}

