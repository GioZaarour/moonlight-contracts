pragma solidity >=0.5.0;

interface IMoonConverterGovernorAlphaFactory {
    function createGovernorAlpha(
        address moonToken,
        address guardian,
        address converterTimeLock,
        address config
    ) external returns (address);
}