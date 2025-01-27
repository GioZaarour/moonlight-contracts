// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMoonFarm {
    function pendingMoon(uint256 _pid, address _user) external view returns (uint256);

    function deposit(uint256 _pid, uint256 _amount) external;

    function poolInfo(uint256 _pid) external view returns (IERC20, uint256, uint256, uint256, address);

    function poolLength() external view returns (uint256);

    function withdraw(uint256 _pid, uint256 _amount) external;
}