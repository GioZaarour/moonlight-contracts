const { assert } = require("chai");

const MoonFactory = artifacts.require('MoonFactory.sol');
const Vault = artifacts.require('Vault.sol');
const MockERC721 = artifacts.require('MockERC721.sol');
const MockERC1155 = artifacts.require('MockERC1155.sol');
const Router = artifacts.require('MoonSwap/MoonSwapV2Router02.sol');
const Factory = artifacts.require('MoonSwap/MoonSwapV2Factory.sol');

contract('MoonFactory', () => {
    it('Check deployed properly', async () => {
        const moonFactory = await MoonFactory.deployed();
        assert(moonFactory.address !== '');
    });
    it('Test creating new crowdfunding vault', async () => {
        const moonFactory = await MoonFactory.deployed();
        const result = await moonFactory.createMoonToken("MoonlightTEST", "MLT", true, true, 1000);
        const {0: vault, 1: vaultGovernorAlpha} = result;
        assert(vault.address !== '' && vaultGovernorAlpha.address !== '');
    });
});

//some un-initialized Vault contract we manually deploy for testing purposes
contract('Vault', () => {
    it('Initialize the vault', async () => {
        const vault = await Vault.deployed();
        const result = await vault.initialize("MoonlightTEST", "MLT", /*issuer address on ganache,*/ /*[put factory address on ganache],*/ true, 1000);
        assert(result === true);
    });
});