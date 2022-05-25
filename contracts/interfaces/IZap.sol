// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IZap {
    function zapInTokenAndDeposit(address _from, uint amount, uint _pid) external;
    function zapInAndDeposit(uint _pid) external payable;
}