# moonlight

Moonlight is a fractional NFT crowdfunding and co-ownership protocol. Includes a fork of [Uniswap V2](https://github.com/Uniswap/v2-core) and [Unic.ly](https://github.com/uniclyNFT/unicly-core)

Read more about the protocol in the [whitepaper](https://moonlightxyz.notion.site/Moonlight-V1-Crowdfunding-Collective-NFT-Ownership-facce76272ea4a6fb6a1409d76b81017) 

[Twitter](https://twitter.com/moonlightmeta) | [Website](https://www.moonlight.xyz/)

### Build instructions
`yarn`

`yarn compile`

### Testing
`yarn test`

### Truffle Migration

#### Local
Use the following commands to spawn a local blockchain and deploy moonlight contracts:

`yarn`

`truffle develop`

`migrate --reset`

#### Rinkeby
Use the following commands to deploy moonlight contracts onto Rinkeby:

`yarn`

`nano truffle-config.js`

Add the mnemonic for the admin account and the API endpoint for the Rinkeby node.

`truffle compile`

`truffle migrate --network rinkeby`
