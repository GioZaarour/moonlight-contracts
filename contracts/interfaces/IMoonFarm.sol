// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUnicFarm {
    //struct PoolInfo {
        //IERC20 lpToken; // Address of LP token contract.
        //uint256 allocPoint; // How many allocation points assigned to this pool. UNICs to distribute per block.
        //uint256 lastRewardBlock; // Last block number that UNICs distribution occurs.
        //uint256 accUnicPerShare; // Accumulated UNICs per share, times 1e12. See below.
        //address uToken;
    //}

    function pendingUnic(uint256 _pid, address _user) external view returns (uint256);

    function deposit(uint256 _pid, uint256 _amount) external;

    function poolInfo(uint256 _pid) external view returns (IERC20, uint256, uint256, uint256, address);

    function poolLength() external view returns (uint256);

    function withdraw(uint256 _pid, uint256 _amount) external;
}
