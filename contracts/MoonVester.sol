pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./MoonSwap/interfaces/IMoonSwapV2Factory.sol";
import "./MoonSwap/interfaces/IMoonSwapV2Pair.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/Math.sol";

contract MoonVester is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IMoonSwapV2Factory public factory; 
    address public bar;
    address public moon;
    address public weth;

    uint256 public vestingDuration;

    mapping(address => Schedule) public vestings;
    mapping(address => bool) public initialized;

    struct Schedule {
        uint256 amount;
        uint256 start;
        uint256 end;
    }

    constructor(IMoonSwapV2Factory _factory, address _bar, address _moon, address _weth) public {
        factory = _factory;
        moon = _moon;
        bar = _bar;
        weth = _weth;
    }

    // Initializes vesting schedule for new moonToken
    function initialize(address token) onlyOwner public {
        require(!initialized[token], "MoonVester: Already initialized token");
        vestings[token] = Schedule(
            {
                amount: IERC20(token).balanceOf(address(this)),
                start: getBlockTimestamp(),
                end: getBlockTimestamp().add(vestingDuration)
            }
        );
    }

    // Set protocol's vesting schedule for future moonTokens
    function setSchedule(uint256 _vestingDuration) onlyOwner public {
        vestingDuration = _vestingDuration;
    }
    
    function swap(address token) onlyOwner public {
        require(msg.sender == tx.origin, "do not convert from contract");

        Schedule storage vestingInfo = vestings[token];
        require(vestingInfo.start < vestingInfo.end, "MoonVester: Fully vested and swapped");
        uint256 currentTime = getBlockTimestamp();
        uint256 timeVested = Math.min(currentTime.sub(vestingInfo.start), vestingInfo.end.sub(vestingInfo.start));
        uint256 amountVested = Math.min(vestingInfo.amount.mul(timeVested).div(vestingInfo.end.sub(vestingInfo.start)), IERC20(token).balanceOf(address(this)));
        vestingInfo.start = currentTime;
        if(vestingInfo.amount < amountVested) {
            vestingInfo.amount = 0;
        }
        else {
            vestingInfo.amount = vestingInfo.amount.sub(amountVested);
        }
        uint256 wethAmount = _toWETH(token, amountVested);
        _toMOON(wethAmount);
    }

    // Converts token passed as an argument to WETH
    function _toWETH(address token, uint amountIn) internal returns (uint256) {
        // If the passed token is Moon, don't convert anything
        if (token == moon) {
            _safeTransfer(token, bar, amountIn);
            return 0;
        }
        // If the passed token is WETH, don't convert anything
        if (token == weth) {
            _safeTransfer(token, factory.getPair(weth, moon), amountIn);
            return amountIn;
        }
        // If the target pair doesn't exist, don't convert anything
        IMoonSwapV2Pair pair = IMoonSwapV2Pair(factory.getPair(token, weth));
        if (address(pair) == address(0)) {
            return 0;
        }
        // Choose the correct reserve to swap from
        (uint reserve0, uint reserve1,) = pair.getReserves();
        address token0 = pair.token0();
        (uint reserveIn, uint reserveOut) = token0 == token ? (reserve0, reserve1) : (reserve1, reserve0);
        // Calculate information required to swap
        uint amountInWithFee = amountIn.mul(997);
        uint amountOut = amountInWithFee.mul(reserveOut) / reserveIn.mul(1000).add(amountInWithFee);
        (uint amount0Out, uint amount1Out) = token0 == token ? (uint(0), amountOut) : (amountOut, uint(0));
        _safeTransfer(token, address(pair), amountIn);
        pair.swap(amount0Out, amount1Out, factory.getPair(weth, moon), new bytes(0));
        return amountOut;
    }

    // Converts WETH to moon
    function _toMOON(uint256 amountIn) internal {
        IMoonSwapV2Pair pair = IMoonSwapV2Pair(factory.getPair(weth, moon));
        // Choose WETH as input token
        (uint reserve0, uint reserve1,) = pair.getReserves();
        address token0 = pair.token0();
        (uint reserveIn, uint reserveOut) = token0 == weth ? (reserve0, reserve1) : (reserve1, reserve0);
        // Calculate information required to swap
        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        uint amountOut = numerator / denominator;
        (uint amount0Out, uint amount1Out) = token0 == weth ? (uint(0), amountOut) : (amountOut, uint(0));
        // Swap WETH for moon
        pair.swap(amount0Out, amount1Out, bar, new bytes(0));
    }

    // Wrapper for safeTransfer
    function _safeTransfer(address token, address to, uint256 amount) internal {
        IERC20(token).safeTransfer(to, amount);
    }

    function getBlockTimestamp() internal view returns (uint) {
        // solium-disable-next-line security/no-block-members
        return block.timestamp;
    }
}