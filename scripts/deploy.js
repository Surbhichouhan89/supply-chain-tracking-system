const hre = require("hardhat");

async function main() {
  console.log("Deploying Supply Chain Tracking System to Core Testnet 2...");

  // Get the deployer's address
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // Get the balance of the deployer
  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("Account balance:", hre.ethers.formatEther(balance), "CORE");

  // Deploy the contract
  const SupplyChainTracker = await hre.ethers.getContractFactory("SupplyChainTracker");
  
  console.log("Deploying SupplyChainTracker contract...");
  const supplyChainTracker = await SupplyChainTracker.deploy();
  
  await supplyChainTracker.waitForDeployment();
  
  const contractAddress = await supplyChainTracker.getAddress();
  console.log("SupplyChainTracker deployed to:", contractAddress);

  // Verify the deployment
  console.log("Verifying deployment...");
  const owner = await supplyChainTracker.owner();
  console.log("Contract owner:", owner);
  console.log("Product counter:", await supplyChainTracker.productCounter());

  console.log("\n=== Deployment Summary ===");
  console.log("Network: Core Testnet 2");
  console.log("Contract Address:", contractAddress);
  console.log("Deployer Address:", deployer.address);
  console.log("Transaction Hash:", supplyChainTracker.deploymentTransaction().hash);
  
  // Save deployment info
  const deploymentInfo = {
    network: "core_testnet2",
    contractAddress: contractAddress,
    deployer: deployer.address,
    deploymentHash: supplyChainTracker.deploymentTransaction().hash,
    timestamp: new Date().toISOString()
  };
  
  console.log("\nDeployment completed successfully!");
  console.log("Save this contract address for future interactions:", contractAddress);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Deployment failed:", error);
    process.exit(1);
  });
