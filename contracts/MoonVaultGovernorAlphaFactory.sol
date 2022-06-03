pragma solidity 0.6.12;

import {VaultGovernorAlpha} from "./VaultGovernorAlpha.sol";
import './interfaces/IMoonVaultGovernorAlphaFactory.sol';

contract MoonVaultGovernorAlphaFactory is IMoonVaultGovernorAlphaFactory {

    /**
     * Creates the VaultGovernorAlpha contract for the proxy transaction functionality for a given moonToken
     */
    function createGovernorAlpha(
        address moonToken, 
        address guardian,
        address vaultTimeLock,
        address config
    ) external override returns (address) {
        return address(new VaultGovernorAlpha(vaultTimeLock, moonToken, guardian, config));
    }
}