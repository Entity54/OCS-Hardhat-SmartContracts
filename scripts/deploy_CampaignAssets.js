const hre = require("hardhat");

const scName = "CampaignAssets";
const networkName = hre.network.name
const chainId = hre.network.config.chainId
console.log(`networkName: ${networkName} chainId: ${chainId}`);  


async function main() {

  const sc = await hre.ethers.deployContract(scName, []);
  await sc.waitForDeployment();

  const deployedAddress = sc.target;
  const timestamp = new Date().toISOString();
  const deploymentMessage= `${timestamp} Deployed Smart Contract: ${scName} at address: ${deployedAddress} on: ${networkName} network and ChainId: ${chainId}`;
  console.log(deploymentMessage);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});


// npx hardhat run deploy_CampaignAssets --network base-sepolia
