pragma solidity ^0.8.4;

interface IUnicSwapV2Callee {
    function unicSwapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
}
