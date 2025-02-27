// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "../access/UserRoles.sol"; // Import your UserRoles contract;

/**
 * @title ChainlinkConsumer
 * @author Michael
 * @dev Fetches price data from Chainlink oracles with role-based access control.
 */
contract ChainlinkConsumer {
    // Reference to the UserRoles contract for access control
    UserRoles internal userRoles;
    
    // Mapping from asset symbol to price feed
    mapping(string => AggregatorV3Interface) public priceFeeds;
    // Mapping from asset symbol to maximum staleness period (in seconds)
    mapping(string => uint256) public stalenessThresholds;
    // Mapping from asset symbol to decimals
    mapping(string => uint8) public decimals;
    
    event PriceFeedAdded(string symbol, address feed, uint8 feedDecimals);
    event PriceUpdated(string indexed symbol, int256 price, uint256 timestamp, address updatedBy);
    event StalenessThresholdUpdated(string symbol, uint256 threshold);
    
    /**
     * @notice Sets up the Chainlink consumer with access control
     * @param _userRoles The address of the UserRoles contract
     * @param _initialFeed The address of the initial Chainlink price feed (optional, can be address(0))
     * @param _symbol The symbol for the initial feed (if provided)
     * @param _threshold The staleness threshold for the initial feed (if provided)
     */
    constructor(
        address _userRoles,
        address _initialFeed,
        string memory _symbol,
        uint256 _threshold
    ) {
        require(_userRoles != address(0), "ChainlinkConsumer: Invalid UserRoles address");
        userRoles = UserRoles(_userRoles);
        
        // Set up initial feed if provided
        if (_initialFeed != address(0)) {
            _addPriceFeed(_symbol, _initialFeed, _threshold);
        }
    }
    
    /**
     * @dev Modifier to restrict function access to admins only
     */
    modifier onlyAdmin() {
        require(
            userRoles.hasRole(userRoles.ADMIN_ROLE(), msg.sender) || 
            userRoles.hasRole(userRoles.DEFAULT_ADMIN_ROLE(), msg.sender),
            "ChainlinkConsumer: Caller is not an admin"
        );
        _;
    }
    
    /**
     * @dev Internal function to add a price feed
     */
    function _addPriceFeed(string memory symbol, address feedAddress, uint256 threshold) internal {
        require(feedAddress != address(0), "ChainlinkConsumer: Invalid price feed address");
        require(threshold > 0, "ChainlinkConsumer: Staleness threshold must be positive");
        
        AggregatorV3Interface feed = AggregatorV3Interface(feedAddress);
        priceFeeds[symbol] = feed;
        stalenessThresholds[symbol] = threshold;
        decimals[symbol] = feed.decimals();
        
        emit PriceFeedAdded(symbol, feedAddress, feed.decimals());
        emit StalenessThresholdUpdated(symbol, threshold);
    }
    
    /**
     * @notice Adds a new price feed for an asset - admin only
     * @param symbol The symbol of the asset
     * @param feedAddress The address of the Chainlink price feed
     * @param threshold The maximum allowed staleness period in seconds
     */
    function addPriceFeed(string memory symbol, address feedAddress, uint256 threshold) 
        external 
        onlyAdmin 
    {
        _addPriceFeed(symbol, feedAddress, threshold);
    }
    
    /**
     * @notice Updates the staleness threshold for an asset - admin only
     * @param symbol The symbol of the asset
     * @param threshold The new staleness threshold in seconds
     */
    function updateStalenessThreshold(string memory symbol, uint256 threshold) 
        external 
        onlyAdmin 
    {
        require(address(priceFeeds[symbol]) != address(0), "ChainlinkConsumer: Price feed not found");
        require(threshold > 0, "ChainlinkConsumer: Staleness threshold must be positive");
        
        stalenessThresholds[symbol] = threshold;
        emit StalenessThresholdUpdated(symbol, threshold);
    }
    
    /**
     * @notice Fetches the latest price from the Chainlink oracle
     * @param symbol The symbol of the asset
     * @return price The latest price
     * @return timestamp The timestamp of the latest price update
     * @return decimalsValue The number of decimal places in the price
     */
    function getLatestPrice(string memory symbol) 
        public 
        view 
        returns (int256 price, uint256 timestamp, uint8 decimalsValue) 
    {
        AggregatorV3Interface feed = priceFeeds[symbol];
        require(address(feed) != address(0), "ChainlinkConsumer: Price feed not found");
        
        (
            uint80 roundID,
            int256 latestPrice,
            ,
            uint256 latestTimestamp,
            uint80 answeredInRound
        ) = feed.latestRoundData();
        
        require(answeredInRound >= roundID, "ChainlinkConsumer: Data from stale round");
        require(block.timestamp - latestTimestamp <= stalenessThresholds[symbol], "ChainlinkConsumer: Data is stale");
        require(latestPrice > 0, "ChainlinkConsumer: Invalid price");
        
        return (latestPrice, latestTimestamp, decimals[symbol]);
    }
    
    /**
     * @notice Fetches the latest normalized price (converted to 18 decimals)
     * @param symbol The symbol of the asset
     * @return normalizedPrice The price normalized to 18 decimal places
     */
    function getNormalizedPrice(string memory symbol) external view returns (int256 normalizedPrice) {
        (int256 price, , uint8 decimalsValue) = getLatestPrice(symbol);
        
        if (decimalsValue < 18) {
            normalizedPrice = price * int256(10 ** (18 - decimalsValue));
        } else if (decimalsValue > 18) {
            normalizedPrice = price / int256(10 ** (decimalsValue - 18));
        } else {
            normalizedPrice = price;
        }
    }
    
    /**
     * @notice Fetches the latest price and emits an event - admin only
     * @param symbol The symbol of the asset
     */
    function updatePrice(string memory symbol) external onlyAdmin {
        (int256 price, uint256 timestamp, ) = getLatestPrice(symbol);
        emit PriceUpdated(symbol, price, timestamp, msg.sender);
    }
    
    /**
     * @notice Batch update multiple prices - admin only
     * @param symbols Array of asset symbols to update
     */
    function batchUpdatePrices(string[] calldata symbols) external onlyAdmin {
        for (uint256 i = 0; i < symbols.length; i++) {
            (int256 price, uint256 timestamp, ) = getLatestPrice(symbols[i]);
            emit PriceUpdated(symbols[i], price, timestamp, msg.sender);
        }
    }
}