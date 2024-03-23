// to verify:
// npx hardhat verify --network mainnet DEPLOYED_CONTRACT_ADDRESS "ConstructorArgument1"


//require("@nomicfoundation/hardhat-toolbox");
//require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-waffle");
require('hardhat-contract-sizer');
//require("@nomiclabs/hardhat-etherscan");
require("@nomicfoundation/hardhat-verify");

require('dotenv').config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
 solidity: {
    compilers: [
      {
        version: "0.8.15"
      },
      {
//        version: "0.8.24"
        version: "0.8.20"
      }
    ],
    settings: {
      optimizer: {
        enabled: true,
        runs: 100000,
      },
      viaIR: true,
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API,
    customChains: [
     {
       network: "base-goerli",
       chainId: 84531,
       urls: {
        apiURL: "https://api-goerli.basescan.org/api",
        browserURL: "https://goerli.basescan.org"
       }
     }
    ]
  },
  networks: {
    hardhat: {},  // For local blockchain
    /// TEST NETS
    mumbai: {
      url: "https://rpc-mumbai.maticvigil.com",
      accounts: [`0x${process.env.EVM_PRIVATE_KEY}`],
      gasPrice: 1000000000, // 1 Gwei
    },
    goerli: {
      url: 'https://rpc.ankr.com/eth_goerli',
      accounts: [`0x${process.env.EVM_PRIVATE_KEY}`]
    },
    baseTest: {
      url: 'https://goerli.base.org',
      accounts: [`0x${process.env.EVM_PRIVATE_KEY}`],
      gasPrice: 1000000000
    },




    /// MAIN NETS
    polygon: {
      url: "https://polygon-rpc.com",
      accounts: [`0x${process.env.EVM_PRIVATE_KEY}`],
      gasPrice: 1000000000, // 1 Gwei
    },
    base: {
      url: "https://mainnet.base.org/",
      accounts: [`0x${process.env.EVM_PRIVATE_KEY}`],
    }
  }}