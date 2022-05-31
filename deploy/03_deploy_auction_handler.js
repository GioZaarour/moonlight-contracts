module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, execute } = deployments;
  const { deployer } = await getNamedAccounts();

  const unicFactory = await deployments.get('UnicFactory');

  await deploy('AuctionHandler', {
    from: deployer,
    log: true,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        methodName: "initialize",
        args: [unicFactory.address, 86400, 105, 300, 100, deployer, deployer],
      }
    },
  });
};
module.exports.tags = ['AuctionHandler'];
module.exports.dependencies = ['UnicFactory'];
