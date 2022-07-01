const { assert } = require("chai");

const MoonFactory = artifacts.require('MoonFactory.sol');
const Vault = artifacts.require('Vault.sol');
const MockERC721 = artifacts.require('MockERC721.sol');
const MockERC1155 = artifacts.require('MockERC1155.sol');
const Router = artifacts.require('MoonSwap/MoonSwapV2Router02.sol');
const Factory = artifacts.require('MoonSwap/MoonSwapV2Factory.sol');

contract('MoonFactory', () => {

    let moonFactory = null;
    before(async () => {
        moonFactory = await MoonFactory.deployed();
    });

    it('Check deployed properly', async () => {
        assert(moonFactory.address !== '');
    });
    it('Test creating new crowdfunding vault', async () => {
        const result = await moonFactory.createMoonToken("MoonlightTEST", "MLT", true, true, 1000);
        //assert(result[0].address !== '');
        //assert(result[1].address !== '');

        const {0: vault, 1: vaultGovernorAlpha} = result;
        assert(vault.address !== '' && vaultGovernorAlpha.address !== '');
        assert(moonFactory.getMoonToken[vault.address] === 0);
        assert(moonFactory.moonTokens[0] === vault.address);
    });
    it('Test setFeeTo and setFeeToSetter', async () => {
        //these may have to be ganache addresses
        await moonFactory.setFeeTo(0x347dA2f2Ac8594Bb007B72F05041b2B0D89264dd);
        await moonFactory.setFeeToSetter(0x062007249Dd89b4FdB423B30ab36A09f18FDb66e);

        assert(moonFactory.feeTo === '0x347dA2f2Ac8594Bb007B72F05041b2B0D89264dd' && moonFactory.feeToSetter === '0x062007249Dd89b4FdB423B30ab36A09f18FDb66e');
        
        //try to set feeTo again, but not as the feeToSetter anymore
        try {
            await moonFactory.setFeeTo(0x347dA2f2Ac8594Bb007B72F05041b2B0D89264dd);
        } catch(e) {
            assert (e.message.includes('Moonlight: FORBIDDEN'));

            return;
        }

        assert(false);
    });
    
});

//some un-initialized Vault contract we manually deploy for testing purposes
contract('Vault', () => {

    let vault = null;
    let mock721 = null;
    before(async () => {
        vault = await Vault.deployed();
        mock721 = await MockERC721.deployed();
    });

    it('Initialize the vault', async () => {
        const result = await vault.initialize("MoonlightTEST", "MLT", /*issuer (this) address on ganache,*/ /*[put factory address on ganache],*/ true, 1000);
        console.log('Crowdfunding price is ', vault.moonTokenCrowdfundingPrice);
        assert(result === true);
    });
    it('Set target NFT', async () => {
        await vault.addTargetNft([1], [1], [150000000000000000], [mock721.address]);
        
        assert(vault.targetNfts[0].nftContract === mock721.address);
        assert(vault.crowdfundGoal !== 0);
    });
    it('Test set buy now price', async () => {

    });
    it('Test update target', async () => {

    });
    it('', async () => {

    });
});