// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const currentTimestampInSeconds = Math.round(Date.now() / 1000);
  const unlockTime = currentTimestampInSeconds + 60;

  const lockedAmount = hre.ethers.parseEther("0.001");

  const lock = await hre.ethers.deployContract("Lock", [unlockTime], {
    value: lockedAmount,
  });

  await lock.waitForDeployment();

  console.log(
    `Lock with ${ethers.formatEther(
      lockedAmount
    )}ETH and unlock timestamp ${unlockTime} deployed to ${lock.target}`
  );

  
 

  // const scName = "Lock";
  // const deploedAddrss = "0x1111111199555555555FbDB2315678afecb367f032d93F642f64180aa3";
  // const networkName = "Chain Bla";
  // const chainId = 11155111;
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});


//npx hardhat run scripts/deploy.js 
//npx hardhat run scripts/deploy.js --network base-sepolia

//Swift+Option+F for pretty JSON 

// Compiled 1 Solidity file successfully (evm target: paris).
// Lock with 0.001ETH and unlock timestamp 1718717491 deployed to 0x5FbDB2315678afecb367f032d93F642f64180aa3