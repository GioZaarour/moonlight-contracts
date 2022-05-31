import chai, { expect } from 'chai'
import { BigNumber, Contract, constants, utils } from 'ethers'
import { solidity, MockProvider, createFixtureLoader, deployContract } from 'ethereum-waffle'

import { expandTo18Decimals, mineBlock, mineBlocks } from './utils'

import UnicFactory from '../build/UnicFactory.json'
import Converter from '../build/Converter.json'
import ProxyCreator from '../build/ProxyCreator.json'
import MockERC721 from '../build/MockERC721.json'
import MockERC1155 from '../build/MockERC1155.json'
import MockERC20 from '../build/MockERC20.json'
import AuctionHandler from '../build/AuctionHandler.json'

chai.use(solidity)

const overrides = {
  gasLimit: 9999999
}

let emptyArray: Array<number>
emptyArray = []

describe('Converter', () => {
    const provider = new MockProvider({
      ganacheOptions: {
        hardfork: 'istanbul',
        mnemonic: 'horn horn horn horn horn horn horn horn horn horn horn horn',
        gasLimit: 99999999,
      },
    })
    const [alice, bob, carol, minter, fees] = provider.getWallets()
  
    let factory: Contract
    let converter: Contract
    let converter2: Contract
    let converter3: Contract
    let nft1: Contract
    let nft2: Contract
    let proxyCreator: Contract
    let unic: Contract
    let converterImpl: Contract
    let auctionHandler: Contract
  
    beforeEach(async () => {
      unic = await deployContract(alice, MockERC20, ['UNIC', 'UNIC', '1000000000000000000000000'], overrides);
      converterImpl = await deployContract(alice, Converter, [], overrides);
      factory = await deployContract(alice, UnicFactory, [], overrides);
      await unic.connect(alice).transfer(factory.address, '1000000000000000000000000')
      await factory.connect(alice).initialize(alice.address, 100, 1000, unic.address, constants.AddressZero);
      await factory.connect(alice).setConverterImplementation(converterImpl.address);
      await factory.connect(bob).createUToken('Star Wars Collection', 'uSTAR', false, overrides)
      auctionHandler = await deployContract(alice, AuctionHandler, [], overrides)
      await auctionHandler.connect(alice).initialize(factory.address, 10, 105, 2, 100, fees.address, fees.address)
      const converterAddress = await factory.uTokens(0)
      converter = new Contract(converterAddress, JSON.stringify(Converter.abi), provider)

      await factory.connect(carol).createUToken('Leia Collection', 'uLEIA', false, overrides)
      const converter2Address = await factory.uTokens(1)
      converter2 = new Contract(converter2Address, JSON.stringify(Converter.abi), provider)

      nft1 = await deployContract(minter, MockERC721, ['Star Wars NFTs', 'STAR'], overrides)
      nft2 = await deployContract(minter, MockERC1155, [], overrides)

      await factory.connect(alice).setAirdropCollections([nft1.address, nft2.address], true)
      
      // 3 NFTs for Bob
      await nft1.connect(minter).mint(bob.address, 0)
      await nft1.connect(minter).mint(bob.address, 1)
      await nft1.connect(minter).mint(bob.address, 2)
      // 3 more NFTs for Bob
      await nft2.connect(minter).mint(bob.address, 0, 2, emptyArray)
      await nft2.connect(minter).mint(bob.address, 1, 1, emptyArray)

      await nft1.connect(bob).setApprovalForAll(converter.address, true)
      await nft2.connect(bob).setApprovalForAll(converter.address, true)

      // 3 NFTs for Carol
      await nft1.connect(minter).mint(carol.address, 3)
      await nft1.connect(minter).mint(carol.address, 4)
      await nft1.connect(minter).mint(carol.address, 5)
      // 3 more NFTs for Carol
      await nft2.connect(minter).mint(carol.address, 2, 2, emptyArray)
      await nft2.connect(minter).mint(carol.address, 3, 1, emptyArray)

      await nft1.connect(carol).setApprovalForAll(converter2.address, true)
      await nft2.connect(carol).setApprovalForAll(converter2.address, true)

      await factory.connect(alice).setAuctionHandler(auctionHandler.address)
      await factory.connect(alice).toggleAirdrop()
    })
  
    it('state variables', async () => {
        // totalSupply is 0 until the issue function is called
        expect(await converter.totalSupply()).to.be.eq(0)
        expect(await converter.decimals()).to.be.eq(18)
        expect(await converter.name()).to.be.eq('Star Wars Collection')
        expect(await converter.symbol()).to.be.eq('uSTAR')
        expect(await converter.issuer()).to.be.eq(bob.address)
        expect(await converter.factory()).to.be.eq(factory.address)

        expect(await converter2.totalSupply()).to.be.eq(0)
        expect(await converter2.decimals()).to.be.eq(18)
        expect(await converter2.name()).to.be.eq('Leia Collection')
        expect(await converter2.symbol()).to.be.eq('uLEIA')
        expect(await converter2.issuer()).to.be.eq(carol.address)
        expect(await converter.factory()).to.be.eq(factory.address)
    })

    it('issue', async () => {
      await expect(converter.connect(alice).issue()).to.be.revertedWith('Converter: Only issuer can issue the tokens')

      await converter.connect(bob).issue()
      expect(await converter.balanceOf(bob.address)).to.be.eq(1000)
      expect(await converter.totalSupply()).to.be.eq(1000)

      await expect(converter.connect(bob).issue()).to.be.revertedWith('Converter: Token is already active')

      await converter2.connect(carol).issue()
      expect(await converter2.balanceOf(carol.address)).to.be.eq(1000)
      expect(await converter2.totalSupply()).to.be.eq(1000)

      expect(await converter.active()).to.be.eq(true)
      expect(await converter2.active()).to.be.eq(true)
    })

    it('issue after fee is on', async () => {
      await factory.connect(alice).setFeeTo(alice.address)

      await converter.connect(bob).issue()
      expect(await converter.balanceOf(alice.address)).to.be.eq(10)
      expect(await converter.balanceOf(bob.address)).to.be.eq(990)

      await converter2.connect(carol).issue()
      expect(await converter2.balanceOf(alice.address)).to.be.eq(10)
      expect(await converter2.balanceOf(carol.address)).to.be.eq(990)
    })

    it('deposit', async () => {
      expect(await nft1.isApprovedForAll(bob.address, converter.address)).to.be.eq(true)
      expect(await nft2.isApprovedForAll(bob.address, converter.address)).to.be.eq(true)
      expect(await nft1.isApprovedForAll(carol.address, converter2.address)).to.be.eq(true)
      expect(await nft2.isApprovedForAll(carol.address, converter2.address)).to.be.eq(true)

      expect(await nft1.balanceOf(bob.address)).to.be.eq(3)
      expect(await nft2.balanceOf(bob.address, 0)).to.be.eq(2)
      expect(await nft2.balanceOf(bob.address, 1)).to.be.eq(1)

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
      expect(await converter.currentNFTIndex()).to.be.eq(5)
      await mineBlock(provider, (await provider.getBlock('latest')).timestamp + 1)

      expect(await nft1.balanceOf(bob.address)).to.be.eq(0)
      expect(await nft2.balanceOf(bob.address, 0)).to.be.eq(0)
      expect(await nft2.balanceOf(bob.address, 1)).to.be.eq(0)
      expect(await nft1.balanceOf(converter.address)).to.be.eq(3)
      expect(await nft2.balanceOf(converter.address, 0)).to.be.eq(2)
      expect(await nft2.balanceOf(converter.address, 1)).to.be.eq(1)

      // 1st token is token ID 0 for nft1
      expect((await converter.nfts(0)).tokenId).to.be.eq(0)
      // 4th token is token ID 0 for nft2
      expect((await converter.nfts(3)).tokenId).to.be.eq(0)
      // 4th token is ERC1155 and we sent 2 of them
      expect((await converter.nfts(3)).amount).to.be.eq(2)
      // 4th token has trigger price of 100
      expect((await converter.nfts(3)).triggerPrice).to.be.eq(100)

      // Check that it works for other people and other NFTs too
      let carolTokenIds: Array<number>
      carolTokenIds = [3, 4, 5]
      let triggerPrices3: Array<number>
      triggerPrices3 = [2000, 3000, 5000]
      await converter2.connect(carol).deposit(carolTokenIds, emptyArray, triggerPrices3, nft1.address)
      await mineBlock(provider, (await provider.getBlock('latest')).timestamp + 1)
      carolTokenIds = [2, 3]
      let triggerPrices4: Array<number>
      triggerPrices4 = [10000, 20000]
      await converter2.connect(carol).deposit(carolTokenIds, ERC1155Amounts, triggerPrices4, nft2.address)
      expect(await converter2.currentNFTIndex()).to.be.eq(5)
    })

    it('refund', async () => {
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
      triggerPrices2 = [300, 500]
      await converter.connect(bob).deposit(bobTokenIds, ERC1155Amounts, triggerPrices2, nft2.address)
      expect(await converter.currentNFTIndex()).to.be.eq(5)
      await mineBlock(provider, (await provider.getBlock('latest')).timestamp + 1)

      await expect(converter.connect(carol).refund(carol.address)).to.be.revertedWith('Converter: Only issuer can refund')
      await converter.connect(bob).refund(bob.address)
      await mineBlock(provider, (await provider.getBlock('latest')).timestamp + 1)
      expect(await converter.currentNFTIndex()).to.be.eq(0)

      expect(await nft1.balanceOf(bob.address)).to.be.eq(3)
      expect(await nft2.balanceOf(bob.address, 0)).to.be.eq(2)
      expect(await nft2.balanceOf(bob.address, 1)).to.be.eq(1)
      expect(await nft1.balanceOf(converter.address)).to.be.eq(0)
      expect(await nft2.balanceOf(converter.address, 0)).to.be.eq(0)
      expect(await nft2.balanceOf(converter.address, 1)).to.be.eq(0)

      await converter.connect(bob).issue()
      expect(await converter.balanceOf(bob.address)).to.be.eq(1000)
      expect(await converter.totalSupply()).to.be.eq(1000)

      await expect(converter.connect(bob).refund(bob.address)).to.be.revertedWith('Converter: Contract is already active - cannot refund')
    })

    it('deposit after issue', async () => {
      let bobTokenIds: Array<number>
      bobTokenIds = [0, 1, 2]
      let triggerPrices: Array<number>
      triggerPrices = [300, 500, 1000]
      await mineBlock(provider, (await provider.getBlock('latest')).timestamp + 1)
      await converter.connect(bob).deposit(bobTokenIds, emptyArray, triggerPrices, nft1.address)
      await mineBlock(provider, (await provider.getBlock('latest')).timestamp + 1)

      let carolTokenIds: Array<number>
      carolTokenIds = [3, 4, 5]
      await expect(converter.connect(carol).deposit(carolTokenIds, emptyArray, triggerPrices, nft1.address)).to.be.revertedWith('Converter: Only issuer can deposit')

      expect(await unic.balanceOf(bob.address)).to.be.eq(0)
      await converter.connect(bob).issue()
      expect(await unic.balanceOf(bob.address)).to.be.eq('100000000000000000000')
      bobTokenIds = [0, 1]

      let ERC1155Amounts: Array<number>
      ERC1155Amounts = [2, 1]
      let triggerPrices2: Array<number>
      triggerPrices2 = [300, 500]
      await converter.connect(bob).deposit(bobTokenIds, ERC1155Amounts, triggerPrices2, nft2.address)
      expect(await converter.currentNFTIndex()).to.be.eq(5)
      // 1st token is token ID 0 for nft1
      expect((await converter.nfts(0)).tokenId).to.be.eq(0)
      // 4th token is token ID 0 for nft2
      expect((await converter.nfts(3)).tokenId).to.be.eq(0)
      // 4th token is ERC1155 and we sent 2 of them
      expect((await converter.nfts(3)).amount).to.be.eq(2)
    })

    it('set vault creator', async () => {
      expect(await converter.issuer()).to.be.eq(bob.address)
      await expect(converter.connect(carol).setCurator(alice.address)).to.be.revertedWith('Converter: Tokens have not been issued yet')
      await converter.connect(bob).issue()
      await expect(converter.connect(carol).setCurator(alice.address)).to.be.revertedWith('Converter: Not vault manager or issuer')
      await converter.connect(bob).setCurator(carol.address)
      expect(await converter.issuer()).to.be.eq(carol.address)
      await converter.connect(alice).setCurator(alice.address)
      expect(await converter.issuer()).to.be.eq(alice.address)
    })

    it('set triggers', async () => {
      let bobTokenIds: Array<number>
      bobTokenIds = [0, 1, 2]
      let triggerPrices: Array<number>
      triggerPrices = [300, 500, 1000]
      await mineBlock(provider, (await provider.getBlock('latest')).timestamp + 1)
      await converter.connect(bob).deposit(bobTokenIds, emptyArray, triggerPrices, nft1.address)
      await mineBlock(provider, (await provider.getBlock('latest')).timestamp + 1)

      let triggerPrices2: Array<number> = [100, 200, 300]
      await expect(converter.connect(carol).setTriggers(bobTokenIds, triggerPrices2)).to.be.revertedWith('Converter: Only issuer can set trigger prices')
      await converter.connect(bob).setTriggers(bobTokenIds, triggerPrices2)
      expect((await converter.nfts(0)).triggerPrice).to.be.eq(100)
      expect((await converter.nfts(1)).triggerPrice).to.be.eq(200)
      expect((await converter.nfts(2)).triggerPrice).to.be.eq(300)
    })

    // it('proxy creator', async () => {
    //   proxyCreator = await deployContract(alice, ProxyCreator, [factory.address], overrides)
    //   await proxyCreator.connect(alice).create(1000, 18, 'Star Wars Collection', 'uSTAR', 950, 'Leia\'s Star Wars NFT Collection')
    //   await proxyCreator.connect(alice).setWhiteList([], true, true)
    //   await proxyCreator.connect(alice).setConstraints(nft1.address, true, [], true, false)
    //   await proxyCreator.connect(alice).issue()
    //   const converterAddr = await factory.uTokens(2)
    //   converter3 = new Contract(converterAddr, JSON.stringify(Converter.abi), provider)
    //   await nft1.connect(bob).setApprovalForAll(proxyCreator.address, true)
    //   await proxyCreator.connect(bob).deposit([0, 1, 2], [1, 1, 1], nft1.address)
    //   expect(await nft1.balanceOf(converter3.address)).to.be.eq(3)
    //   expect((await converter3.nfts(0)).amount).to.be.eq(1)
    // })
})
