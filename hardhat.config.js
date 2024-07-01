require("dotenv").config()
require("@nomicfoundation/hardhat-toolbox");

const RPC_BASE_KEY = process.env.VITE_RPC_BASE_KEY;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const PRIVATE_KEY2 = process.env.PRIVATE_KEY2;



/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.24",
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
    },
    "base-sepolia": {
      url: "https://sepolia.base.org",
      accounts: [PRIVATE_KEY, PRIVATE_KEY2],
      chainId: 84532,
      timeout: 60000,
    },
    "base": {
      url: `https://api.developer.coinbase.com/rpc/v1/base/${RPC_BASE_KEY}`,
      accounts: [PRIVATE_KEY, PRIVATE_KEY2],
      chainId: 8453,
      timeout: 60000,
    },
  },


  //FOR CONTRACT VERIFICATION
  basescan: {
    url: "https://basescan.org/",
    apiKey: "",
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  mocha: {
    timeout: 40000
  }
}
