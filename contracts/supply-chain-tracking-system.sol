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
        newProduc
