# Proxy transactions

### Deployment order
1. UnicConverterGovernorAlphaFactory
2. UnicConverterProxyTransactionFactory
3. UnicGovernorAlphaFactory

### How it works

Tokenholders can delegate voting power to themselves or other users.
```
ERC20Votes:delegate(address delegatee)
```

Addresses that have more voting power than the threshold (ConverterGovernorAlpha:proposalThreshold()) can submit 
proposals for transactions. The proposal can consist of several single transactions. For each transaction a target 
address, the amount of ETH to be sent, the method signature as well as the calldata must be passed. For the whole 
proposal there is a description.
```
ConverterGovernorAlpha:propose(address[] memory targets, uint[] memory values, string[] memory signatures, bytes[] memory calldatas, string memory description)
```

Subsequently, a vote can be cast for the transaction. 
```
ConverterGovernorAlpha:castVote(uint proposalId, bool support)
```

When the voting phase is over (ConverterGovernorAlphaConfig:votingPeriod) and the positive votes exceed the threshold 
(ConverterGovernorAlpha:quorumVotes()) the proposal can be enqueued in the ConverterTimeLock contract.
```
ConverterGovernorAlpha:queue(uint proposalId)
```

In this phase the proposal can still be canceled. This can be done either by the creator of the collection or by anyone 
if the proposer's voting power fall below the threshold required to create a proposal 
(ConverterGovernorAlpha:proposalThreshold()).
```
ConverterGovernorAlpha:cancel(uint proposalId)
```

When the waiting time is over (ConverterGovernorAlphaConfig:delay) the proposal can be executed. The amount of ETH 
defined in the values must be sent with the proposal.
```
ConverterGovernorAlpha:execute(uint proposalId) payable
```

Configurations for thresholds, delay and more can be set for all collections via the Config 
(ConverterGovernorAlphaConfig) by the owner (us).

### Examples

Propose:
```
contract.propose(
        [address1, address2],
        [0, 10],
        ['verifyOwnership(address,uint256)', 'pay()'],
        [utils.defaultAbiCoder.encode(['address', 'uint256'], [nft.address, 0]), utils.defaultAbiCoder.encode([], [])],
        'verify the ownership of 0 and transfer 10*10^-18 eth'
      )
```