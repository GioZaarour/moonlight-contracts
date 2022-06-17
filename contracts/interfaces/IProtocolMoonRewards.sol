pragma solidity 0.6.12;

interface IProtocolMoonRewards {
    function reward(address userAddress, uint256 amount) external;
    function harvest() external;
}
