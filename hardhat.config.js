require("@nomiclabs/hardhat-ethers");
require('hardhat-deploy');
require('hardhat-contract-sizer');

const networks = {
  hardhat: {}
}

if (process.env.RINKEBY_PRIVATE_KEY) {
  networks.rinkeby = {
    url: process.env.RINKEBY_RPC || 'https://rinkeby-light.eth.linkpool.io',
    accounts: [`${process.env.RINKEBY_PRIVATE_KEY}`],
  };
}

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
  networks,
  solidity: {
    version: '0.6.12',
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
};
