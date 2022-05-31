import chai, { expect } from 'chai'
import { constants, Contract, utils, Wallet } from 'ethers'
import { solidity, MockProvider, deployContract } from 'ethereum-waffle'

import UnicFactory from '../build/UnicFactory.json'
import UnicConverterGovernorAlphaFactory from '../build/UnicConverterGovernorAlphaFactory.json'
import UnicConverterProxyTransactionFactory from '../build/UnicConverterProxyTransactionFactory.json'
import Converter from '../build/Converter.json'
import ConverterGovernorAlpha from '../build/ConverterGovernorAlpha.json'
import ConverterGovernorAlphaConfig from '../build/ConverterGovernorAlphaConfig.json'
import MockERC721 from '../build/MockERC721.json'
import MockThirdPartyContract from '../build/MockThirdPartyContract.json'
import { mineBlock, mineBlocks } from './utils'
import MockERC20 from '../build/MockERC20.json'

chai.use(solidity)

const overrides = {
  gasLimit: 9999999,
}

let emptyArray: Array<number>
emptyArray = []

// The states as defined in ConverterGovernorAlpha
enum ProposalState {
  Pending,
  Active,
  Canceled,
  Defeated,
  Succeeded,
  Queued,
  Expired,
  Executed,
}

describe('ConverterGovernorAlpha', () => {
  const provider = new MockProvider({
    ganacheOptions: {
      hardfork: 'istanbul',
      mnemonic: 'horn horn horn horn horn horn horn horn horn horn horn horn',
      gasLimit: 99999999,
    },
  })
  const [collectionCreator, alice, bob, carol, minter] = provider.getWallets()

  let unic: Contract
  let converterImpl: Contract
  let config: Contract
  let factory: Contract
  let proxyTransactionFactory: Contract
  let converter: Contract
  let governorAlpha: Contract
  let nft: Contract
  let thirdParty: Contract

  beforeEach(async () => {
    unic = await deployContract(alice, MockERC20, ['UNIC', 'UNIC', '1000000000000000000000000'], overrides)

    config = await deployContract(alice, ConverterGovernorAlphaConfig, [], overrides)
    await config.setVotingPeriod(200)
    await config.setVotingDelay(1)

    const governorAlphaFactory = await deployContract(alice, UnicConverterGovernorAlphaFactory, [], overrides)
    proxyTransactionFactory = await deployContract(alice, UnicConverterProxyTransactionFactory, [config.address, governorAlphaFactory.address], overrides)

    converterImpl = await deployContract(alice, Converter, [], overrides);

    factory = await deployContract(alice, UnicFactory, [], overrides)
    await factory.connect(alice).initialize(alice.address, 100, 1000, unic.address, proxyTransactionFactory.address)
    await factory.connect(alice).setConverterImplementation(converterImpl.address)
    await factory
      .connect(collectionCreator)
      .createUToken(
        'Star Wars Collection',
        'uSTAR',
        true
      )
    const converterAddress = await factory.uTokens(0)
    converter = new Contract(converterAddress, JSON.stringify(Converter.abi), provider)

    const governorAlphaAddress = await factory.getGovernorAlpha(converterAddress)
    governorAlpha = new Contract(governorAlphaAddress, JSON.stringify(ConverterGovernorAlpha.abi), provider)

    nft = await deployContract(minter, MockERC721, ['Star Wars NFTs', 'STAR'], overrides)

    await nft.connect(minter).mint(collectionCreator.address, 0)

    await nft.connect(collectionCreator).setApprovalForAll(converter.address, true)

    await mineBlock(provider, (await provider.getBlock('latest')).timestamp + 1)
    let triggerPrices: Array<number>
    triggerPrices = [100]
    await converter.connect(collectionCreator).deposit([0], emptyArray, triggerPrices, nft.address)
    await mineBlock(provider, (await provider.getBlock('latest')).timestamp + 1)

    await converter.connect(collectionCreator).issue()
    expect(await converter.balanceOf(collectionCreator.address)).to.be.eq(1000)
    expect(await converter.totalSupply()).to.be.eq(1000)

    thirdParty = await deployContract(alice, MockThirdPartyContract, [], overrides)
  })

  async function votingDelay() {
    const timestamp = (await provider.getBlock('latest')).timestamp + 1
    const blocks = (await config.callStatic.votingDelay()).toNumber()
    await mineBlocks(provider, timestamp, blocks)
  }

  async function votingPeriod() {
    const timestamp = (await provider.getBlock('latest')).timestamp + 1
    const blocks = (await config.callStatic.votingPeriod()).toNumber()
    await mineBlocks(provider, timestamp, blocks)
  }

  async function delay() {
    const time = (await config.callStatic.delay()).toNumber()
    const timestamp = (await provider.getBlock('latest')).timestamp + time
    await mineBlocks(provider, timestamp, 1)
  }

  async function gracePeriod() {
    const time = (await config.callStatic.gracePeriod()).toNumber()
    const timestamp = (await provider.getBlock('latest')).timestamp + time
    await mineBlocks(provider, timestamp, 1)
  }

  async function addTestProposal(signer: Wallet) {
    // add a proposal with one transaction that calls verifyOwnership on the thirdParty contract with the nft contract and the token id 0
    await governorAlpha
      .connect(signer)
      .propose(
        [thirdParty.address],
        [0],
        ['verifyOwnership(address,uint256)'],
        [utils.defaultAbiCoder.encode(['address', 'uint256'], [nft.address, 0])],
        'verify the ownership of 0'
      )
  }

  it('Voting right should be adjusted on token transfer', async () => {
    await converter.connect(collectionCreator).delegate(bob.address)
    await converter.connect(collectionCreator).transfer(alice.address, 300)
    await converter.connect(alice).delegate(alice.address)

    // The voting power of the tokens from collectionCreator should be available for bob
    expect(await converter.getCurrentVotes(collectionCreator.address)).to.equal('0')
    expect(await converter.getCurrentVotes(bob.address)).to.equal('700')
    expect(await converter.getCurrentVotes(alice.address)).to.equal('300')

    // The collectionCreator should be able to reclaim its voting power
    await converter.connect(collectionCreator).delegate(collectionCreator.address)

    expect(await converter.getCurrentVotes(collectionCreator.address)).to.equal('700')
    expect(await converter.getCurrentVotes(bob.address)).to.equal('0')
  })

  it('should be possible to execute a proposal', async () => {
    await converter.connect(collectionCreator).delegate(collectionCreator.address)

    await addTestProposal(collectionCreator)
    await votingDelay()
    await governorAlpha.connect(collectionCreator).castVote(1, true)
    await votingPeriod()
    await governorAlpha.connect(collectionCreator).queue(1)
    await delay()

    const receipt = await governorAlpha.connect(collectionCreator).execute(1)
    const result = await receipt.wait()

    // Check whether the verification of ownership was correct (verifyOwnership(address,uint256))
    expect(result.events[0].data).to.equal('0x0000000000000000000000000000000000000000000000000000000000000001')
  })

  it('should not be possible to execute a proposal multiple times', async () => {
    await converter.connect(collectionCreator).delegate(collectionCreator.address)

    await addTestProposal(collectionCreator)
    await votingDelay()
    await governorAlpha.connect(collectionCreator).castVote(1, true)
    await votingPeriod()
    await governorAlpha.connect(collectionCreator).queue(1)
    await delay()

    await governorAlpha.connect(collectionCreator).execute(1)
    // The second execution must be reverted
    await expect(governorAlpha.connect(collectionCreator).execute(1)).to.be.revertedWith(
      'GovernorAlpha::execute: proposal can only be executed if it is queued'
    )
  })

  it('should be possible to execute a complex proposal', async () => {
    await converter.connect(collectionCreator).delegate(collectionCreator.address)
    await converter.connect(collectionCreator).transfer(alice.address, 500)
    expect(await converter.getCurrentVotes(collectionCreator.address)).to.equal('500')
    await converter.connect(alice).delegate(alice.address)
    expect(await converter.getCurrentVotes(alice.address)).to.equal('500')

    // In this case, the proposed transaction contains two separate transactions, one of which transfers ETH
    await governorAlpha
      .connect(collectionCreator)
      .propose(
        [thirdParty.address, thirdParty.address],
        [0, 10],
        ['verifyOwnership(address,uint256)', 'pay()'],
        [utils.defaultAbiCoder.encode(['address', 'uint256'], [nft.address, 0]), utils.defaultAbiCoder.encode([], [])],
        'verify the ownership of 0 and transfer 10*10^-18 eth'
      )

    await votingDelay()
    await governorAlpha.connect(collectionCreator).castVote(1, true)
    await governorAlpha.connect(alice).castVote(1, true)
    await votingPeriod()
    expect(await governorAlpha.state(1)).to.equal(ProposalState.Succeeded)

    await governorAlpha.connect(collectionCreator).queue(1)
    expect(await governorAlpha.state(1)).to.equal(ProposalState.Queued)
    await delay()

    const receipt = await governorAlpha.connect(collectionCreator).execute(1, { value: 10 })
    const result = await receipt.wait()
    expect(await governorAlpha.state(1)).to.equal(ProposalState.Executed)

    // Check whether the verification of ownership was correct (verifyOwnership(address,uint256))
    expect(result.events[0].data).to.equal('0x0000000000000000000000000000000000000000000000000000000000000001')
    // Check if the 10 ETH have been transferred (pay())
    expect(result.events[2].data).to.equal('0x000000000000000000000000000000000000000000000000000000000000000a')
  })

  it('should not be possible to queue a proposal that has been rejected', async () => {
    await converter.connect(collectionCreator).delegate(collectionCreator.address)
    await converter.connect(collectionCreator).transfer(alice.address, 500)
    expect(await converter.getCurrentVotes(collectionCreator.address)).to.equal('500')
    await converter.connect(alice).delegate(alice.address)
    expect(await converter.getCurrentVotes(alice.address)).to.equal('500')

    await addTestProposal(collectionCreator)

    await votingDelay()
    await governorAlpha.connect(collectionCreator).castVote(1, true)
    await governorAlpha.connect(alice).castVote(1, false)
    await votingPeriod()
    expect(await governorAlpha.state(1)).to.equal(ProposalState.Defeated)

    await expect(governorAlpha.connect(collectionCreator).queue(1)).to.be.revertedWith(
      'GovernorAlpha::queue: proposal can only be queued if it is succeeded'
    )
  })

  it('should not be possible to execute a proposal without queueing it', async () => {
    await converter.connect(collectionCreator).delegate(collectionCreator.address)

    await addTestProposal(collectionCreator)
    await votingDelay()
    await governorAlpha.connect(collectionCreator).castVote(1, true)
    await votingPeriod()

    // For safety reasons, all delays and steps must be followed
    await expect(governorAlpha.connect(collectionCreator).execute(1)).to.be.revertedWith(
      'GovernorAlpha::execute: proposal can only be executed if it is queued'
    )
  })

  it('should not be possible to execute a proposal before the time lock has expired', async () => {
    await converter.connect(collectionCreator).delegate(collectionCreator.address)

    await addTestProposal(collectionCreator)
    await votingDelay()
    await governorAlpha.connect(collectionCreator).castVote(1, true)
    await votingPeriod()
    await governorAlpha.connect(collectionCreator).queue(1)

    // For safety reasons, all delays and steps must be followed
    await expect(governorAlpha.connect(collectionCreator).execute(1)).to.be.revertedWith(
      "TimeLock::executeTransaction: Transaction hasn't surpassed time lock."
    )
  })

  it('should not be possible to execute an expired proposal', async () => {
    await converter.connect(collectionCreator).delegate(collectionCreator.address)

    await addTestProposal(collectionCreator)
    await votingDelay()
    await governorAlpha.connect(collectionCreator).castVote(1, true)
    await votingPeriod()
    await governorAlpha.connect(collectionCreator).queue(1)
    await delay()

    // a proposal that can be executed must be executed within a certain time frame
    await gracePeriod()
    expect(await governorAlpha.state(1)).to.equal(ProposalState.Expired)

    await expect(governorAlpha.connect(collectionCreator).execute(1)).to.be.revertedWith(
      'GovernorAlpha::execute: proposal can only be executed if it is queued'
    )
  })

  it('should not be possible to vote multiple times', async () => {
    await converter.connect(collectionCreator).delegate(collectionCreator.address)

    await addTestProposal(collectionCreator)
    await votingDelay()
    await governorAlpha.connect(collectionCreator).castVote(1, true)

    await expect(governorAlpha.connect(collectionCreator).castVote(1, true)).to.be.revertedWith(
      'GovernorAlpha::_castVote: voter already voted'
    )
  })

  it('should not be possible to vote multiple times by transferring tokens', async () => {
    await converter.connect(collectionCreator).delegate(collectionCreator.address)
    await converter.connect(collectionCreator).transfer(alice.address, 500)
    expect(await converter.getCurrentVotes(collectionCreator.address)).to.equal('500')
    await converter.connect(alice).delegate(alice.address)
    expect(await converter.getCurrentVotes(alice.address)).to.equal('500')

    await addTestProposal(collectionCreator)

    await votingDelay()
    await governorAlpha.connect(collectionCreator).castVote(1, true)
    await governorAlpha.connect(alice).castVote(1, false)

    // transfer tokens to bob and vote again
    await converter.connect(collectionCreator).transfer(bob.address, 500)
    await converter.connect(bob).delegate(bob.address)
    expect(await converter.getCurrentVotes(bob.address)).to.equal('500')
    await governorAlpha.connect(bob).castVote(1, true)
    await votingPeriod()
    // bob still has a voting power of 0 so the proposal was declined
    expect(await governorAlpha.state(1)).to.equal(ProposalState.Defeated)
  })

  it('should be possible to delegate votes', async () => {
    // Alice should have the voting power instead of the collectionCreator
    await converter.connect(collectionCreator).delegate(alice.address)

    await addTestProposal(alice)
    await votingDelay()
    await governorAlpha.connect(alice).castVote(1, true)
    await votingPeriod()
    expect(await governorAlpha.state(1)).to.equal(ProposalState.Succeeded)
  })

  it('should not be possible to vote with the help of already used delegate votes', async () => {
    await converter.connect(collectionCreator).delegate(collectionCreator.address)
    await converter.connect(collectionCreator).transfer(alice.address, 500)
    expect(await converter.getCurrentVotes(collectionCreator.address)).to.equal('500')
    await converter.connect(alice).delegate(alice.address)
    expect(await converter.getCurrentVotes(alice.address)).to.equal('500')

    await addTestProposal(collectionCreator)

    await votingDelay()
    await governorAlpha.connect(collectionCreator).castVote(1, true)
    await governorAlpha.connect(alice).castVote(1, false)

    // delegate voting power to bob and vote again
    await converter.connect(collectionCreator).delegate(bob.address)
    await governorAlpha.connect(bob).castVote(1, true)
    await votingPeriod()
    // bob still has a voting power of 0 so the proposal was declined
    expect(await governorAlpha.state(1)).to.equal(ProposalState.Defeated)
  })

  it('should be possible for the guardian to cancel a proposal', async () => {
    await converter.connect(collectionCreator).delegate(collectionCreator.address)
    await converter.connect(collectionCreator).transfer(alice.address, 500)
    expect(await converter.getCurrentVotes(collectionCreator.address)).to.equal('500')
    await converter.connect(alice).delegate(alice.address)
    expect(await converter.getCurrentVotes(alice.address)).to.equal('500')

    await addTestProposal(alice)

    // The creator (guardian) can always cancel a proposal
    await governorAlpha.connect(collectionCreator).cancel(1)
    expect(await governorAlpha.state(1)).to.equal(ProposalState.Canceled)
  })

  it('should be possible to cancel a proposal if the proposal threshold has changed and the proposer is below it', async () => {
    await converter.connect(collectionCreator).delegate(collectionCreator.address)
    await converter.connect(collectionCreator).transfer(alice.address, 500)
    expect(await converter.getCurrentVotes(collectionCreator.address)).to.equal('500')
    await converter.connect(alice).delegate(alice.address)
    expect(await converter.getCurrentVotes(alice.address)).to.equal('500')

    await addTestProposal(alice)

    // Since Alice's voice power is above the threshold, Bob should not be able to cancel it
    await expect(governorAlpha.connect(bob).cancel(1)).to.be.revertedWith(
      'GovernorAlpha::cancel: proposer above threshold'
    )

    // change the threshold so that alice no longer has enough voting power to add a proposal
    await config.setProposalThresholdDivider(2)
    await governorAlpha.connect(bob).cancel(1)

    expect(await governorAlpha.state(1)).to.equal(ProposalState.Canceled)
  })

  it('should not be possible to execute a canceled proposal', async () => {
    await converter.connect(collectionCreator).delegate(collectionCreator.address)

    await addTestProposal(collectionCreator)
    await votingDelay()
    await governorAlpha.connect(collectionCreator).castVote(1, true)
    await votingPeriod()
    await governorAlpha.connect(collectionCreator).queue(1)
    await delay()

    // cancel
    await governorAlpha.connect(collectionCreator).cancel(1)

    // Try to executed the canceled proposal
    await expect(governorAlpha.connect(collectionCreator).execute(1)).to.be.revertedWith(
      'GovernorAlpha::execute: proposal can only be executed if it is queued'
    )
  })

  it('should not be possible to make a proposal without exceeding the proposal threshold', async () => {
    await converter.connect(collectionCreator).delegate(collectionCreator.address)
    await converter.connect(collectionCreator).transfer(alice.address, 4)
    expect(await converter.getCurrentVotes(collectionCreator.address)).to.equal('996')
    await converter.connect(alice).delegate(alice.address)
    expect(await converter.getCurrentVotes(alice.address)).to.equal('4')

    // Alice should not be able to add a proposal because her voting power is too low
    await expect(addTestProposal(alice)).to.be.revertedWith(
      'GovernorAlpha::propose: proposer votes below proposal threshold'
    )
  })

  it('should be possible to handle multiple proposals at once', async () => {
    await converter.connect(collectionCreator).delegate(collectionCreator.address)
    await converter.connect(collectionCreator).transfer(alice.address, 300)
    await converter.connect(alice).delegate(alice.address)
    expect(await converter.getCurrentVotes(alice.address)).to.equal('300')
    await converter.connect(collectionCreator).transfer(bob.address, 300)
    await converter.connect(bob).delegate(bob.address)
    expect(await converter.getCurrentVotes(bob.address)).to.equal('300')

    // phase: add proposals
    await addTestProposal(collectionCreator)
    await addTestProposal(alice)
    // it is not possible to queue the same action twice
    await governorAlpha
      .connect(bob)
      .propose([thirdParty.address], [0], ['pay()'], [utils.defaultAbiCoder.encode([], [])], 'transfer 0 eth')

    // phase: vote
    await votingDelay()
    await governorAlpha.connect(collectionCreator).castVote(1, true)
    await governorAlpha.connect(alice).castVote(1, false)
    await governorAlpha.connect(bob).castVote(1, false)

    await governorAlpha.connect(collectionCreator).castVote(2, true)
    await governorAlpha.connect(alice).castVote(2, true)

    await governorAlpha.connect(collectionCreator).castVote(3, true)
    await governorAlpha.connect(alice).castVote(3, true)
    await votingPeriod()

    // phase: queue
    expect(await governorAlpha.state(1)).to.equal(ProposalState.Defeated)
    expect(await governorAlpha.state(2)).to.equal(ProposalState.Succeeded)
    expect(await governorAlpha.state(3)).to.equal(ProposalState.Succeeded)

    await expect(governorAlpha.connect(collectionCreator).queue(1)).to.be.revertedWith(
      'GovernorAlpha::queue: proposal can only be queued if it is succeeded'
    )
    await governorAlpha.connect(collectionCreator).queue(2)
    await governorAlpha.connect(collectionCreator).queue(3)
    await delay()

    // phase: execute
    const receipt2 = await governorAlpha.connect(collectionCreator).execute(2)
    const result2 = await receipt2.wait()
    expect(result2.events[0].data).to.equal('0x0000000000000000000000000000000000000000000000000000000000000001')

    const receipt3 = await governorAlpha.connect(collectionCreator).execute(3)
    const result3 = await receipt3.wait()
    expect(result3.events[0].data).to.equal('0x0000000000000000000000000000000000000000000000000000000000000000')
  })

  it('should not be possible to call the factory with a proxy transaction', async () => {
    await converter.connect(collectionCreator).delegate(collectionCreator.address)

    await governorAlpha
      .connect(collectionCreator)
      .propose(
        [factory.address],
        [0],
        ['foo()'],
        [utils.defaultAbiCoder.encode([], [])],
        'call foo on the factory'
      )
    await votingDelay()
    await governorAlpha.connect(collectionCreator).castVote(1, true)
    await votingPeriod()
    await governorAlpha.connect(collectionCreator).queue(1)
    await delay()

    await expect(governorAlpha.connect(collectionCreator).execute(1))
      .to.be.revertedWith('Converter: No proxy transactions calling factory allowed')
  })

  it('should not be possible to call the unic contract with a proxy transaction', async () => {
    await converter.connect(collectionCreator).delegate(collectionCreator.address)

    await governorAlpha
      .connect(collectionCreator)
      .propose(
        [unic.address],
        [0],
        ['foo()'],
        [utils.defaultAbiCoder.encode([], [])],
        'call foo on the unic contract'
      )
    await votingDelay()
    await governorAlpha.connect(collectionCreator).castVote(1, true)
    await votingPeriod()
    await governorAlpha.connect(collectionCreator).queue(1)
    await delay()

    await expect(governorAlpha.connect(collectionCreator).execute(1))
      .to.be.revertedWith('Converter: No proxy transactions calling unic allowed')
  })
})