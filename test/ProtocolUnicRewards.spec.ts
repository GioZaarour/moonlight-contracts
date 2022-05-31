// import chai, { expect } from 'chai'
// import { createFixtureLoader, deployContract, MockProvider } from 'ethereum-waffle'
// import { Contract } from 'ethers'
// import ProtocolUnicRewards from '../build/ProtocolUnicRewards.json'
// import UnicSwapRouterIncentivized from '../build/UnicSwapRouterIncentivized.json'
// import MockRouter from '../build/MockRouter.json'
// import { governanceFixture } from './fixtures'

// const overrides = {
//   gasLimit: 9999999
// }

// describe.only('ProtocolUnicRewards', () => {
//   const provider = new MockProvider({
//     ganacheOptions: {
//       hardfork: 'istanbul',
//       mnemonic: 'horn horn horn horn horn horn horn horn horn horn horn horn',
//       gasLimit: 99999999,
//     },
//   })
//   const [alice, bob, carol, random] = provider.getWallets()
//   const loadFixture = createFixtureLoader([alice], provider)

//   let unic: Contract
//   let protocolUnicRewards: Contract
//   let mockRouter: Contract
//   let incentivizedRouter: Contract

//   beforeEach(async () => {
//     const fixture = await loadFixture(governanceFixture)
//     unic = fixture.unic

//     protocolUnicRewards = await deployContract(alice, ProtocolUnicRewards, [], overrides)
//     await protocolUnicRewards.initialize(unic.address)

//     mockRouter = await deployContract(alice, MockRouter, [random.address, random.address], overrides);

//     incentivizedRouter = await deployContract(alice, UnicSwapRouterIncentivized, [], overrides);

//     // 0.01 UNIC per ETH, just an example
//     await incentivizedRouter.initialize(mockRouter.address, protocolUnicRewards.address, '10000000000000000', 0);
//   });

//   it('should handle pausing properly', async () => {
//     expect(await protocolUnicRewards.paused()).to.eq(false);
//     await protocolUnicRewards.pause();
//     expect(await protocolUnicRewards.paused()).to.eq(true);
//     await protocolUnicRewards.unpause();
//     expect(await protocolUnicRewards.paused()).to.eq(false);
//     await expect(protocolUnicRewards.connect(bob).pause()).to.revertedWith('Ownable: caller is not the owner');
//     await expect(protocolUnicRewards.connect(bob).unpause()).to.revertedWith('Ownable: caller is not the owner');
//   });

//   it('should not allow double initialization', async () => {
//     await expect(protocolUnicRewards.initialize(unic.address)).to.revertedWith('Initializable: contract is already initialized');
//   });

//   it('should error on zero rewards', async () => {
//     await expect(protocolUnicRewards.connect(bob).harvest()).to.revertedWith('ProtocolUnicRewards: No rewards available');
//   });

//   it('should error if contract has no funds', async () => {
//     await protocolUnicRewards.reward(bob.address, 100);
//     await expect(protocolUnicRewards.connect(bob).harvest()).to.revertedWith('ProtocolUnicRewards: Not enough balance to harvest');
//   });

//   it('should allow the happy path', async () => {
//     expect((await unic.balanceOf(bob.address)).toString()).to.equal('0');
//     expect((await unic.balanceOf(carol.address)).toString()).to.equal('0');

//     await protocolUnicRewards.reward(bob.address, 100);
//     await protocolUnicRewards.reward(carol.address, 300);

//     expect((await protocolUnicRewards.connect(bob).pendingReward()).toString()).to.eq('100')
//     expect((await protocolUnicRewards.connect(carol).pendingReward()).toString()).to.eq('300')

//     await unic.transfer(protocolUnicRewards.address, 500);
//     expect((await unic.balanceOf(protocolUnicRewards.address)).toString()).to.equal('500');

//     await protocolUnicRewards.connect(bob).harvest();
//     await protocolUnicRewards.connect(carol).harvest();

//     expect((await unic.balanceOf(protocolUnicRewards.address)).toString()).to.equal('100');
//     expect((await unic.balanceOf(bob.address)).toString()).to.equal('100');
//     expect((await unic.balanceOf(carol.address)).toString()).to.equal('300');

//     expect((await protocolUnicRewards.connect(bob).pendingReward()).toString()).to.eq('0')
//     expect((await protocolUnicRewards.connect(carol).pendingReward()).toString()).to.eq('0')
//     await expect(protocolUnicRewards.connect(bob).harvest()).to.revertedWith('ProtocolUnicRewards: No rewards available');

//     await protocolUnicRewards.reward(bob.address, 50);
//     expect((await protocolUnicRewards.connect(bob).pendingReward()).toString()).to.eq('50')
//     await protocolUnicRewards.connect(bob).harvest();
//     expect((await unic.balanceOf(bob.address)).toString()).to.equal('150');
//   });

//   it('should add rewards on swap', async () => {
//     expect((await protocolUnicRewards.connect(bob).pendingReward()).toString()).to.eq('0')
//     await incentivizedRouter.connect(bob).swapExactETHForTokens(0, [], bob.address, 0, { value: '10000000000000000000' }); // swap 1 ETH
//     expect((await protocolUnicRewards.connect(bob).pendingReward()).toString()).to.eq('100000000000000000') // 0.1 UNIC
//   });
// });
