/*import chai, { expect } from 'chai'
import { BigNumber, Contract, constants, utils } from 'ethers'
import { solidity, MockProvider, createFixtureLoader, deployContract } from 'ethereum-waffle'

import { governanceFixture } from './fixtures'
import { expandTo18Decimals, mineBlock, mineBlocks } from './utils'

import PointShop from '../build/PointShop.json'
import PointFarm from '../build/PointFarm.json'
import MockERC20 from '../build/MockERC20.json'
import UnicFactory from '../build/UnicFactory.json'
import Converter from '../build/Converter.json'
import MockERC721 from '../build/MockERC721.json'

const overrides = {
    gasLimit: 9999999
  }
  
  describe('PointFarm', () => {
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
      await pointFarm.connect(issuer).setApprovalForAll(pointShop.address, true)

      await pointShop.connect(issuer).setConstraints(converter.address, nft1.address, [], true, false)
      await pointShop.connect(issuer).deposit(converter.address, [0, 1, 2, 3, 4, 5], [1, 1, 1, 1, 1, 1], [1, 1, 1, 1, 1, 1], nft1.address)
      await pointShop.connect(issuer).add(converter.address, false)

      await converter.connect(issuer).issue()
      await converter.connect(issuer).approve(pointFarm.address, 1000)
    })

    it('farm points with uTokens and redeem in shop', async () => {
      await pointFarm.connect(issuer).deposit(0, 10)

      let currentBlock = await provider.getBlock('latest')
      await mineBlock(provider, (currentBlock.timestamp + 1))
      // Alice should have 10*1 pending reward
      expect(await pointFarm.pendingPoints(0, issuer.address)).to.be.eq(1)

      await mineBlock(provider, (currentBlock.timestamp + 1))
      expect(await pointFarm.pendingPoints(0, issuer.address)).to.be.eq(2)
      await pointFarm.connect(issuer).deposit(0, 0)

      expect(await pointFarm.balanceOf(issuer.address, 0)).to.be.eq(3)

      await expect(pointFarm.connect(issuer).safeTransferFrom(issuer.address, alice.address, 0, 1, '0x00')).to.be.revertedWith('Points can not be transferred out')

      await pointShop.connect(issuer).redeem(converter.address, 0)
      expect(await pointFarm.balanceOf(issuer.address, 0)).to.be.eq(2)
      expect(await nft1.balanceOf(issuer.address)).to.be.eq(1)
    })

    it('should allow emergency withdraw', async () => {
      await pointFarm.connect(issuer).deposit(0, 10)
      expect(await converter.balanceOf(issuer.address)).to.be.eq(990)
      await pointFarm.connect(issuer).emergencyWithdraw(0)
      expect(await converter.balanceOf(issuer.address)).to.be.eq(1000)
    })
})*/