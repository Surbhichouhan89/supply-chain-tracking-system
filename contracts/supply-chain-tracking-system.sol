// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract KYCVerifiedPredictionMarket {
    address public owner;

    enum VerificationStatus { Unverified, Pending, Verified, Rejected }

    struct Customer {
        address customerAddress;
        string customerName;
        string customerDataHash;
        VerificationStatus status;
        uint256 verificationTimestamp;
        string rejectionReason;
    }

    mapping(address => Customer) public customers;
    mapping(address => bool) public verifiers;
    address[] private customerAddresses;
    uint256 public customerCount;
    uint256 public verifierCount;

    struct Market {
        string description;
        uint256 endTime;
        bool resolved;
        bool outcome;
        address oracle;
        uint256 totalYesShares;
        uint256 totalNoShares;
        uint256 totalYesStaked;
        uint256 totalNoStaked;
        mapping(address => uint256) yesShares;
        mapping(address => uint256) noShares;
        mapping(address => bool) rewardsClaimed;
    }

    mapping(uint256 => Market) public markets;
    uint256 public marketCount;
    uint256 public fee = 1; // 1% fee

    event CustomerRegistered(address indexed customerAddress, string customerName);
    event KYCVerified(address indexed customerAddress, address indexed verifier);
    event KYCRejected(address indexed customerAddress, address indexed verifier, string reason);
    event VerifierAdded(address indexed verifier);
    event VerifierRemoved(address indexed verifier);
    event KYCResubmitted(address indexed customerAddress, string newHash);
    event CustomerNameChanged(address indexed customerAddress, string newName);
    event MarketCreated(uint256 indexed marketId, string description, uint256 endTime, address oracle);
    event SharesPurchased(uint256 indexed marketId, address indexed buyer, bool isYes, uint256 amount);
    event MarketResolved(uint256 indexed marketId, bool outcome);
    event RewardsClaimed(uint256 indexed marketId, address indexed user, uint256 amount);
    event OracleUpdated(uint256 indexed marketId, address newOracle);
    event FeeUpdated(uint256 newFee);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier onlyVerifier() {
        require(verifiers[msg.sender] || msg.sender == owner, "Only verifier");
        _;
    }

    modifier onlyVerifiedCustomer() {
        require(customers[msg.sender].status == VerificationStatus.Verified, "Not verified");
        _;
    }

    constructor() {
        owner = msg.sender;
        verifiers[msg.sender] = true;
        verifierCount = 1;
    }

    // ========== KYC ==========
    function registerCustomer(string memory _name, string memory _hash) public {
        require(customers[msg.sender].customerAddress == address(0), "Already registered");
        customers[msg.sender] = Customer(msg.sender, _name, _hash, VerificationStatus.Pending, 0, "");
        customerAddresses.push(msg.sender);
        customerCount++;
        emit CustomerRegistered(msg.sender, _name);
    }

    function verifyCustomer(address _addr) public onlyVerifier {
        require(customers[_addr].status == VerificationStatus.Pending, "Not pending");
        customers[_addr].status = VerificationStatus.Verified;
        customers[_addr].verificationTimestamp = block.timestamp;
        emit KYCVerified(_addr, msg.sender);
    }

    function rejectCustomer(address _addr, string memory _reason) public onlyVerifier {
        require(customers[_addr].status == VerificationStatus.Pending, "Not pending");
        customers[_addr].status = VerificationStatus.Rejected;
        customers[_addr].rejectionReason = _reason;
        emit KYCRejected(_addr, msg.sender, _reason);
    }

    function addVerifier(address _addr) public onlyOwner {
        require(!verifiers[_addr], "Already verifier");
        verifiers[_addr] = true;
        verifierCount++;
        emit VerifierAdded(_addr);
    }

    function removeVerifier(address _addr) public onlyOwner {
        require(verifiers[_addr], "Not a verifier");
        require(_addr != owner, "Owner cannot be removed");
        verifiers[_addr] = false;
        verifierCount--;
        emit VerifierRemoved(_addr);
    }

    function resubmitKYC(string memory _newHash) public {
        require(customers[msg.sender].status == VerificationStatus.Rejected, "Not rejected");
        customers[msg.sender].customerDataHash = _newHash;
        customers[msg.sender].status = VerificationStatus.Pending;
        customers[msg.sender].rejectionReason = "";
        emit KYCResubmitted(msg.sender, _newHash);
    }

    function changeCustomerName(string memory _newName) public {
        require(customers[msg.sender].status == VerificationStatus.Pending, "Only in pending");
        customers[msg.sender].customerName = _newName;
        emit CustomerNameChanged(msg.sender, _newName);
    }

    function getAllCustomerAddresses() public view returns (address[] memory) {
        return customerAddresses;
    }

    function getCustomerDetails(address user) public view returns (
        string memory name,
        string memory dataHash,
        VerificationStatus status,
        uint256 timestamp,
        string memory reason
    ) {
        Customer storage c = customers[user];
        return (
            c.customerName,
            c.customerDataHash,
            c.status,
            c.verificationTimestamp,
            c.rejectionReason
        );
    }

    // ========== Prediction Market ==========

    function createMarket(string memory _desc, uint256 _endTime, address _oracle) public onlyOwner {
        require(_endTime > block.timestamp, "Invalid endTime");
        uint256 id = marketCount++;
        Market storage m = markets[id];
        m.description = _desc;
        m.endTime = _endTime;
        m.oracle = _oracle;
        emit MarketCreated(id, _desc, _endTime, _oracle);
    }

    function updateOracle(uint256 id, address newOracle) public onlyOwner {
        Market storage m = markets[id];
        require(!m.resolved, "Already resolved");
        m.oracle = newOracle;
        emit OracleUpdated(id, newOracle);
    }

    function calculateShares(uint256 amount, uint256 totalStaked, uint256 totalShares) internal pure returns (uint256) {
        if (totalShares == 0 || totalStaked == 0) return amount;
        return (amount * totalShares) / totalStaked;
    }

    function purchaseShares(uint256 id, bool isYes) public payable onlyVerifiedCustomer {
        Market storage m = markets[id];
        require(block.timestamp < m.endTime, "Market closed");
        require(!m.resolved, "Already resolved");
        require(msg.value > 0, "No ETH");

        uint256 feeAmt = (msg.value * fee) / 100;
        uint256 stake = msg.value - feeAmt;

        if (isYes) {
            uint256 shares = calculateShares(stake, m.totalYesStaked, m.totalYesShares);
            m.yesShares[msg.sender] += shares;
            m.totalYesShares += shares;
            m.totalYesStaked += stake;
        } else {
            uint256 shares = calculateShares(stake, m.totalNoStaked, m.totalNoShares);
            m.noShares[msg.sender] += shares;
            m.totalNoShares += shares;
            m.totalNoStaked += stake;
        }

        payable(owner).transfer(feeAmt);
        emit SharesPurchased(id, msg.sender, isYes, stake);
    }

    function resolveMarket(uint256 id, bool outcome) public {
        Market storage m = markets[id];
        require(msg.sender == m.oracle, "Only oracle");
        require(!m.resolved, "Already resolved");
        require(block.timestamp >= m.endTime, "Not ended");

        m.resolved = true;
        m.outcome = outcome;

        emit MarketResolved(id, outcome);
    }

    function claimRewards(uint256 id) public onlyVerifiedCustomer {
        Market storage m = markets[id];
        require(m.resolved, "Not resolved");
        require(!m.rewardsClaimed[msg.sender], "Already claimed");

        uint256 userShares = m.outcome ? m.yesShares[msg.sender] : m.noShares[msg.sender];
        uint256 totalWinningShares = m.outcome ? m.totalYesShares : m.totalNoShares;
        uint256 rewardPool = m.totalYesStaked + m.totalNoStaked;

        require(userShares > 0, "No winning shares");

        uint256 reward = (userShares * rewardPool) / totalWinningShares;
        m.rewardsClaimed[msg.sender] = true;

        payable(msg.sender).transfer(reward);
        emit RewardsClaimed(id, msg.sender, reward);
    }

    function getMarketDetails(uint256 id) public view returns (
        string memory description,
        uint256 endTime,
        bool resolved,
        bool outcome,
        address oracle,
        uint256 totalYesStaked,
        uint256 totalNoStaked,
        uint256 totalYesShares,
        uint256 totalNoShares
    ) {
        Market storage m = markets[id];
        return (
            m.description,
            m.endTime,
            m.resolved,
            m.outcome,
            m.oracle,
            m.totalYesStaked,
            m.totalNoStaked,
            m.totalYesShares,
            m.totalNoShares
        );
    }

    function getUserShares(uint256 id, address user) public view returns (uint256 yesShares, uint256 noShares) {
        Market storage m = markets[id];
        return (m.yesShares[user], m.noShares[user]);
    }

    function changeFee(uint256 newFee) public onlyOwner {
        require(newFee <= 10, "Fee too high");
        fee = newFee;
        emit FeeUpdated(newFee);
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
