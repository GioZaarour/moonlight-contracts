/*import chai, { expect } from 'chai'
import { createFixtureLoader, deployContract, MockProvider, solidity } from 'ethereum-waffle'
import { governanceFixture } from './fixtures'
import { Contract, ContractFactory, utils, constants } from 'ethers'
import UnicFactory from '../build/UnicFactory.json'
import UnicStakingV6 from '../build/UnicStakingV6.json'
import UnicStakingERC721 from '../build/UnicStakingERC721.json'
import MockERC20 from '../build/MockERC20.json'
import Converter from '../build/Converter.json'
import { mineBlock, mineBlocks } from './utils'

chai.use(solidity)

const overrides = {
  gasLimit: 9999999
}

describe('UnicStakingV6', () => {
  const provider = new MockProvider({
    ganacheOptions: {
      hardfork: 'istanbul',
      mnemonic: 'horn horn horn horn horn horn horn horn horn horn horn horn',
      gasLimit: 99999999,
    },
  })
  const [alice, nonOwner, minter, stakerHarold, stakerWilly] = provider.getWallets()
  const loadFixture = createFixtureLoader([alice], provider)

  let unic: Contract
  let nftCollection: Contract
  let staking: Contract
  let uToken: Contract
  let uTokenFake: Contract
  let factory: Contract

  beforeEach(async () => {
    const fixture = await loadFixture(governanceFixture)
    unic = fixture.unic

    await unic.mint(minter.address, 100000000)

    nftCollection = await deployContract(alice, UnicStakingERC721, ['UnicStakingCollection', 'UNIC-721', 'https://721.unic.ly'], overrides)

    // in fact the staking would not only work for UNIC only but also for xUNIC or any other desired ERC-20 token
    staking = await deployContract(alice, UnicStakingV6, [], overrides)
    await staking.initialize(unic.address, nftCollection.address, 1, 100)

    uTokenFake = await deployContract(alice, MockERC20, ['Fake uToken', 'uFAKE', 10000000000], overrides)

    // grant the staking role to the minting contract
    await nftCollection.grantRole(utils.keccak256(utils.toUtf8Bytes('MINTER_ROLE')), staking.address)

    factory = await deployContract(alice, UnicFactory, [alice.address], overrides)

    // create a first uToken because we had to implement a workaround in the staking contract
    await factory.createUToken(10000000000, 18, 'First uToken', 'uFIRST', 5000000000, '', false)

    const uTokenTx = await factory.createUToken(10000000000, 18, 'Sample uToken', 'uSAMPLE', 5000000000, '', false)
    const uTokenTxReceipt = await uTokenTx.wait();
    const uTokenAddress = uTokenTxReceipt.events.find((e: any) => e.event == 'TokenCreated').args.uToken

    uToken = new ContractFactory(Converter.abi, Converter.bytecode, alice).attach(uTokenAddress)
    await uToken.issue();

    await staking.setUnicFactory(factory.address)
  })

  it('should fix bug where the withdraw was not working properly', async () => {
    await staking.createPool(uToken.address);
    await staking.connect(alice).setLockMultiplier(0, 100);
    await staking.connect(alice).setMinStakeAmount(100);

    await unic.transfer(stakerHarold.address, 500);
    await unic.connect(stakerHarold).approve(staking.address, 500);
    await unic.transfer(stakerWilly.address, 1000);
    await unic.connect(stakerWilly).approve(staking.address, 500);

    const stakedHarold = await staking.connect(stakerHarold).stake(500, 0, uToken.address);
    const stakedHaroldReceipt = await stakedHarold.wait();
    const haroldEvent = stakedHaroldReceipt.events.find((e: any) => e.event === 'Staked');
    const haroldNftId = haroldEvent.args.nftId.toString();
    console.log('haroldNftId', haroldNftId);

    await uToken.approve(staking.address, 1000);
    await staking.addRewards(uToken.address, 1000);

    const currentBlock = await provider.getBlock('latest')
    await mineBlocks(provider, (currentBlock.timestamp + 1), currentBlock.number + 1);

    const pendingRewardHarold = (await staking.pendingReward(haroldNftId)).toString();
    expect(pendingRewardHarold).to.equal('1000');

    const stakedWilly = await staking.connect(stakerWilly).stake(500, 0, uToken.address);
    await stakedWilly.wait();

    const pendingRewardHaroldUpdated = (await staking.pendingReward(haroldNftId)).toString();
    expect(pendingRewardHaroldUpdated).to.equal('1000');

    await nftCollection.connect(stakerHarold).approve(staking.address, haroldNftId);
    await staking.connect(stakerHarold).withdraw(haroldNftId);

    const balanceHarold = (await unic.balanceOf(stakerHarold.address)).toString();
    expect(balanceHarold).to.equal('500');

    const balanceHarold2 = (await uToken.balanceOf(stakerHarold.address)).toString();
    expect(balanceHarold2).to.equal('1000');
  });
});
*/