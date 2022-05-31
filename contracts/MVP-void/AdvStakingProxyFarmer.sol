pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./UnicFarm.sol";
import "./UnicStaking.sol";

contract AdvStakingProxyFarmer {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public unic;
    IERC20 public token;
    address public farm;
    address public staking;
    uint256 public pid;
    bool public initialized = false;
    uint256 private constant MAX_INT = 2**256 - 1;

    function initialize() external {
        require(!initialized, "AdvStakingProxyFarmer: Already initialized");
        token.approve(farm, 1);
        unic.approve(staking, MAX_INT);
        UnicFarm(farm).deposit(pid, 1);
        initialized = true;
    }

    function addRewards() public {
        require(initialized, "AdvStakingProxyFarmer: Not initialized");
        UnicFarm(farm).deposit(pid, 0);
        UnicStaking(staking).addRewards(address(unic), unic.balanceOf(address(this)));
    }

    constructor(
        IERC20 _unic,
        IERC20 _token,
        address _farm,
        address _staking,
        uint256 _pid
    ) public {
        unic = _unic;
        token = _token;
        farm = _farm;
        staking = _staking;
        pid = _pid;
    }
}