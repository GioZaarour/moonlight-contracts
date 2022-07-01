const { deployProxy } = require('@openzeppelin/truffle-upgrades');

const Vault = artifacts.require('Vault.sol');

module.exports = async function(deployer, _network, addresses) {
    const [moonlight, _] = addresses;

  /*await deployer.deploy(Vault, "Moonlight Vault", "MLT", moonlight, 0x80E3701fA4c252D64d938435eEf9e4867eF9fb1B, false, 1000);
  const vault = await Vault.deployed();
  console.log('Deployed uninitialized vault at', vault.address);*/

  /*await deployer.deploy(Vault);
  const vault = await Vault.deployed();
  console.log('Deployed uninitialized vault at', vault.address); */

  /*const vault = await deployProxy(Vault, ["Moonlight Vault", "MLT", moonlight, 0x80E3701fA4c252D64d938435eEf9e4867eF9fb1B, false, 1000], { deployer });
  console.log('Deployed uninitialized vault at', vault.address); */

  const vault = await deployProxy(Vault);
  console.log('Deployed uninitialized vault at', vault.address);

};