pragma solidity ^0.8.4;

//import "@openzeppelin/contracts/utils/math/SafeMath.sol";
//import "./interfaces/IProxyTransaction.sol";
//import "@openzeppelin/contracts/access/Ownable.sol";
//import "./ConverterGovernorAlphaConfig.sol";
import "./ConverterTimeLock.sol";
//import "./interfaces/IUnicConverterGovernorAlphaFactory.sol";
import "./interfaces/IUnicConverterProxyTransactionFactory.sol";

contract UnicConverterProxyTransactionFactory is IUnicConverterProxyTransactionFactory {

    // ConverterGovernorAlphaConfig
    address public config;

    IUnicConverterGovernorAlphaFactory public governorAlphaFactory;

    constructor (address _config, address _governorAlphaFactory) public {
        require(_config != address(0) && _governorAlphaFactory != address(0), "Invalid address");
        config = _config;
        governorAlphaFactory = IUnicConverterGovernorAlphaFactory(_governorAlphaFactory);
    }

    /**
     * Creates the contracts for the proxy transaction functionality for a given uToken
     */
    function createProxyTransaction(address uToken, address guardian) external override returns (address, address) {
        ConverterTimeLock converterTimeLock = new ConverterTimeLock(address(this), uToken, config);
        address converterGovernorAlpha = governorAlphaFactory.createGovernorAlpha(uToken, guardian, address(converterTimeLock), config);
        // Initialize timelock admin
        converterTimeLock.setAdmin(address(converterGovernorAlpha));

        emit UnicGovernorAlphaCreated(converterGovernorAlpha, address(converterTimeLock));
        
        return (converterGovernorAlpha, address(converterTimeLock));
    }
}