const HDWalletProvider = require("truffle-hdwallet-provider");

require('dotenv').config()

module.exports = {
  // Uncommenting the defaults below
  // provides for an easier quick-start with Ganache.
  // You can also follow this format for other networks;
  // see <http://truffleframework.com/docs/advanced/configuration>
  // for more details on how to specify configuration options!
  //
  networks: {
    development: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*"
    },
    test: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*"
    },
    mainnet: {
      network_id: 1,
    },
    rinkeby: {
      networkCheckTimeout: 10000,
      provider: function() {
        //return new HDWalletProvider("<MNEMONIC>", "<API_ENDPOINT>");
        //return new HDWalletProvider("patient verb imitate host ball category gorilla brush elbow reduce remind awful", "http://127.0.0.1:8545");
        
        return new HDWalletProvider("", "");

        //very smart unicly team for leaving a private key in here and giving access to their repo 04ff867c5d51263db9c82625f1c867d05d3fc2f7bed8bdaeaff187f3a5fc2416
      },  
      network_id: 4,
      gas: 10000000,
      gasPrice: 10000000000,
    }, 
    goerli: {
      networkCheckTimeout: 10000,
      provider: function() {
        return new HDWalletProvider(process.env.PRIVATE_KEY, "https://goerli.infura.io/v3/" + process.env.INFURA_API_KEY);
      },  
      network_id: 5,
      //gas:      10000000,
      //gasPrice: 10000000000,
    }
  },
  compilers: {
    solc: {
      version: "0.6.12",
      settings: {
        optimizer: {
          enabled: false, // Default: false
          runs: 200, // Default: 200
        },
      }
    }
  },
  plugins: [
    'truffle-plugin-verify',
    'truffle-contract-size'
  ],
  api_keys: {
    etherscan: process.env.ETHERSCAN_API_KEY,
  }
};
