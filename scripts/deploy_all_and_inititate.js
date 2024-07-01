const hre = require("hardhat");
const crudJSON = require(__dirname + `/utils/crudJSON.js`);

const scName_CampaignManager = "CampaignManager";
const scName_InfluencersManager = "InfluencersManager";
const scName_CampaignAssets = "CampaignAssets";
const scName_SquawkProcessor = "SquawkProcessor";
const scNamesArray = [scName_CampaignManager, scName_InfluencersManager, scName_CampaignAssets, scName_SquawkProcessor];

let deployedAddressesArray = [];



const networkName = hre.network.name
const chainId = hre.network.config.chainId
console.log(`networkName: ${networkName} chainId: ${chainId}`);  


async function main() {

    const sc_CampaignManager = await hre.ethers.deployContract(scName_CampaignManager, []);
    await sc_CampaignManager.waitForDeployment();
    const deployedAddress_CampaignManager = sc_CampaignManager.target;
    deployedAddressesArray.push(deployedAddress_CampaignManager);

    const sc_InfluencersManager = await hre.ethers.deployContract(scName_InfluencersManager, []);
    await sc_InfluencersManager.waitForDeployment();
    const deployedAddress_InfluencersManager = sc_InfluencersManager.target;
    deployedAddressesArray.push(deployedAddress_InfluencersManager);

    const sc_CampaignAssets = await hre.ethers.deployContract(scName_CampaignAssets, []);
    await sc_CampaignAssets.waitForDeployment();
    const deployedAddress_CampaignAssets = sc_CampaignAssets.target;
    deployedAddressesArray.push(deployedAddress_CampaignAssets);

    const sc_SquawkProcessor = await hre.ethers.deployContract(scName_SquawkProcessor, []);
    await sc_SquawkProcessor.waitForDeployment();
    const deployedAddress_SquawkProcessor = sc_SquawkProcessor.target;
    deployedAddressesArray.push(deployedAddress_SquawkProcessor);


    const timestamp = new Date().toISOString();
    let deploymentMessage = ""
    deploymentMessage += `${timestamp} Deployed Smart Contract scName_CampaignManager: ${scName_CampaignManager} at address: ${deployedAddress_CampaignManager} on: ${networkName} network and ChainId: ${chainId} \n`;
    deploymentMessage += `${timestamp} Deployed Smart Contract scName_InfluencersManager: ${scName_InfluencersManager} at address: ${deployedAddress_InfluencersManager} on: ${networkName} network and ChainId: ${chainId} \n`;
    deploymentMessage += `${timestamp} Deployed Smart Contract scName_CampaignAssets: ${scName_CampaignAssets} at address: ${deployedAddress_CampaignAssets} on: ${networkName} network and ChainId: ${chainId} \n`;
    deploymentMessage += `${timestamp} Deployed Smart Contract scName_SquawkProcessor: ${scName_SquawkProcessor} at address: ${deployedAddress_SquawkProcessor} on: ${networkName} network and ChainId: ${chainId} \n`;


    const scFile = await crudJSON.readJSON(__dirname + `/deployments/DeploymentData.json`);
    let readDeploymentData = JSON.parse(scFile);


    for (let i=0; i<scNamesArray.length; i++) {
        const scName = scNamesArray[i];
        const deployedAddress = deployedAddressesArray[i];

        if ( !(Object.keys(readDeploymentData)).includes(scName) ) readDeploymentData[`${scName}`] = {};
        readDeploymentData[`${scName}`][`${networkName}`] = {
            networkName,
            chainId,
            address: deployedAddress,
            constructorArguments: [],
            value: "0",
            timestamp: timestamp
        };

    }

    saveDeploymentDataJSON(readDeploymentData);
    save_server_logs(deploymentMessage);
    console.log(deploymentMessage);



    //#region Intitiations
    console.log(`********************************************************`);
    console.log(`********************* Getting signers ***********************************`);
    const [admin, secondAccount] = await ethers.getSigners();
    const adminAddress = await admin.getAddress();
    const secondAccountAddress = await secondAccount.getAddress();
    console.log(`Address of the admin is: ${adminAddress} secondAccountAddress: ${secondAccountAddress} \n`);

    console.log(`********************* Instantiating smart contracts ***********************************`);
    const CampaignManagerr_raw = await hre.artifacts.readArtifact("contracts/CampaignManager.sol:CampaignManager")
    const CampaignManager_ABI = CampaignManagerr_raw.abi;
    const CampaignManager_sc = new ethers.Contract( deployedAddress_CampaignManager, CampaignManager_ABI, admin );
    console.log(`CampaignManager_sc.target: ${CampaignManager_sc.target} \n`);

    const InfluencersManagerr_raw = await hre.artifacts.readArtifact("contracts/InfluencersManager.sol:InfluencersManager");
    const InfluencersManager_ABI = InfluencersManagerr_raw.abi;
    const InfluencersManager_sc = new ethers.Contract( deployedAddress_InfluencersManager, InfluencersManager_ABI, admin );
    console.log(`InfluencersManager_sc.target: ${InfluencersManager_sc.target} \n`);

    const CampaignAssetss_raw = await hre.artifacts.readArtifact("contracts/CampaignAssets.sol:CampaignAssets");
    const CampaignAssets_ABI = CampaignAssetss_raw.abi;
    const CampaignAssets_sc = new ethers.Contract( deployedAddress_CampaignAssets, CampaignAssets_ABI, admin );
    console.log(`CampaignAssets_sc.target: ${CampaignAssets_sc.target} \n`);

    const SquawkProcessorr_raw = await hre.artifacts.readArtifact("contracts/SquawkProcessor.sol:SquawkProcessor");
    const SquawkProcessor_ABI = SquawkProcessorr_raw.abi;
    const SquawkProcessor_sc = new ethers.Contract( deployedAddress_SquawkProcessor, SquawkProcessor_ABI, admin );
    console.log(`SquawkProcessor_sc.target: ${SquawkProcessor_sc.target} \n`);


    console.log(` ********************* setting up addresses inside smart contracts for intercommunication starts *********************`);
    await CampaignManager_sc.setInfluencersManager(deployedAddress_InfluencersManager);
    await CampaignManager_sc.setCampaignAssets(deployedAddress_CampaignAssets);
    await InfluencersManager_sc.setCampaignManager(deployedAddress_CampaignManager);
    await CampaignAssets_sc.setCampaignManager(deployedAddress_CampaignManager);
    await SquawkProcessor_sc.setCampaignManager(deployedAddress_CampaignManager);
    await SquawkProcessor_sc.setInfluencersManager(deployedAddress_InfluencersManager);
    await SquawkProcessor_sc.setCampaignAssets(deployedAddress_CampaignAssets);
    console.log(` ********************* setting up addresses inside smart contracts for intercommunication ends *********************`);
    
    console.log(` `);

    console.log(` ********************* setting up addresses for toggleAdministrator starts *********************`);
    await CampaignManager_sc.toggleAdministrator(deployedAddress_InfluencersManager);
    await CampaignManager_sc.toggleAdministrator(deployedAddress_CampaignAssets);
    await CampaignManager_sc.toggleAdministrator(deployedAddress_SquawkProcessor);

    await InfluencersManager_sc.toggleAdministrator(deployedAddress_CampaignManager);
    await InfluencersManager_sc.toggleAdministrator(deployedAddress_SquawkProcessor);

    await CampaignAssets_sc.toggleAdministrator(deployedAddress_CampaignManager);
    await CampaignAssets_sc.toggleAdministrator(deployedAddress_SquawkProcessor);

    //for testing purposes
    await CampaignManager_sc.toggleAdministrator(secondAccountAddress);
    await SquawkProcessor_sc.toggleAdministrator(secondAccountAddress);




    console.log(` ********************* setting up addresses for toggleAdministrator ends *********************`);

    console.log(`********************************************************`);
    //#endregion Intitiations





}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});


// npx hardhat run  scripts/deploy_all_and_inititate.js --network base-sepolia  
// Shift+Option+F to format code in VSCode


const save_server_logs = (message) => {
  const datafilePath = __dirname + `/deployments/DeploymentLogs.txt`;
  crudJSON.appendToTXT(datafilePath,message);  
}

const saveDeploymentDataJSON = (message) => {
  const datafilePath = __dirname + `/deployments/DeploymentData.json`;
  crudJSON.writeToJSON(datafilePath,message);  
}
