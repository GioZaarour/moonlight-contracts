import chai, { expect } from 'chai'
import { BigNumber, Contract, constants, utils } from 'ethers'
import { solidity, MockProvider, createFixtureLoader, deployContract } from 'ethereum-waffle'

import { expandTo18Decimals, mineBlock, mineBlocks } from './utils'

import UnicFactory from '../build/UnicFactory.json'
import Converter from '../build/Converter.json'
import AuctionHandler from '../build/AuctionHandler.json'
import MockERC721 from '../build/MockERC721.json'
import MockERC1155 from '../build/MockERC1155.json'
import MockERC20 from '../build/MockERC20.json'

chai.use(solidity)

const overrides = {
  gasLimit: 9999999
}

let emptyArray: Array<number>
emptyArray = []

describe('AuctionHandler', () => {
    const provider = new MockProvider({
      ganacheOptions: {
        hardfork: 'istanbul',
        mnemonic: 'horn horn horn horn horn horn horn horn horn horn horn horn',
        gasLimit: 99999999,
      },
    })
    const [alice, bob, carol, minter, fees, bidder1, bidder2] = provider.getWallets()
  
    let factory: Contract
    let converterImpl: Contract
    let converter: Contract
    let auctionHandler: Contract
    let nft1: Contract
    let nft2: Contract
    let unic: Contract
  
    beforeEach(async () => {
      unic = await deployContract(alice, MockERC20, ['UNIC', 'UNIC', '1000000000000000000000000'], overrides);
      converterImpl = await deployContract(alice, Converter, [], overrides);
      factory = await deployContract(alice, UnicFactory, [], overrides);
      await factory.connect(alice).initialize(alice.address, 100, 1000, unic.address, constants.AddressZero);
      await factory.connect(alice).setConverterImplementation(converterImpl.address);
      await factory.connect(bob).createUToken('Star Wars Collection', 'uSTAR', false, overrides)
      auctionHandler = await deployContract(alice, AuctionHandler, [], overrides)
      await auctionHandler.connect(alice).initialize(factory.address, 10, 105, 2, 100, fees.address, fees.address)
      const converterAddress = await factory.uTokens(0)
      converter = new Contract(converterAddress, JSON.stringify(Converter.abi), provider)

      nft1 = await deployContract(minter, MockERC721, ['Star Wars NFTs', 'STAR'], overrides)
      nft2 = await deployContract(minter, MockERC1155, [], overrides)
      
      // 3 NFTs for Bob
      await nft1.connect(minter).mint(bob.address, 0)
      await nft1.connect(minter).mint(bob.address, 1)
      await nft1.connect(minter).mint(bob.address, 2)
      // 3 more NFTs for Bob
      await nft2.connect(minter).mint(bob.address, 0, 2, emptyArray)
      await nft2.connect(minter).mint(bob.address, 1, 1, emptyArray)

      await nft1.connect(bob).setApprovalForAll(converter.address, true)
      await nft2.connect(bob).setApprovalForAll(converter.address, true)

      let bobTokenIds: Array<number>
      bobTokenIds = [0, 1, 2]
      let triggerPrices: Array<number>
      triggerPrices = [300, 500, 1000]
      await mineBlock(provider, (await provider.getBlock('latest')).timestamp + 1)
      await converter.connect(bob).deposit(bobTokenIds, emptyArray, triggerPrices, nft1.address)
      expect(await converter.currentNFTIndex()).to.be.eq(3)
      await mineBlock(provider, (await provider.getBlock('latest')).timestamp + 1)

      bobTokenIds = [0, 1]

      let ERC1155Amounts: Array<number>
      ERC1155Amounts = [2, 1]
      let triggerPrices2: Array<number>
      triggerPrices2 = [100, 200]
      await converter.connect(bob).deposit(bobTokenIds, ERC1155Amounts, triggerPrices2, nft2.address)
      await converter.connect(bob).issue()
      await converter.connect(bob).approve(auctionHandler.address, 1000)

      await factory.connect(alice).setAuctionHandler(auctionHandler.address)
    })

    it('start new auction', async () => {
        await expect(auctionHandler.connect(bidder1).newAuction(alice.address, 0, { value: 300 })).to.be.revertedWith('AuctionHandler: uToken contract must be valid')
        await expect(auctionHandler.connect(bidder1).newAuction(converter.address, 5, { value: 300 })).to.be.revertedWith('AuctionHandler: NFT index must exist')
        await expect(auctionHandler.connect(bidder1).newAuction(converter.address, 0, { value: 200 })).to.be.revertedWith('AuctionHandler: Starting bid must be higher than trigger price')
        await expect(await auctionHandler.connect(bidder1).newAuction(converter.address, 0, { value: 300 })).to.changeEtherBalances([bidder1, fees], [-300, 3])
        await expect(auctionHandler.connect(bidder1).newAuction(converter.address, 0, { value: 300 })).to.be.revertedWith('AuctionHandler: NFT already on auction')
    
        expect((await auctionHandler.bids(0))[0]).to.be.eq(bidder1.address)
        expect((await auctionHandler.bids(0))[1]).to.be.eq(300)
        expect(await auctionHandler.auctionStarted(converter.address, 0)).to.be.eq(true)
        expect((await auctionHandler.auctionInfo(0))[1].toNumber() - (await auctionHandler.auctionInfo(0))[0].toNumber()).to.be.eq(await auctionHandler.duration())
        expect((await auctionHandler.auctionInfo(0))[2]).to.be.eq(converter.address)
        expect((await auctionHandler.auctionInfo(0))[3]).to.be.eq(0)
        expect((await auctionHandler.auctionInfo(0))[4]).to.be.eq(false)
        expect(await auctionHandler.vaultBalances(converter.address)).to.be.eq(297)
    })

    it('bid and unbid', async () => {
      // Bidder 1 bids on NFT 0
      await expect(await auctionHandler.connect(bidder1).newAuction(converter.address, 0, { value: 300 })).to.changeEtherBalances([bidder1, fees], [-300, 3])
      expect(await auctionHandler.vaultBalances(converter.address)).to.be.eq(297)
      // Bidder 2 bids on NFT 3
      await expect(await auctionHandler.connect(bidder2).newAuction(converter.address, 3, { value: 100 })).to.changeEtherBalances([bidder2, fees], [-100, 1])
      expect(await auctionHandler.vaultBalances(converter.address)).to.be.eq(396)

      // Check bid data for auction ID 0
      expect((await auctionHandler.bids(0))[0]).to.be.eq(bidder1.address)
      expect((await auctionHandler.bids(0))[1]).to.be.eq(300)
      // Check bid data for auction ID 1
      expect((await auctionHandler.bids(1))[0]).to.be.eq(bidder2.address)
      expect((await auctionHandler.bids(1))[1]).to.be.eq(100)

      await expect(auctionHandler.connect(bidder1).bid(0, { value: 301 })).to.be.revertedWith('AuctionHandler: You have an active bid')
      await expect(auctionHandler.connect(bidder2).bid(0, { value: 301 })).to.be.revertedWith('AuctionHandler: Bid too low')

      // Fee on this gets rounded to 0
      await expect(await auctionHandler.connect(bidder2).bid(0, { value: 315 })).to.changeEtherBalances([bidder2, fees], [-315, 0])
      expect((await auctionHandler.bids(0))[0]).to.be.eq(bidder2.address)
      expect((await auctionHandler.bids(0))[1]).to.be.eq(315)
      expect(await auctionHandler.vaultBalances(converter.address)).to.be.eq(411)
      await expect(auctionHandler.connect(bidder1).bid(0, { value: 500 })).to.be.revertedWith('AuctionHandler: Collect bid refund first')

      expect(await auctionHandler.bidRefunds(0, bidder1.address)).to.be.eq(300)
      // Bidder 1 unbids
      await expect(await auctionHandler.connect(bidder1).unbid(0)).to.changeEtherBalance(bidder1, 300)
      await expect(auctionHandler.connect(bidder1).unbid(0)).to.be.revertedWith('AuctionHandler: No bid found')
      await expect(auctionHandler.connect(bidder2).unbid(0)).to.be.revertedWith('AuctionHandler: Top bidder can not unbid')

      let endTime = (await auctionHandler.auctionInfo(0))[1].toNumber()
      await mineBlock(provider, (endTime - 1))

      // Bid last moment - fee gets rounded down to 1
      await expect(await auctionHandler.connect(bidder1).bid(0, { value: 500 })).to.changeEtherBalances([bidder1, fees], [-500, 1])
      let newEndTime = (await auctionHandler.auctionInfo(0))[1].toNumber()
      expect(endTime).to.be.lt(newEndTime)

      expect(await auctionHandler.vaultBalances(converter.address)).to.be.eq(595)

      await mineBlock(provider, ((await auctionHandler.auctionInfo(0))[1].toNumber() + 1))
      await expect(auctionHandler.connect(bidder1).bid(0, { value: 1000 })).to.be.revertedWith('AuctionHandler: Auction for NFT ended')
    })

    it('claim', async () => {
        await expect(await auctionHandler.connect(bidder1).newAuction(converter.address, 0, { value: 300 })).to.changeEtherBalances([bidder1, fees], [-300, 3])
        await expect(await auctionHandler.connect(bidder2).newAuction(converter.address, 3, { value: 100 })).to.changeEtherBalances([bidder2, fees], [-100, 1])
        await expect(auctionHandler.connect(bidder1).claim(0)).to.be.revertedWith('AuctionHandler: Auction is not over')
        await mineBlock(provider, ((await auctionHandler.auctionInfo(0))[1].toNumber() + 1))
        await expect(auctionHandler.connect(bidder2).claim(0)).to.be.revertedWith('AuctionHandler: Only winner can claim')
        expect(await nft1.balanceOf(bidder1.address)).to.be.eq(0)
        expect(await nft2.balanceOf(bidder2.address, 0)).to.be.eq(0)
    
        await auctionHandler.connect(bidder1).claim(0)
        await auctionHandler.connect(bidder2).claim(1)

        expect((await auctionHandler.auctionInfo(0))[4]).to.be.eq(true)
        expect((await auctionHandler.auctionInfo(1))[4]).to.be.eq(true)
        expect(await nft1.balanceOf(bidder1.address)).to.be.eq(1)
        expect(await nft2.balanceOf(bidder2.address, 0)).to.be.eq(2)

        await expect(auctionHandler.connect(bidder1).claim(0)).to.be.revertedWith('AuctionHandler: Already claimed')
    })

    it('burn and redeem', async () => {
        await expect(auctionHandler.connect(bob).burnAndRedeem(converter.address, 100)).to.be.revertedWith('AuctionHandler: No vault balance to redeem from')
        await expect(await auctionHandler.connect(bidder1).newAuction(converter.address, 0, { value: 300 })).to.changeEtherBalances([bidder1, fees], [-300, 3])
        await expect(await auctionHandler.connect(bidder2).newAuction(converter.address, 3, { value: 100 })).to.changeEtherBalances([bidder2, fees], [-100, 1])
        expect(await auctionHandler.vaultBalances(converter.address)).to.be.eq(396)
        
        // Burn 10% of supply
        await expect(await auctionHandler.connect(bob).burnAndRedeem(converter.address, 100)).to.changeEtherBalances([bob, auctionHandler], [39, -39])
        expect(await converter.balanceOf(bob.address)).to.be.eq(900)
        expect(await converter.totalSupply()).to.be.eq(900)
        expect(await auctionHandler.vaultBalances(converter.address)).to.be.eq(357)
    })
})
