pragma solidity 0.6.12;

import "./ConverterTimeLock.sol";
import './interfaces/IMoonConverterGovernorAlphaFactory.sol';
import './interfaces/IMoonConverterProxyTransactionFactory.sol';

contract MoonConverterProxyTransactionFactory is IMoonConverterProxyTransactionFactory {

    // ConverterGovernorAlphaConfig
    address public config;

    IMoonConverterGovernorAlphaFactory public governorAlphaFactory;

    constructor (address _config, address _governorAlphaFactory) public {
        require(_config != address(0) && _governorAlphaFactory != address(0), "Invalid address");
        config = _config;
        governorAlphaFactory = IMoonConverterGovernorAlphaFactory(_governorAlphaFactory);
    }

    /**
     * Creates the contracts for the proxy transaction functionality for a given moonToken
     */
    function createProxyTransaction(address moonToken, address guardian) external override returns (address, address) {
        ConverterTimeLock converterTimeLock = new ConverterTimeLock(address(this), moonToken, config);
        address converterGovernorAlpha = governorAlphaFactory.createGovernorAlpha(moonToken, guardian, address(converterTimeLock), config);
        // Initialize timelock admin
        converterTimeLock.setAdmin(address(converterGovernorAlpha));

        emit MoonGovernorAlphaCreated(converterGovernorAlpha, address(converterTimeLock));
        
        return (converterGovernorAlpha, address(converterTimeLock));
    }
}