pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./UnicFarm.sol";

contract ProxyFarmer {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public unic;
    IERC20 public token;
    address public farm;
    address public xunic;
    uint256 public pid;
    bool public initialized = false;

    function initialize() external {
        require(!initialized, "ProxyFarmer: Already initialized");
        token.approve(farm, 1);
        UnicFarm(farm).deposit(pid, 1);
        initialized = true;
    }

    function rewardXUNIC() public {
        require(initialized, "ProxyFarmer: Not initialized");
        UnicFarm(farm).deposit(pid, 0);
        unic.transfer(xunic, unic.balanceOf(address(this)));
    }

    constructor(
        IERC20 _unic,
        IERC20 _token,
        address _farm,
        address _xunic,
        uint256 _pid
    ) public {
        unic = _unic;
        token = _token;
        farm = _farm;
        xunic = _xunic;
        pid = _pid;
    }
}