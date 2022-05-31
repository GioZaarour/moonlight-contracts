pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./interfaces/IMoonFactory.sol";
import "./Converter.sol";

contract ProxyCreator is Ownable {
    using SafeMath for uint256;

    bool public isPublic;
    bool public anyAllowed;
    mapping(address => bool) public whitelist;
    mapping(address => mapping(uint256 => bool)) public allowedNFTs;
    mapping(address => bool) public contractWhitelist;
    address public factory;
    address public proxyTransactionFactory;
    address public moonToken;
    address public governorAlpha;
    uint256 public reward;

    constructor(address _factory, address _moonToken) public {
        factory = _factory;
        moonToken = _moonToken;
    }

    function setReward(uint256 _reward) public onlyOwner {
        reward = _reward;
    }

    function setConstraints(address _contract, bool _contractWhitelist, uint256[] calldata _ids, bool _isAllowed, bool _anyAllowed) public onlyOwner {
        if(_anyAllowed) {
            anyAllowed = _anyAllowed;
            return;
        }

        if(_contractWhitelist) {
            contractWhitelist[_contract] = true;
            return;
        }

        require(_ids.length < 200, "ProxyCreator: Allow at most 200 ids at a time");

        for (uint8 i=0; i<200; i++) {
            if (i == _ids.length) {
                break;
            }

            allowedNFTs[_contract][_ids[i]] = _isAllowed;
        }
    }

    function setWhiteList(address[] memory _addresses, bool _isWhitelisted, bool _isPublic) public onlyOwner {
        if(_isPublic) {
            isPublic = _isPublic;
            return;
        }

        require(_addresses.length < 200, "ProxyCreator: Set at most 200 addresses at a time");

        for (uint8 i=0; i<200; i++) {
            if (i == _addresses.length) {
                break;
            }

            whitelist[_addresses[i]] = _isWhitelisted;
        }
    }

    function deposit(uint256[] calldata tokenIDs, uint256[] calldata amounts, uint256[] calldata triggerPrices, address contractAddr) public {
        for (uint8 i=0; i<200; i++) {
            if (i == tokenIDs.length) {
                break;
            }
            require(allowedNFTs[contractAddr][tokenIDs[i]] || anyAllowed || contractWhitelist[contractAddr], "ProxyCreator: Attempted deposit of non-whitelisted NFT");

            IERC721(contractAddr).transferFrom(msg.sender, address(this), tokenIDs[i]);
        }

        IERC721(contractAddr).setApprovalForAll(moonToken, true);
        if(isPublic) {
            Converter(moonToken).deposit(tokenIDs, amounts, triggerPrices, contractAddr);
        }
        else {
            require(whitelist[msg.sender], "ProxyCreator: User not part of whitelist");
            Converter(moonToken).deposit(tokenIDs, amounts, triggerPrices, contractAddr);
        }
        
        if(reward != 0) {
            Converter(moonToken).transfer(msg.sender, reward.mul(tokenIDs.length));
        }
    }
}
