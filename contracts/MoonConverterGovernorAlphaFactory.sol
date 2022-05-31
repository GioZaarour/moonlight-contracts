pragma solidity 0.6.12;

import {ConverterGovernorAlpha} from "./ConverterGovernorAlpha.sol";
import './interfaces/IMoonConverterGovernorAlphaFactory.sol';

contract MoonConverterGovernorAlphaFactory is IMoonConverterGovernorAlphaFactory {

    /**
     * Creates the ConverterGovernorAlpha contract for the proxy transaction functionality for a given moonToken
     */
    function createGovernorAlpha(
        address moonToken, 
        address guardian,
        address converterTimeLock,
        address config
    ) external override returns (address) {
        return address(new ConverterGovernorAlpha(converterTimeLock, moonToken, guardian, config));
    }
}