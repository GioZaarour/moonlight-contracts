pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/introspection/ERC165CheckerUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "./interfaces/IMoonFactory.sol";
import "./interfaces/IProxyTransaction.sol";
import "./interfaces/IGetAuctionInfo.sol"; 
import "./interfaces/IConverter.sol";
import "./abstract/ERC20VotesUpgradeable.sol";

contract Converter is IConverter, IProxyTransaction, Initializable, ERC1155ReceiverUpgradeable, ERC20VotesUpgradeable, OwnableUpgradeable {
    using SafeMathUpgradeable for uint;

    //list of target NFTs for crowdfunding
    struct TargetNft {
        address nftContract;
        uint tokenId;
        uint amount;
        uint buyNowPrice;
    }

    mapping(uint256 => TargetNft) public targetNfts;
    uint256 public targetNFTIndex = 0;

    // List of NFTs that have been deposited
    struct NFT {
    	address contractAddr;
    	uint256 tokenId;
        uint256 amount;
        uint256 triggerPrice;
    }

    mapping(uint256 => NFT) public nfts;
    // Current index and length of nfts
    uint256 public currentNFTIndex = 0;
    // If active, NFTs can’t be withdrawn
    bool public active = false;
    address public issuer;
    uint256 public cap; //whatever the current supply of tokens is
    address public converterTimeLock;
    IMoonFactory public factory;


    ////////////////CROWDFUND////////////////////
    //whether or not this is currently in crowdfund stage
    bool public crowdfundingMode;
    //current crowdfund goal based on buy now prices
    uint256 public crowdfundGoal;
    //how much funded so far
    uint256 fundedSoFar;
    //tracking how much stake users have in this crowdfund
    mapping (address => uint) ethContributed;
    mapping (address => uint) amountOwned;
    //how much ETH the token is worth, (artificially) set upon creation by the crowdfund creator at $10 per token (must use chainlink price oracle)
    uint moonTokenPrice;

    event Deposited(uint256[] tokenIDs, uint256[] amounts, uint256[] triggerPrices, address indexed contractAddr);
    event Refunded();
    event Issued();
    event TriggerPriceUpdate(uint256[] indexed nftIndex, uint[] price);
    event TargetAdded(uint256[] tokenIDs, uint256[] amounts, uint256[] buyNowPrices, address indexed contractAddr);
    event UpdatedGoal(uint256 newGoal);
    event BuyPriceUpdate(uint256[] indexed targetNftIndex, uint[] buyNowPrices);

    bytes private constant VALIDATOR = bytes('JCMY');

    function initialize (
        string memory name,
        string memory symbol,
        address _issuer,
        address _factory, 
        bool _crowdfundingMode
    )
        public
        initializer
        returns (bool)
    {
        require(_issuer != address(0) && _factory != address(0), "Invalid address");
        __Ownable_init();
        __ERC20_init(name, symbol);
        crowdfundingMode = _crowdfundingMode;
        issuer = _issuer;
        factory = IMoonFactory(_factory);
        cap = factory.moonTokenSupply();
        return true;
    }

    function burn(address _account, uint256 _amount) public {
        require(msg.sender == factory.auctionHandler(), "Converter: Only auction handler can burn");
        super._burn(_account, _amount);
    }

    function setCurator(address _issuer) external {
        require(active, "Converter: Tokens have not been issued yet");
        require(msg.sender == factory.owner() || msg.sender == issuer, "Converter: Not vault manager or issuer");

        issuer = _issuer;
    }

    function setTriggers(uint256[] calldata _nftIndex, uint256[] calldata _triggerPrices) external {
        require(msg.sender == issuer, "Converter: Only issuer can set trigger prices");
        require(_nftIndex.length <= 50, "Converter: A maximum of 50 trigger prices can be set at once");
        require(_nftIndex.length == _triggerPrices.length, "Array length mismatch");
        for (uint8 i = 0; i < 50; i++) {
            if (_nftIndex.length == i) {
                break;
            }
            // require(!IGetAuctionInfo(factory.auctionHandler()).onAuction(address(this), _nftIndex[i]), "Converter: Already on auction");
            nfts[_nftIndex[i]].triggerPrice = _triggerPrices[i];
        }

        emit TriggerPriceUpdate(_nftIndex, _triggerPrices);
    }

    function setConverterTimeLock(address _converterTimeLock) public override {
        require(msg.sender == address(factory), "Converter: Only factory can set converterTimeLock");
        require(_converterTimeLock != address(0), "Invalid address");
        converterTimeLock = _converterTimeLock;
    }

    //can add multiple NFTs with this but only if they come from the same collection (contractAddr)
    //otherwise will have to call this func multiple times for different NFT contracts
    //notify user that buy now price is for the whole bundle
    function addTargetNft(uint256[] calldata tokenIDs, uint256[] calldata amounts, uint256[] calldata buyNowPrices, address contractAddr) external {
        require(msg.sender == issuer, "Converter: Only issuer can add target NFTs");
        require(tokenIDs.length <= 50, "Converter: A maximum of 50 tokens can be added in one go");
        require(tokenIDs.length > 0, "Converter: You must specify at least one token ID");
        require(tokenIDs.length == buyNowPrices.length, "Array length mismatch");
        require(crowdfundingMode == true, "Converter: Crowdfund is not on");
        
        //if it is an ERC1155 we will take the amounts[] they give us
        if (ERC165CheckerUpgradeable.supportsInterface(contractAddr, 0xd9b67a26)){
            for (uint8 i = 0; i < 50; i++){
                if (i == tokenIDs.length) {
                    break;
                }
                targetNfts[targetNFTIndex++] = TargetNft(contractAddr, tokenIDs[i], amounts[i], buyNowPrices[i]);
            }
        }
        //else it is ERC721 and amounts will always be 1
        else {
            for (uint8 i = 0; i < 50; i++){
                if (i == tokenIDs.length) {
                    break;
                }
                targetNfts[targetNFTIndex++] = TargetNft(contractAddr, tokenIDs[i], 1, buyNowPrices[i]);
            }
        }
        
        //update the crowdfund goal
        updateCrowdfundGoal();
        emit TargetAdded(tokenIDs, amounts, buyNowPrices, contractAddr);
    }

    function setBuyNowPrices(uint256[] calldata _targetNftIndex, uint256[] calldata _buyNowPrices) external {
        //post-MVP: chainlink => opensea API. update periodically
        require(msg.sender == issuer, "Converter: Only issuer can set buy prices");
        require(_targetNftIndex.length <= 50, "Converter: A maximum of 50 buy prices can be set at once");
        require(_targetNftIndex.length == _buyNowPrices.length, "Array length mismatch");
        require(crowdfundingMode == true, "Converter: Crowdfund is not on");
        for (uint8 i = 0; i < 50; i++) {
            if (_targetNftIndex.length == i) {
                break;
            }
            targetNfts[_targetNftIndex[i]].buyNowPrice = _buyNowPrices[i];
        }

        emit BuyPriceUpdate(_targetNftIndex, _buyNowPrices);
        updateCrowdfundGoal();
    }

    //call this internally whenever buy prices change
    function updateCrowdfundGoal() public {
        require(crowdfundingMode == true, "Converter: Crowdfund is not on");

        //post-MVP: automatically update buy prices here, then make setBuyNowPrices() as onlyOwner

        for (uint8 i = 0; i < targetNFTIndex; i++) {
            crowdfundGoal += targetNfts[i].buyNowPrice; //holy shit github copilot is amazing
        }
        emit UpdatedGoal(crowdfundGoal);

    }

    // deposits an nft using the transferFrom action of the NFT contractAddr
    function deposit(uint256[] calldata tokenIDs, uint256[] calldata amounts, uint256[] calldata triggerPrices, address contractAddr) external {
        require(msg.sender == issuer, "Converter: Only issuer can deposit");
        require(tokenIDs.length <= 50, "Converter: A maximum of 50 tokens can be deposited in one go");
        require(tokenIDs.length > 0, "Converter: You must specify at least one token ID");
        require(tokenIDs.length == triggerPrices.length, "Array length mismatch");

        //this if statement checks if the contractAddr is an ERC1155 contract
        if (ERC165CheckerUpgradeable.supportsInterface(contractAddr, 0xd9b67a26)){
            IERC1155Upgradeable(contractAddr).safeBatchTransferFrom(msg.sender, address(this), tokenIDs, amounts, VALIDATOR);

            for (uint8 i = 0; i < 50; i++){
                if (tokenIDs.length == i){
                    break;
                }
                nfts[currentNFTIndex++] = NFT(contractAddr, tokenIDs[i], amounts[i], triggerPrices[i]);
            }
        }
        else {
            for (uint8 i = 0; i < 50; i++){
                if (tokenIDs.length == i){
                    break;
                }
                IERC721Upgradeable(contractAddr).transferFrom(msg.sender, address(this), tokenIDs[i]);
                nfts[currentNFTIndex++] = NFT(contractAddr, tokenIDs[i], 1, triggerPrices[i]);
            }
        }

        emit Deposited(tokenIDs, amounts, triggerPrices, contractAddr);
    }

    // Function that locks deposited NFTs as collateral and issues the uTokens to the issuer
    //puts the entire token supply (aka cap) in th issuers wallet (**for non-crowdfund mode)
    function issue() external {
        require(msg.sender == issuer, "Converter: Only issuer can issue the tokens");
        require(active == false, "Converter: Token is already active");
        require(crowdfundingMode == false, "Converter: Crowdfund is on");

        active = true;
        address feeTo = factory.feeTo();
        uint256 feeAmount = 0;  
        if (feeTo != address(0)) {
            feeAmount = cap.div(factory.feeDivisor());
            _mint(feeTo, feeAmount);
        }

        uint256 amount = cap - feeAmount;
        _mint(issuer, amount);

        if (!factory.airdropEnabled()) {
            emit Issued();
            return;
        }

        //EXCLUDE airdrop part
        if (!factory.receivedAirdrop(msg.sender)) {
            bool airdropEligible = false;
            for (uint8 i = 0; i < currentNFTIndex; i++) {
                if (factory.isAirdropCollection(nfts[i].contractAddr)) {
                    airdropEligible = true;
                    break;
                }
            }
            if (airdropEligible) {
                if (IERC20Upgradeable(factory.moon()).balanceOf(address(factory)) < factory.airdropAmount()) { //EXCLUDE
                    emit Issued();
                    return;
                }
                factory.setAirdropReceived(msg.sender);
                IERC20Upgradeable(factory.moon()).transferFrom(address(factory), msg.sender, factory.airdropAmount()); //EXCLUDE
            }
        }

        emit Issued();
    }

    //function to temporarily set the moonToken price for crowdfunding
    function setTokenPriceCrowdfunding() internal {

    }

    //handles minting new tokens for crowdfunding mode, whether crowdfund creator or anyone else
    function purchaseCrowdfunding(uint amount) external payable {
        require (msg.value >= amount*moonTokenPrice);
        require (crowdfundingMode == true, "Converter: Crowdfund is not on");

        //don't forget to add paying fees here
        //also more require statements, and emit events

        amountOwned[msg.sender] += amount;
        ethContributed[msg.sender] += msg.value;//check values start initialized at 0?
        _mint(msg.sender, amount);
    }

    // Function that allows NFTs to be refunded (prior to issue being called)
    function refund(address _to) external {
        require(!active, "Converter: Contract is already active - cannot refund");
        require(msg.sender == issuer, "Converter: Only issuer can refund");

        // Only transfer maximum of 50 at a time to limit gas per call
        uint8 _i = 0;
        uint256 _index = currentNFTIndex;
        bytes memory data;

        while (_index > 0 && _i < 50){
            NFT memory nft = nfts[_index - 1];

            if (ERC165CheckerUpgradeable.supportsInterface(nft.contractAddr, 0xd9b67a26)){
                IERC1155Upgradeable(nft.contractAddr).safeTransferFrom(address(this), _to, nft.tokenId, nft.amount, data);
            }
            else {
                IERC721Upgradeable(nft.contractAddr).safeTransferFrom(address(this), _to, nft.tokenId);
            }

            delete nfts[_index - 1];

            _index--;
            _i++;
        }

        currentNFTIndex = _index;

        emit Refunded();
    }

    function claimNFT(uint256 _nftIndex, address _to) external returns (bool) {
        require(msg.sender == factory.auctionHandler(), "Converter: Not auction handler");

        if (ERC165CheckerUpgradeable.supportsInterface(nfts[_nftIndex].contractAddr, 0xd9b67a26)){
            bytes memory data;
            IERC1155Upgradeable(nfts[_nftIndex].contractAddr).safeTransferFrom(address(this), _to, nfts[_nftIndex].tokenId, nfts[_nftIndex].amount, data);
        }
        else {
            IERC721Upgradeable(nfts[_nftIndex].contractAddr).safeTransferFrom(address(this), _to, nfts[_nftIndex].tokenId);
        }

        return true;
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

    /**
     * @dev See {ERC20-_beforeTokenTransfer}.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        // Move voting rights
        _moveDelegates(_delegates[from], _delegates[to], amount);
    }

    /**
     * @dev implements the proxy transaction used by {ConverterTimeLock-executeTransaction}
     */
    function forwardCall(address target, uint256 value, bytes calldata callData) external override payable returns (bool success, bytes memory returnData) {
        require(target != address(factory), "Converter: No proxy transactions calling factory allowed");
        require(target != address(factory.moon()), "Converter: No proxy transactions calling unic allowed");  // EXCLUDE
        require(msg.sender == converterTimeLock, "Converter: Caller is not the converterTimeLock contract");
        return target.call{value: value}(callData);
    }

    function getBlockTimestamp() internal view returns (uint) {
        // solium-disable-next-line security/no-block-members
        return block.timestamp;
    }
}
