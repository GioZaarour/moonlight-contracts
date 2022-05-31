pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ProxyToken is ERC20("Beeple Proxy LP Token", "uBEEPLE-LP") {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public lpToken;

    function swapIn(uint256 _amount) public {
        IERC20(lpToken).transferFrom(msg.sender, address(this), _amount);
        _mint(msg.sender, _amount);
    }

    function swapOut(uint256 _amount) public {
        _burn(msg.sender, _amount);
        IERC20(lpToken).transfer(msg.sender, _amount);
    }

    constructor(
        address _lpToken
    ) public {
        lpToken = _lpToken;
    }
}