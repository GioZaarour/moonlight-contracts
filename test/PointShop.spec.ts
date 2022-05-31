/*import chai, { expect } from 'chai'
import { BigNumber, Contract, constants, utils } from 'ethers'
import { solidity, MockProvider, createFixtureLoader, deployContract } from 'ethereum-waffle'

import { governanceFixture } from './fixtures'
import { expandTo18Decimals, mineBlock } from './utils'

import PointShop from '../build/PointShop.json'
import PointFarm from '../build/PointFarm.json'
import MockERC20 from '../build/MockERC20.json'
import UnicFactory from '../build/UnicFactory.json'
import Converter from '../build/Converter.json'
import MockERC721 from '../build/MockERC721.json'

const overrides = {
    gasLimit: 9999999
  }
  
  describe('PointShop', () => {
    const provider = new MockProvider({
      ganacheOptions: {
        hardfork: 'istanbul',
        mnemonic: 'horn horn horn horn horn horn horn horn horn horn horn horn',
        gasLimit: 99999999,
      },
    })
    const [alice, bob, carol, issuer, minter] = provider.getWallets()
    const loadFixture = createFixtureLoader([alice], provider)
  
    let pointShop: Contract
    let pointFarm: Contract
    let factory: Contract
    let converter: Contract
    let nft1: Contract

    beforeEach(async () => {
      pointFarm = await deployContract(alice, PointFarm, [1, 1, ""], overrides)
      pointShop = await deployContract(alice, PointShop, [pointFarm.address], overrides)
      await pointFarm.connect(alice).setShop(pointShop.address)
      expect(await pointFarm.shop()).to.be.eq(pointShop.address)

      factory = await deployContract(alice, UnicFactory, [alice.address], overrides)
      await factory.connect(issuer).createUToken(1000, 18, 'Star Wars Collection', 'uSTAR', 950, 'Leia\'s Star Wars NFT Collection', false)
      const converterAddress = await factory.uTokens(0)
      converter = new Contract(converterAddress, JSON.stringify(Converter.abi), provider)

      nft1 = await deployContract(minter, MockERC721, ['Star Wars NFTs', 'STAR'], overrides)
      // 3 NFTs for Bob
      await nft1.connect(minter).mint(issuer.address, 0)
      await nft1.connect(minter).mint(issuer.address, 1)
      await nft1.connect(minter).mint(issuer.address, 2)
      // 3 NFTs for Issuer
      await nft1.connect(minter).mint(issuer.address, 3)
      await nft1.connect(minter).mint(issuer.address, 4)
      await nft1.connect(minter).mint(issuer.address, 5)

      await nft1.connect(bob).setApprovalForAll(pointShop.address, true)
      await nft1.connect(issuer).setApprovalForAll(pointShop.address, true)
    })

    it('admin functions', async () => {
      await expect(pointShop.connect(alice).setConstraints(converter.address, nft1.address, [0, 1, 3, 4], true, false)).to.be.revertedWith('PointShop: Only shop admin can set constraints')
      await pointShop.connect(issuer).setConstraints(converter.address, nft1.address, [0, 1, 3, 4], true, false)
      
      expect(await pointShop.allowedNFTs(converter.address, nft1.address, 0)).to.be.eq(true)
      expect(await pointShop.allowedNFTs(converter.address, nft1.address, 1)).to.be.eq(true)
      expect(await pointShop.allowedNFTs(converter.address, nft1.address, 2)).to.be.eq(false)

      await pointShop.connect(issuer).setConstraints(converter.address, nft1.address, [0, 1, 3, 4], false, false)
      expect(await pointShop.allowedNFTs(converter.address, nft1.address, 0)).to.be.eq(false)
      expect(await pointShop.allowedNFTs(converter.address, nft1.address, 1)).to.be.eq(false)

      await pointShop.connect(issuer).setConstraints(converter.address, nft1.address, [0, 1, 3, 4], false, true)
      expect(await pointShop.notAnyAllowed(converter.address)).to.be.eq(true)

      await expect(pointShop.connect(alice).setAdmin(converter.address, [alice.address, bob.address], true)).to.be.revertedWith('PointShop: Only issuer can set this permission')
      await pointShop.connect(issuer).setAdmin(converter.address, [alice.address, bob.address], true)
      expect(await pointShop.isShopAdmin(converter.address, alice.address)).to.be.eq(true)
      expect(await pointShop.isShopAdmin(converter.address, bob.address)).to.be.eq(true)
      expect(await pointShop.isShopAdmin(converter.address, carol.address)).to.be.eq(false)

      await expect(pointShop.connect(carol).setPublic(converter.address, true)).to.be.revertedWith('PointShop: Only shop admin can set this permission')
      await pointShop.connect(alice).setPublic(converter.address, true)
      expect(await pointShop.isPublic(converter.address)).to.be.eq(true)

      await pointShop.connect(issuer).setAdmin(converter.address, [alice.address], false)
      expect(await pointShop.isShopAdmin(converter.address, alice.address)).to.be.eq(false)
    })

    it('deposit and modify shop', async () => {
      await pointShop.connect(issuer).setConstraints(converter.address, nft1.address, [0, 1, 3, 4], true, false)
      await pointShop.connect(issuer).deposit(converter.address, [0, 1], [1, 1], [1, 1], nft1.address)
      expect((await pointShop.nfts(converter.address, 0)).contractAddr).to.be.eq(nft1.address)
      expect((await pointShop.nfts(converter.address, 1)).amount).to.be.eq(1)
      await expect(pointShop.connect(alice).deposit(converter.address, [0, 1, 3, 4], [1, 1, 1, 1], [1, 1, 1, 1], nft1.address)).to.be.revertedWith('PointShop: Only shop admin can add to shop')
      
      await pointShop.connect(issuer).setConstraints(converter.address, nft1.address, [], true, false)
      await pointShop.connect(issuer).deposit(converter.address, [2, 5], [1, 1], [1, 1], nft1.address)
      expect((await pointShop.nfts(converter.address, 2)).tokenId).to.be.eq(2)
      expect((await pointShop.nfts(converter.address, 3)).price).to.be.eq(1)

      await pointShop.connect(issuer).setAdmin(converter.address, [alice.address, bob.address], true)
      await expect(pointShop.connect(carol).modifyShop(converter.address, [0, 1, 2, 3], [3, 5, 1, 2])).to.be.revertedWith('PointShop: Only shop admin can modify shop')
      await pointShop.connect(alice).modifyShop(converter.address, [0, 1, 2, 3], [3, 5, 1, 2])
      expect((await pointShop.nfts(converter.address, 0)).price).to.be.eq(3)
      expect((await pointShop.nfts(converter.address, 1)).price).to.be.eq(5)
      expect((await pointShop.nfts(converter.address, 2)).price).to.be.eq(1)
      expect((await pointShop.nfts(converter.address, 3)).price).to.be.eq(2)

      await pointShop.connect(issuer).setConstraints(converter.address, nft1.address, [], true, true)
      await expect(pointShop.connect(issuer).deposit(converter.address, [0, 1, 2, 3], [1, 1, 1, 1], [1, 1, 1, 1], nft1.address)).to.be.revertedWith('PointShop: Attempted deposit of non-whitelisted NFT')
    })

    it('add', async () => {
      await pointShop.connect(issuer).add(converter.address, false)
      await expect(pointShop.connect(issuer).add(converter.address, false)).to.be.revertedWith('PointShop: Already added')
      expect(await pointShop.shopExists(converter.address)).to.be.eq(true)
      expect(await pointFarm.whitelist(converter.address)).to.be.eq(true)
    })
})*/