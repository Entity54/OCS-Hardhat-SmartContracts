const hre = require("hardhat");

const scName = "simpleTarget";
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


// npx hardhat run scripts/deploy_simpleTarget.js --network base-sepolia

// networkName: base-sepolia chainId: 84532
// 2024-06-18T16:47:06.629Z Deployed Smart Contract: simpleTarget at address: 0xf6CE06B69Be0914F4Ba79710DeA42545F8D8388F on: base-sepolia network and ChainId: 84532