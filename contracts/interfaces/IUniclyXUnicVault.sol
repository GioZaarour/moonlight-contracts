// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IUniclyXUnicVault {
    function depositFor(uint256 _pid, uint256 _amount, address _user) external;
}
