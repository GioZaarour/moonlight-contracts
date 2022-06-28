const { deployProxy } = require('@openzeppelin/truffle-upgrades');

const Factory = artifacts.require('MoonSwap/MoonSwapV2Factory.sol');
//const Rewarder = artifacts.require('ProtocolUnicRewards.sol');
const Router = artifacts.require('MoonSwap/MoonSwapV2Router02.sol');
//const Unic = artifacts.require('Unic.sol')
//const UnicFarm = artifacts.require('UnicFarm.sol');
//const UnicGallery = artifacts.require('UnicGallery.sol');
//const UnicPumper = artifacts.require('UnicPumper.sol');
const Vault = artifacts.require('Vault.sol');
const MoonFactory = artifacts.require('MoonFactory.sol');
const MockERC721 = artifacts.require('MockERC721.sol');
const MockERC1155 = artifacts.require('MockERC1155.sol');
const VaultGovernorAlpha = artifacts.require('VaultGovernorAlpha.sol');
const MoonVaultGovernorAlphaFactory = artifacts.require('MoonVaultGovernorAlphaFactory.sol');
const MoonVaultProxyTransactionFactory = artifacts.require('MoonVaultProxyTransactionFactory.sol');
const VaultGovernorAlphaConfig = artifacts.require('VaultGovernorAlphaConfig.sol');
const MockThirdPartyContract = artifacts.require('MockThirdPartyContract.sol');
const AuctionHandler = artifacts.require('AuctionHandler.sol');


module.exports = async function(deployer, _network, addresses) {
  const [moonlight, _] = addresses;

  await deployer.deploy(Vault);
  const converter = await Vault.deployed();

  // await deployer.deploy(Unic)
  // const unic = await Unic.deployed();

  const factory = await deployer.deployProxy(Factory, [moonlight], { deployer });
  console.log('Deployed factory at', instance.address);
  //const factory = await Factory.deployed();

  // await deployer.deploy(Rewarder)
  // const rewarder = await Rewarder.deployed();

  // await deployer.deploy(Router, factory.address, "0xc778417e063141139fce010982780140aa0cd5ab"/*, "0xE5aEE6abDbe9589c927f96911A452448aD453431"*/)
  // const router = await Router.deployed();

  // await deployer.deploy(UnicFarm, unic.address, leia, 19, 20, 1, 10456340, 6000)
  // const unicFarm = await UnicFarm.deployed();

  // await deployer.deploy(UnicGallery, unic.address)
  // const unicGallery = await UnicGallery.deployed();

  // await deployer.deploy(UnicFactory/*, leia, 100, "10000000000000000000000"*/);
  // const unicFactory = await UnicFactory.deployed();

  // await deployer.deploy(ConverterGovernorAlphaConfig);
  // const converterGovernorAlphaConfig = await ConverterGovernorAlphaConfig.deployed();
  // await converterGovernorAlphaConfig.setVotingPeriod(200);
  // await converterGovernorAlphaConfig.setVotingDelay(1);

  // await deployer.deploy(UnicConverterGovernorAlphaFactory);
  // const unicConverterGovernorAlphaFactory = await UnicConverterGovernorAlphaFactory.deployed();

  // await deployer.deploy(UnicConverterProxyTransactionFactory, converterGovernorAlphaConfig.address, unicConverterGovernorAlphaFactory.address);
  // const unicConverterProxyTransactionFactory = await UnicConverterProxyTransactionFactory.deployed();

  // // const converterGovernorAlphaAddress = await unicFactory.getGovernorAlpha(uLeiaAddress);
  // // const converterGovernorAlpha = await ConverterGovernorAlpha.at(converterGovernorAlphaAddress);
  // // console.log('converterGovernorAlphaAddress' + converterGovernorAlphaAddress);

  // await deployer.deploy(MockThirdPartyContract);
  // const mockThirdPartyContract = await MockThirdPartyContract.deployed();

  // await deployer.deploy(AuctionHandler);
  // const auctionHandler = await AuctionHandler.deployed();

  // await unicFactory.initialize(leia, 100, "10000000000000000000000", unic.address, unicConverterProxyTransactionFactory.address);
  // await unicFactory.setAuctionHandler(auctionHandler.address);
  // await auctionHandler.initialize(unicFactory.address, 259200, 105, 300, 100, leia, leia);
};
