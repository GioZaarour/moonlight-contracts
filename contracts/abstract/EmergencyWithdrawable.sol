pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract EmergencyWithdrawable is Ownable {
    // for worst case scenarios or to recover funds from people sending to this contract by mistake
    function emergencyWithdrawETH() external payable onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    // for worst case scenarios or to recover funds from people sending to this contract by mistake
    function emergencyWithdrawTokens(IERC20 token) external onlyOwner {
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }
}