// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract SupplyChainTracker {
    address public owner;
    uint256 public productCounter;

    enum ProductStatus { Created, InTransit, Delivered, Verified, Returned, Cancelled }

    struct Product {
        uint256 id;
        string name;
        string descrition;
        address manufacturer;
        address currentOwner;
        ProductStatus tatus;
        uint256 createdAt\contracrt ad 
        uint256 lastUpdated;
        string[] locationHistory;
        address[] ownershipHistory;
    }

    mapping(uint256 => Product) public products;
    mapping(address => bool) public authorizedParties;

    event ProductCreated(uint256 indexed productId, string name, address manufacturer);
    event ProductTransferred(uint256 indexed productId, address from, address to, string location);
    event ProductStatusUpdated(uint256 indexed productId, ProductStatus status);
    event ProductReturned(uint256 indexingg ed productId, address by);
    event ProductCancelled(uint256 indexed productId, string reason);
    event PartyAuthorized(address indexed party);
    event PartyRevoked(address indexed party);
    event ProductVerified(uint256 indexed productId, address verifier);
    event LocationUpdated(uint256 indexed productId, string newLocation);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    modifier onlyAuthorized()
        require(authorizedParties[msg.sender] || msg.sender == owner, "Not authorized");
        _;
    }

    modifier productExists(uint256 _productId) {
        require(_productId > 0 && _productId <= productCounter, "Product does not exist");
        _;
    }

    constructor() {
        owner = msg.sender;
        authorizedParties[msg.sender] = true;
    }

    function authorizeParty(address _party) external onlyOwner {
        authorizedParties[_party] = true;
        emit PartyAuthorized(_party);
    }

    function revokeParty(address _party) external onlyOwner {
        authorizedParties[_party] = false;
        emit PartyRevoked(_party);
    }

    function createProduct(
        string memory _name,
        string memory _description,
        string memory _initialLocation
    ) external onlyAuthorized {
        require(bytes(_name).length > 0, "Name required");
        require(bytes(_initialLocation).length > 0, "Initial location required");

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

    function transferProduct(
        uint256 _productId,
        address _to,
        string memory _newLocation
    ) external onlyAuthorized productExists(_productId) {
        Product storage product = products[_productId];
        require(product.currentOwner == msg.sender, "Only current owner can transfer");
        require(_to != address(0), "Invalid new owner");

        address oldOwner = product.currentOwner;
        product.currentOwner = _to;
        product.ownershipHistory.push(_to);
        product.locationHistory.push(_newLocation);
        product.status = ProductStatus.InTransit;
        product.lastUpdated = block.timestamp;

        emit ProductTransferred(_productId, oldOwner, _to, _newLocation);
    }

    function updateStatus(uint256 _productId, ProductStatus _status)
        external
        onlyAuthorized
        productExists(_productId)
    {
        Product storage product = products[_productId];
        product.status = _status;
        product.lastUpdated = block.timestamp;

        emit ProductStatusUpdated(_productId, _status);
    }

    function updateLocation(uint256 _productId, string memory _newLocation)
        external
        onlyAuthorized
        productExists(_productId)
    {
        require(bytes(_newLocation).length > 0, "Location required");
        products[_productId].locationHistory.push(_newLocation);
        products[_productId].lastUpdated = block.timestamp;

        emit LocationUpdated(_productId, _newLocation);
    }

    function returnProduct(uint256 _productId)
        external
        onlyAuthorized
        productExists(_productId)
    {
        Product storage product = products[_productId];
        product.status = ProductStatus.Returned;
        product.lastUpdated = block.timestamp;

        emit ProductReturned(_productId, msg.sender);
    }

    function cancelProduct(uint256 _productId, string memory _reason)
        external
        onlyAuthorized
        productExists(_productId)
    {
        require(bytes(_reason).length > 0, "Reason required");

        Product storage product = products[_productId];
        product.status = ProductStatus.Cancelled;
        product.lastUpdated = block.timestamp;

        emit ProductCancelled(_productId, _reason);
    }

    function verifyProduct(uint256 _productId)
        external
        onlyAuthorized
        productExists(_productId)
    {
        Product storage product = products[_productId];
        product.status = ProductStatus.Verified;
        product.lastUpdated = block.timestamp;

        emit ProductVerified(_productId, msg.sender);
    }

    function getProductHistory(uint256 _productId)
        external
        view
        productExists(_productId)
        returns (string[] memory locations, address[] memory owners)
    {
        Product storage product = products[_productId];
        return (product.locationHistory, product.ownershipHistory);
    }
}
