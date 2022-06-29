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

  /*await deployer.deploy(Vault);
  const vault = await Vault.deployed();
  console.log('Deployed uninitialized vault at', vault.address); */

  /*const vault = await deployProxy(Vault, [], { deployer });
  console.log('Deployed uninitialized vault at', vault.address); */

  // await deployer.deploy(Unic)
  // const unic = await Unic.deployed();

  //moonswap factory
  await deployer.deploy(Factory, moonlight);
  const factory = await Factory.deployed();
  console.log('Deployed moonswap factory at', factory.address);

  // await deployer.deploy(Rewarder)
  // const rewarder = await Rewarder.deployed();

  await deployer.deploy(Router, factory.address, "0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6" /*goerli address for WETH*/);
  const router = await Router.deployed();
  console.log('Deployed moonswap router at', router.address);

  // await deployer.deploy(UnicFarm, unic.address, leia, 19, 20, 1, 10456340, 6000)
  // const unicFarm = await UnicFarm.deployed();

  // await deployer.deploy(UnicGallery, unic.address)
  // const unicGallery = await UnicGallery.deployed();

  await deployer.deploy(VaultGovernorAlphaConfig);
  const vaultGovernorAlphaConfig = await VaultGovernorAlphaConfig.deployed();
  await vaultGovernorAlphaConfig.setVotingPeriod(200);
  await vaultGovernorAlphaConfig.setVotingDelay(1);
  console.log('Deployed governor config at ', vaultGovernorAlphaConfig.address);

  await deployer.deploy(MoonVaultGovernorAlphaFactory);
  const moonVaultGovernorAlphaFactory = await MoonVaultGovernorAlphaFactory.deployed();
  console.log('Deployed governor factory at ', moonVaultGovernorAlphaFactory.address);

  await deployer.deploy(MoonVaultProxyTransactionFactory, vaultGovernorAlphaConfig.address, moonVaultGovernorAlphaFactory.address);
  const moonVaultProxyTransactionFactory = await MoonVaultProxyTransactionFactory.deployed();
  console.log('Deployed vault proxy transaction factory at ', moonVaultProxyTransactionFactory.address);

  // // const converterGovernorAlphaAddress = await unicFactory.getGovernorAlpha(uLeiaAddress);
  // // const converterGovernorAlpha = await ConverterGovernorAlpha.at(converterGovernorAlphaAddress);
  // // console.log('converterGovernorAlphaAddress' + converterGovernorAlphaAddress);

  await deployer.deploy(MockThirdPartyContract);
  const mockThirdPartyContract = await MockThirdPartyContract.deployed();
  console.log('Deployed mock contract at ', mockThirdPartyContract.address);

  //initialize everything
  const moonFactory = await deployProxy(MoonFactory, [moonlight, 100, "10000000000000000000000", moonVaultProxyTransactionFactory.address, 2419000, 20, 10], { deployer });
  console.log('Deployed moonlight factory at ', moonFactory.address);

  const auctionHandler = await deployProxy(AuctionHandler, [moonFactory.address, 129600, 105, 300, 50, moonlight, moonlight], { deployer });
  console.log('Deployed auction handler at ', auctionHandler.address);

  await moonFactory.setAuctionHandler(auctionHandler.address);
};
