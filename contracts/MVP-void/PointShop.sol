pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Converter.sol";
import "./PointFarm.sol";

contract PointShop is ERC1155Receiver, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // List of NFTs that have been deposited
    struct NFT {
    	address contractAddr;
    	uint256 tokenId;
        uint256 amount;
        uint256 price;
    }

    // Track whether uToken has a shop
    mapping(address => bool) public shopExists;
    // Map uToken to internal NFT id to NFT
    mapping(address => mapping(uint256 => NFT)) public nfts;
    // Length of NFTs in each shop
    mapping(address => uint256) public currentNFTIndex;
    // Number of redeemed NFTs in each shop
    mapping(address => uint256) public redeemedNFTs;

    mapping(address => bool) public isPublic;
    mapping(address => bool) public notAnyAllowed;

    // Map uToken to address to boolean
    mapping(address => mapping(address => bool)) public isShopAdmin;
    // Map uToken to contract address to token ID to boolean
    mapping(address => mapping(address => mapping(uint256 => bool))) public allowedNFTs;

    address public farm;

    bytes private constant VALIDATOR = bytes('JCNH');

    event Deposited(address uToken, uint256[] tokenIDs, uint256[] amounts, address contractAddr);

    constructor(
        address _farm
    )
        public
    {
        farm = _farm;
    }

    function setConstraints(address _uToken, address _contract, uint256[] calldata _ids, bool _isAllowed, bool _notAnyAllowed) public {
        // Check if issuer OR shopAdmin
        require(Converter(_uToken).issuer() == msg.sender || isShopAdmin[_uToken][msg.sender], "PointShop: Only shop admin can set constraints");

        if(_notAnyAllowed) {
            notAnyAllowed[_uToken] = _notAnyAllowed;
            return;
        }

        require(_ids.length < 200, "PointShop: Allow at most 200 ids at a time");

        for (uint8 i=0; i<200; i++) {
            if (i == _ids.length) {
                break;
            }

            allowedNFTs[_uToken][_contract][_ids[i]] = _isAllowed;
        }
    }

    function setAdmin(address _uToken, address[] memory _addresses, bool _isAdmin) public {
        require(Converter(_uToken).issuer() == msg.sender, "PointShop: Only issuer can set this permission");

        require(_addresses.length < 200, "ProxyCreator: Set at most 200 addresses at a time");

        for (uint8 i=0; i<200; i++) {
            if (i == _addresses.length) {
                break;
            }

            isShopAdmin[_uToken][_addresses[i]] = _isAdmin;
        }
    }

    function setPublic(address _uToken, bool _isPublic) public {
        // Check if issuer OR shopAdmin
        require(Converter(_uToken).issuer() == msg.sender || isShopAdmin[_uToken][msg.sender], "PointShop: Only shop admin can set this permission");

        isPublic[_uToken] = _isPublic;
    }

    // deposits an nft using the transferFrom action of the NFT contractAddr
    function deposit(address _uToken, uint256[] calldata tokenIDs, uint256[] calldata amounts, uint256[] calldata prices, address contractAddr) external {
        if(notAnyAllowed[_uToken]) {
            for (uint8 i=0; i<200; i++) {
                if (i == tokenIDs.length) {
                    break;
                }

                require(allowedNFTs[_uToken][contractAddr][tokenIDs[i]], "PointShop: Attempted deposit of non-whitelisted NFT");
            }
        }
        // Check if issuer OR shop admin OR isPublic
        require(Converter(_uToken).issuer() == msg.sender ||
        isShopAdmin[_uToken][msg.sender] || isPublic[_uToken], "PointShop: Only shop admin can add to shop");
        require(tokenIDs.length <= 50, "PointShop: A maximum of 50 tokens can be deposited in one go");
        require(tokenIDs.length > 0, "PointShop: You must specify at least one token ID");

        if (ERC165Checker.supportsInterface(contractAddr, 0xd9b67a26)){
            IERC1155(contractAddr).safeBatchTransferFrom(msg.sender, address(this), tokenIDs, amounts, VALIDATOR);

            for (uint8 i = 0; i < 50; i++){
                if (tokenIDs.length == i){
                    break;
                }
                nfts[_uToken][currentNFTIndex[_uToken]++] = NFT(contractAddr, tokenIDs[i], amounts[i], prices[i]);
            }
        }
        else {
            for (uint8 i = 0; i < 50; i++){
                if (tokenIDs.length == i){
                    break;
                }
                IERC721(contractAddr).transferFrom(msg.sender, address(this), tokenIDs[i]);
                nfts[_uToken][currentNFTIndex[_uToken]++] = NFT(contractAddr, tokenIDs[i], 1, prices[i]);
            }
        }

        emit Deposited(_uToken, tokenIDs, amounts, contractAddr);
    }

    // Edit existing NFT structs (prices) in shop
    function modifyShop(address _uToken, uint256[] calldata internalIDs, uint256[] calldata prices) public {
        require(internalIDs.length <= 50, "PointShop: A maximum of 50 NFTs can be modified in one go");
        require(internalIDs.length > 0, "PointShop: You must specify at least one internal ID");
        // Check if issuer OR shop admin
        require(Converter(_uToken).issuer() == msg.sender ||
        isShopAdmin[_uToken][msg.sender], "PointShop: Only shop admin can modify shop");

        for (uint8 i = 0; i < 50; i++){
            if (internalIDs.length == i){
                break;
            }
            NFT storage currentNFT = nfts[_uToken][internalIDs[i]];
            currentNFT.price = prices[i];
        }
    }

    // Function that adds to PointFarm
    function add(address _uToken, bool _withUpdate) public {
        require(Converter(_uToken).issuer() == msg.sender ||
        isShopAdmin[_uToken][msg.sender] || isPublic[_uToken], "PointShop: Only shop admin can add shop to farm");
        require(!shopExists[_uToken], "PointShop: Already added");
        PointFarm(farm).add(IERC20(_uToken), _withUpdate);
        shopExists[_uToken] = true;
    }

    // Function that redeems points for NFTs
    function redeem(address _uToken, uint256 internalID) public {
        PointFarm(farm).burn(msg.sender, PointFarm(farm).shopIDs(_uToken), nfts[_uToken][internalID].price);
        NFT storage currentNFT = nfts[_uToken][internalID];
        currentNFT.amount = 0;
        if (ERC165Checker.supportsInterface(nfts[_uToken][internalID].contractAddr, 0xd9b67a26)){
            IERC1155(nfts[_uToken][internalID].contractAddr).safeTransferFrom(address(this), msg.sender, nfts[_uToken][internalID].tokenId, nfts[_uToken][internalID].amount, VALIDATOR);
        }
        else {
            IERC721(nfts[_uToken][internalID].contractAddr).transferFrom(address(this), msg.sender, nfts[_uToken][internalID].tokenId);
        }
    }

    /**
     * ERC1155 Token ERC1155Receiver
     */
    function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _value, bytes calldata _data) override external returns(bytes4) {
        if(keccak256(_data) == keccak256(VALIDATOR)){
            return 0xf23a6e61;
        }
    }

    function onERC1155BatchReceived(address _operator, address _from, uint256[] calldata _ids, uint256[] calldata _values, bytes calldata _data) override external returns(bytes4) {
        if(keccak256(_data) == keccak256(VALIDATOR)){
            return 0xbc197c81;
        }
    }
}
