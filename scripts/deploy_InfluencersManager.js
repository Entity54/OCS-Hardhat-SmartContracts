const hre = require("hardhat");
const crudJSON = require(__dirname + `/utils/crudJSON.js`);


const scName = "InfluencersManager";

const networkName = hre.network.name
const chainId = hre.network.config.chainId
console.log(`networkName: ${networkName} chainId: ${chainId}`);  


async function main() {

  const sc = await hre.ethers.deployContract(scName, []);
  await sc.waitForDeployment();

  const deployedAddress = sc.target;
  const timestamp = new Date().toISOString();
  const deploymentMessage= `${timestamp} Deployed Smart Contract: ${scName} at address: ${deployedAddress} on: ${networkName} network and ChainId: ${chainId}`;

  const scFile = await crudJSON.readJSON(__dirname + `/deployments/DeploymentData.json`);
  let readDeploymentData = JSON.parse(scFile);
  if ( !(Object.keys(readDeploymentData)).includes(scName) ) readDeploymentData[`${scName}`] = {};
  readDeploymentData[`${scName}`][`${networkName}`] = {
                                                        networkName,
                                                        chainId,
                                                        address: deployedAddress,
                                                        constructorArguments: [],
                                                        value: "0",
                                                        timestamp: timestamp
                                                      };

  saveDeploymentDataJSON(readDeploymentData);
  save_server_logs(deploymentMessage);
  console.log(deploymentMessage);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});



// npx hardhat run  scripts/deploy_InfluencersManager.js --network base-sepolia  
// Shift+Option+F to format code in VSCode


const save_server_logs = (message) => {
  const datafilePath = __dirname + `/deployments/DeploymentLogs.txt`;
  crudJSON.appendToTXT(datafilePath,message);  
}

const saveDeploymentDataJSON = (message) => {
  const datafilePath = __dirname + `/deployments/DeploymentData.json`;
  crudJSON.writeToJSON(datafilePath,message);  
}
