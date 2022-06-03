pragma solidity >=0.5.0;

interface IMoonVaultGovernorAlphaFactory {
    function createGovernorAlpha(
        address moonToken,
        address guardian,
        address vaultTimeLock,
        address config
    ) external returns (address);
}