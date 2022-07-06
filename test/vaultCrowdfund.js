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

        const index = await moonFactory.getMoonToken(vault.address);
        const token = await moonFactory.moonTokens(0);

        assert(index === 0);
        assert(token === vault.address);
    });
    it('Test setFeeTo and setFeeToSetter', async () => {
        //these may have to be ganache addresses
        await moonFactory.setFeeTo(0x347dA2f2Ac8594Bb007B72F05041b2B0D89264dd);
        await moonFactory.setFeeToSetter(0x062007249Dd89b4FdB423B30ab36A09f18FDb66e);

        const newFeeTo = await moonFactory.feeTo();
        const newFeeToSetter = await moonFactory.feeToSetter();

        assert(newFeeTo === '0x347dA2f2Ac8594Bb007B72F05041b2B0D89264dd' && newFeeToSetter === '0x062007249Dd89b4FdB423B30ab36A09f18FDb66e');
        
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
        const price = await vault.moonTokenCrowdfundingPrice();
        console.log('Crowdfunding price is ', price.toNumber());
        assert(result === true);
    });
    it('Set target NFT', async () => {
        await vault.addTargetNft([1], [1], [150000000000000000], [mock721.address]);

        const addy = await vault.targetNfts(0).nftContract();
        const newGoal = await vault.crowdfundGoal();
        
        assert(addy === mock721.address);
        assert(newGoal.toNumber() !== 0);
    });
    it('Test set buy now price', async () => {
        await vault.setBuyNowPrices([0], [100000000000000000]);

        const newBuyNow = await vault.targetNfts(0).buyNowPrice();
        const newGoal = await vault.crowdfundGoal();

        assert(newBuyNow.toNumber() === 100000000000000000);
        assert(newGoal.toNumber() === 100000000000000000);
    });
    it('Test update target', async () => {
        await vault.updateTarget(0, 2, 5, 90000000000000000, mock721.address);

        const newTokenId = await vault.targetNfts(0).tokenId();
        const newGoal = await vault.crowdfundGoal();

        assert(newTokenId.toNumber() === 2);
        assert(newGoal.toNumber() === 90000000000000000);
    });
    it('Test purchase crowdfunding', async () => {
        const price = await vault.moonTokenCrowdfundingPrice();
        const beforeFeeVal = price.toNumber() * 10;
        const val = beforeFeeVal + (beforeFeeVal / 20); //5% fee

        try {
            await vault.purchaseCrowdfunding(10, {value: val});
        } catch (e) {
            console.log(e.message);
            assert(false);
        }
        
        const amountOwned = await vault.amountOwned(/*figure out syntax whatever this should be on ganache*/address(this));
        const contractFees = await vault.contributionFees();
        assert(amountOwned.toNumber() === 10);
        assert(contractFees.toNumber() !== 0);
    });
    it('Test crowdfund success', async () => {

    });
    it('Test beta buy NFTs', async () => {

    });
    /*
    it('Test terminate crowdfunding', async () => {

    });
    it('Test withdraw crowdfunding', async () => {

    }); */
});