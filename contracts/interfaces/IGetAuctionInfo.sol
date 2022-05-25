pragma solidity ^0.8.4;

interface IGetAuctionInfo {
    function onAuction(address uToken, uint nftIndexForUToken) external view returns (bool);
}