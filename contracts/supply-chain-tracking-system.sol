// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract SupplyChainTracker {
    address public owner;
    uint256 public productCounter;

    // Updated Enum
    enum ProductStatus { Created, InTransit, Delivered, Verified, Returned, Cancelled }

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
    event ProductReturned(uint256 indexed productId, address by);
    event ProductCancelled(uint256 indexed productId, string reason);
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

    // ✅ New function to mark as Returned
    function markAsReturned(uint256 _productId) external onlyAuthorized productExists(_productId) {
        Product storage product = products[_productId];
        require(product.status == ProductStatus.Delivered || product.status == ProductStatus.Verified, "Can only return after delivery or verification");

        product.status = ProductStatus.Returned;
        product.lastUpdated = block.timestamp;

        emit ProductReturned(_productId, msg.sender);
    }

    // ✅ New function to Cancel
    function cancelProduct(uint256 _productId, string memory _reason) external onlyOwner productExists(_productId) {
        Product storage product = products[_productId];
        require(product.status == ProductStatus.Created || product.status == ProductStatus.InTransit, "Can only cancel early stage products");

        product.status = ProductStatus.Cancelled;
        product.lastUpdated = block.timestamp;

        emit ProductCancelled(_productId, _reason);
    }

    function authorizeParty(address _party) external onlyOwner {
        require(_party != address(0), "Invalid address");
        authorizedParties[_party] = true;
        emit PartyAuthorized(_party);
    }

    function revokeParty(address _party) external onlyOwner {
        authorizedParties[_party] = false;
        emit PartyRevoked(_party);
    }

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

    function getProductLocationHistory(uint256 _productId) external view productExists(_productId) returns (string[] memory) {
        return products[_productId].locationHistory;
    }

    function getProductOwnershipHistory(uint256 _productId) external view productExists(_productId) returns (address[] memory) {
        return products[_productId].ownershipHistory;
    }

    // ✅ Optional: Status as string for frontend convenience
    function getProductStatusString(uint256 _productId) external view productExists(_productId) returns (string memory) {
        ProductStatus status = products[_productId].status;
        if (status == ProductStatus.Created) return "Created";
        if (status == ProductStatus.InTransit) return "InTransit";
        if (status == ProductStatus.Delivered) return "Delivered";
        if (status == ProductStatus.Verified) return "Verified";
        if (status == ProductStatus.Returned) return "Returned";
        if (status == ProductStatus.Cancelled) return "Cancelled";
        return "Unknown";
    }
}
