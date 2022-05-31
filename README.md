# moonlight

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
