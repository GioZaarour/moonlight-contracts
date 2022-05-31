pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
/*
contract SimpleAuction is Ownable {
    using SafeMath for uint;

    struct AuctionInfo {
        address creator;
        uint256 goal;
        uint256 startTime;
        uint256 endTime;
    }

    address[] public tokens;

    mapping(address => uint256) public auctionIDs;
    mapping(address => bool) public isActive;
    mapping(address => AuctionInfo) public auctions;

    function tokensLength() external view returns (uint) {
        return tokens.length;
    }

    function intializeAuction(address _token, address _creator, uint256 _goal, uint256 _startTime, uint256 _endTime) public onlyOwner {
        auctionIDs[_token] = tokens.length;
        isActive[_token] = true;
        auctions[_token] = new AuctionInfo(_creator, _goal, _startTime, _endTime);
        tokens.push(_token);
    }

    function modifyAuction(bool _pause, address _token, address _creator, uint256 _goal, uint256 _startTime, uint256 _endTime) public onlyOwner {
        isActive[_token] = !_pause;
        AuctionInfo storage info = auctions[_token];
        info = new AuctionInfo(_creator, _goal, _startTime, _endTime);
    }
}
*/