pragma solidity 0.6.12;

import "./VaultTimeLock.sol";
import './interfaces/IMoonVaultGovernorAlphaFactory.sol';
import './interfaces/IMoonVaultProxyTransactionFactory.sol';

contract MoonVaultProxyTransactionFactory is IMoonVaultProxyTransactionFactory {

    // VaultGovernorAlphaConfig
    address public config;

    IMoonVaultGovernorAlphaFactory public governorAlphaFactory;

    constructor (address _config, address _governorAlphaFactory) public {
        require(_config != address(0) && _governorAlphaFactory != address(0), "Invalid address");
        config = _config;
        governorAlphaFactory = IMoonVaultGovernorAlphaFactory(_governorAlphaFactory);
    }

    /**
     * Creates the contracts for the proxy transaction functionality for a given moonToken
     */
    function createProxyTransaction(address moonToken, address guardian) external override returns (address, address) {
        VaultTimeLock vaultTimeLock = new VaultTimeLock(address(this), moonToken, config);
        address vaultGovernorAlpha = governorAlphaFactory.createGovernorAlpha(moonToken, guardian, address(vaultTimeLock), config);
        // Initialize timelock admin
        vaultTimeLock.setAdmin(address(vaultGovernorAlpha));

        emit MoonGovernorAlphaCreated(vaultGovernorAlpha, address(vaultTimeLock));
        
        return (vaultGovernorAlpha, address(vaultTimeLock));
    }
}