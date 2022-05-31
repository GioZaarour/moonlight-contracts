module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  await deploy('Converter', {
    from: deployer,
    log: true,
    proxy: {
      execute: false,
      proxyContract: "OpenZeppelinTransparentProxy",
    },
  });
};
module.exports.tags = ['Converter'];
