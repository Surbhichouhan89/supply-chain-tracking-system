// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract SupplyChainTracker {
    address public owner;
    uint256 public productCounter;
    
    enum ProductStatus { Created, InTransit, Delivered, Verified }
    
    struct Product {
        uint256 id;
        string name;
        string description;
        address manufacturer;
        address currentOwner;
        ProductStatus status;
        uint256 createdAt;
        uint256 lastUpdated;
        string[] locationHistory;
        address[] ownershipHistory;
    }
    
    mapping(uint256 => Product) public products;
    mapping(address => bool) public authorizedParties;
    
    event ProductCreated(uint256 indexed productId, string name, address manufacturer);
    event ProductTransferred(uint256 indexed productId, address from, address to, string location);
    event ProductStatusUpdated(uint256 indexed productId, ProductStatus status);
    event PartyAuthorized(address indexed party);
    event PartyRevoked(address indexed party);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }
    
    modifier onlyAuthorized() {
        require(authorizedParties[msg.sender] || msg.sender == owner, "Not authorized");
        _;
    }
    
    modifier productExists(uint256 _productId) {
        require(_productId <= productCounter && _productId > 0, "Product does not exist");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        authorizedParties[msg.sender] = true;
    }
    
    /**
     * @dev Creates a new product in the supply chain
     * @param _name Product name
     * @param _description Product description
     * @param _initialLocation Initial location of the product
     */
    function createProduct(
        string memory _name,
        string memory _description,
        string memory _initialLocation
    ) external onlyAuthorized {
        productCounter++;
        
        Product storage newProduct = products[productCounter];
        newProduct.id = productCounter;
        newProduct.name = _name;
        newProduct.description = _description;
        newProduct.manufacturer = msg.sender;
        newProduct.currentOwner = msg.sender;
        newProduct.status = ProductStatus.Created;
        newProduct.createdAt = block.timestamp;
        newProduct.lastUpdated = block.timestamp;
        newProduct.locationHistory.push(_initialLocation);
        newProduct.ownershipHistory.push(msg.sender);
        
        emit ProductCreated(productCounter, _name, msg.sender);
    }
    
    /**
     * @dev Transfers product ownership and updates location
     * @param _productId ID of the product to transfer
     * @param _newOwner Address of the new owner
     * @param _location Current location of the product
     */
    function transferProduct(
        uint256 _productId,
        address _newOwner,
        string memory _location
    ) external onlyAuthorized productExists(_productId) {
        Product storage product = products[_productId];
        require(
            product.currentOwner == msg.sender || authorizedParties[msg.sender] || msg.sender == owner,
            "Not authorized to transfer this product"
        );
        require(_newOwner != address(0), "Invalid new owner address");
        
        address previousOwner = product.currentOwner;
        product.currentOwner = _newOwner;
        product.status = ProductStatus.InTransit;
        product.lastUpdated = block.timestamp;
        product.locationHistory.push(_location);
        product.ownershipHistory.push(_newOwner);
        
        emit ProductTransferred(_productId, previousOwner, _newOwner, _location);
    }
    
    /**
     * @dev Updates the status of a product
     * @param _productId ID of the product
     * @param _status New status of the product
     */
    function updateProductStatus(
        uint256 _productId,
        ProductStatus _status
    ) external onlyAuthorized productExists(_productId) {
        Product storage product = products[_productId];
        require(
            product.currentOwner == msg.sender || authorizedParties[msg.sender] || msg.sender == owner,
            "Not authorized to update this product"
        );
        
        product.status = _status;
        product.lastUpdated = block.timestamp;
        
        emit ProductStatusUpdated(_productId, _status);
    }
    
    /**
     * @dev Authorizes a party to interact with the supply chain
     * @param _party Address to authorize
     */
    function authorizeParty(address _party) external onlyOwner {
        require(_party != address(0), "Invalid address");
        authorizedParties[_party] = true;
        emit PartyAuthorized(_party);
    }
    
    /**
     * @dev Revokes authorization from a party
     * @param _party Address to revoke authorization from
     */
    function revokeParty(address _party) external onlyOwner {
        authorizedParties[_party] = false;
        emit PartyRevoked(_party);
    }
    
    /**
     * @dev Returns complete product information
     * @param _productId ID of the product
     */
    function getProduct(uint256 _productId) external view productExists(_productId) returns (
        uint256 id,
        string memory name,
        string memory description,
        address manufacturer,
        address currentOwner,
        ProductStatus status,
        uint256 createdAt,
        uint256 lastUpdated
    ) {
        Product storage product = products[_productId];
        return (
            product.id,
            product.name,
            product.description,
            product.manufacturer,
            product.currentOwner,
            product.status,
            product.createdAt,
            product.lastUpdated
        );
    }
    
    /**
     * @dev Returns the location history of a product
     * @param _productId ID of the product
     */
    function getProductLocationHistory(uint256 _productId) external view productExists(_productId) returns (string[] memory) {
        return products[_productId].locationHistory;
    }
    
    /**
     * @dev Returns the ownership history of a product
     * @param _productId ID of the product
     */
    function getProductOwnershipHistory(uint256 _productId) external view productExists(_productId) returns (address[] memory) {
        return products[_productId].ownershipHistory;
    }
}
