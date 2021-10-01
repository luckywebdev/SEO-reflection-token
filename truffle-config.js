require("dotenv").config();

const HDWalletProvider = require("@truffle/hdwallet-provider");
const mnemonic = process.env.MNEUMONIC;
const infuraKey = process.env.INFURA_PROJECT_ID;
const etherscanApiKey = process.env.ETHERSCAN_API_KEY;
const fromAddress = process.env.FROM_ADDRESS;

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "999",
      gas: 11000000,
      gasPrice: 42000000000,
      networkCheckTimeout: 10000000,
      timeoutBlocks: 200,
    },
    main: {
      provider: () =>
        new HDWalletProvider(
          mnemonic,
          `wss://mainnet.infura.io/ws/v3/${infuraKey}`
        ),
      network_id: 1,
      gas: 11000000,
      gasPrice: 70000000000,
      networkCheckTimeout: 10000000,
      confirmations: 2,
      timeoutBlocks: 200,
      skipDryRun: true,
      from: fromAddress,
    },
    ropsten: {
      provider: () =>
        new HDWalletProvider(
          mnemonic,
          `https://ropsten.infura.io/v3/${infuraKey}`
        ),
      network_id: 3,
      gas: 6721975,
      gasPrice: 10000000000,
      networkCheckTimeout: 10000000,
      confirmations: 2,
      timeoutBlocks: 200,
      skipDryRun: true,
      from: fromAddress,
    },
    rinkeBy: {
      provider: () =>
        new HDWalletProvider(
          mnemonic,
          `wss://rinkeby.infura.io/ws/v3/${infuraKey}`
        ),
      network_id: 4,
      gas: 11000000,
      gasPrice: 42000000000,
      networkCheckTimeout: 10000000,
      confirmations: 2,
      timeoutBlocks: 200,
      skipDryRun: true,
      from: fromAddress,
    },
    mumbai: {
      provider: () =>
        new HDWalletProvider(
          mnemonic,
          `https://polygon-mumbai.infura.io/v3/${infuraKey}`
        ),
      network_id: 80001,
      gas: 6721975,
      gasPrice: 10000000000,
      networkCheckTimeout: 10000000,
      confirmations: 2,
      timeoutBlocks: 200,
      skipDryRun: true,
      from: fromAddress,
    }
  },

  // Set default mocha options here, use special reporters etc.
  mocha: {
    // timeout: 100000
  },

  // Configure your compilers
  compilers: {
    solc: {
      version: "0.8.4",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200,
        },
        evmVersion: "byzantium",
      },
    },
  },

  plugins: ["truffle-plugin-verify"],

  api_keys: {
    etherscan: etherscanApiKey,
  },
};
