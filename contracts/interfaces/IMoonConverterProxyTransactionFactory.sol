pragma solidity >=0.5.0;

interface IMoonConverterProxyTransactionFactory {
    event MoonGovernorAlphaCreated(address indexed governorAlpha, address indexed timelock);

    function createProxyTransaction(address moonToken, address guardian) external returns (address, address);
}