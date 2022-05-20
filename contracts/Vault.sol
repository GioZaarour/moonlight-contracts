// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";

//have this file store an NFT instead of ETH
//we don't want to have a payee either, but a function to release said NFT/NFTs upon call by the timelock 
//so timelock should be the owner of this contract

contract Vault is Ownable {
    uint256 public totalFunds;
    address public payee;
    bool public isReleased;

    constructor(address _payee) payable {
        totalFunds = msg.value;
        payee = _payee;
        isReleased = false;
    }

    function releaseFunds() public onlyOwner {
        isReleased = true;
        payable(payee).transfer(totalFunds);
    }
}