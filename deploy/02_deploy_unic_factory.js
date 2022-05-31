module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, execute } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('UnicFactory', {
    from: deployer,
    log: true,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        methodName: "initialize",
        args: [deployer, 100, hre.ethers.utils.parseEther('1000000')],
      }
    },
  });

  const converter = await deployments.get('Converter');
  await execute('UnicFactory', { from: deployer, log: true }, 'setConverterImplementation', converter.implementation);
};
module.exports.tags = ['UnicFactory'];
module.exports.dependencies = ['Converter'];
