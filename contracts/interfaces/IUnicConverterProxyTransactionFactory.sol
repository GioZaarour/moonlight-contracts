pragma solidity >=0.5.0;

interface IUnicConverterProxyTransactionFactory {
    event UnicGovernorAlphaCreated(address indexed governorAlpha, address indexed timelock);

    function createProxyTransaction(address uToken, address guardian) external returns (address, address);
}