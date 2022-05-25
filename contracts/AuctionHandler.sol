// File: contracts/AuctionHandler.sol

pragma solidity ^0.8.4;

//import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
//import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
//import "./interfaces/IUnicFactory.sol";
//import "./interfaces/IConverter.sol";
//import "./interfaces/IProxyTransaction.sol";
//import "./interfaces/IGetAuctionInfo.sol";
import "./Converterv2.sol";

contract AuctionHandler is Initializable, OwnableUpgradeable {
    using SafeMathUpgradeable for uint;

    struct AuctionInfo {
        uint startTime;
        uint endTime;
        address uToken;
        uint256 nftIndexForUToken;
        bool claimed;
    }

    struct Bid {
        address bidder;
        uint256 amount;
    }

    // Info of each pool.
    AuctionInfo[] public auctionInfo;

    // Auction index to bid
    mapping(uint256 => Bid) public bids;
    // Auction index to user address to amount
    mapping(uint256 => mapping(address => uint256)) public bidRefunds;
    // uToken address to NFT index to auction index
    mapping(address => mapping(uint256 => uint256)) public auctionIndex;
    // uToken address to NFT index to bool
    mapping(address => mapping(uint256 => bool)) public auctionStarted;
    // uToken address to vault balances
    mapping(address => uint256) public vaultBalances;

    address public factory;
    // 3 days
    uint public duration;
    // 105
    uint8 public minBidMultiplier;
    // 5 minutes?
    uint public auctionExtension;
    // 100 (1%)
    uint8 public feeDivisor;

    address public feeToSetter;
    address public feeTo;

    event AuctionCreated(uint256 indexed auctionId, address indexed uToken, uint256 nftIndexForUToken, uint startTime, uint indexed endTime);
    event BidCreated(uint256 indexed auctionId, address indexed bidder, uint256 amount, uint indexed endTime);
    event BidRemoved(uint256 indexed auctionId, address indexed bidder);
    event ClaimedNFT(uint256 indexed auctionId, address indexed winner);

    function initialize(
        address _factory,
        uint _duration,
        uint8 _minBidMultiplier,
        uint _auctionExtension,
        uint8 _feeDivisor,
        address _feeToSetter,
        address _feeTo
    ) public initializer {
        require(_factory != address(0) && _feeToSetter != address(0) && _feeTo != address(0), "Invalid address");
        require(_minBidMultiplier > 100 && _minBidMultiplier < 200, "Invalid multiplier");
        require(_feeDivisor > 1, "Invalid fee divisor");
        require(_feeDivisor > uint256(100).div(uint256(100).mul(_minBidMultiplier).div(100).sub(100)), "Invalid fee vs multiplier");
        __Ownable_init();
        factory = _factory;
        duration = _duration;
        minBidMultiplier = _minBidMultiplier;
        auctionExtension = _auctionExtension;
        feeDivisor = _feeDivisor;
        feeToSetter = _feeToSetter;
        feeTo = _feeTo;
    }

    function auctionLength() external view returns (uint256) {
        return auctionInfo.length;
    }

    function newAuction(address _uToken, uint256 _nftIndexForUToken) public payable {
        require(IUnicFactory(factory).getUToken(_uToken) != 0 || IUnicFactory(factory).uTokens(0) == _uToken,
            "AuctionHandler: uToken contract must be valid");
        require(Converter(_uToken).active(), "AuctionHandler: Can not bid on inactive uToken");
        (address contractAddr, , , uint256 triggerPrice) = Converter(_uToken).nfts(_nftIndexForUToken);
        // Check that nft index exists on vault contract
        require(contractAddr != address(0), "AuctionHandler: NFT index must exist");
        // Check that bid meets reserve price
        require(triggerPrice <= msg.value, "AuctionHandler: Starting bid must be higher than trigger price");
        require(!auctionStarted[_uToken][_nftIndexForUToken], "AuctionHandler: NFT already on auction");
        auctionStarted[_uToken][_nftIndexForUToken] = true;

        uint256 currentIndex = auctionInfo.length;
        uint auctionEndTime = getBlockTimestamp().add(duration);

        auctionInfo.push(
            AuctionInfo({
                startTime: getBlockTimestamp(),
                endTime: auctionEndTime,
                uToken: _uToken,
                nftIndexForUToken: _nftIndexForUToken,
                claimed: false
            })
        );

        auctionIndex[_uToken][_nftIndexForUToken] = currentIndex;
        uint256 fee = msg.value.div(feeDivisor);
        vaultBalances[_uToken] = vaultBalances[_uToken].add(msg.value.sub(fee));
        bids[currentIndex] = Bid(msg.sender, msg.value);
        sendFee(fee);

        emit AuctionCreated(currentIndex, _uToken, _nftIndexForUToken, getBlockTimestamp(), auctionEndTime);
        emit BidCreated(currentIndex, msg.sender, msg.value, auctionEndTime);
    }

    function bid(uint256 _auctionId) public payable {
        AuctionInfo storage thisAuction = auctionInfo[_auctionId];
        require(getBlockTimestamp() < thisAuction.endTime, "AuctionHandler: Auction for NFT ended");
        require(Converter(thisAuction.uToken).active(), "AuctionHandler: Can not bid on inactive uToken");

        Bid storage topBid = bids[_auctionId];
        require(topBid.bidder != msg.sender, "AuctionHandler: You have an active bid");
        require(topBid.amount.mul(minBidMultiplier) <= msg.value.mul(100), "AuctionHandler: Bid too low");
        require(bidRefunds[_auctionId][msg.sender] == 0, "AuctionHandler: Collect bid refund first");

        // Case where new top bid occurs near end time
        // In this case we add an extension to the auction
        if(getBlockTimestamp() > thisAuction.endTime.sub(auctionExtension)) {
            thisAuction.endTime = getBlockTimestamp().add(auctionExtension);
        }

        bidRefunds[_auctionId][topBid.bidder] = topBid.amount;
        uint256 fee = (msg.value.sub(topBid.amount)).div(feeDivisor);
        vaultBalances[thisAuction.uToken] = vaultBalances[thisAuction.uToken].add(msg.value).sub(topBid.amount).sub(fee);

        topBid.bidder = msg.sender;
        topBid.amount = msg.value;

        sendFee(fee);

        emit BidCreated(_auctionId, msg.sender, msg.value, thisAuction.endTime);
    }

    function unbid(uint256 _auctionId) public {
        Bid memory topBid = bids[_auctionId];
        require(topBid.bidder != msg.sender, "AuctionHandler: Top bidder can not unbid");

        uint256 refundAmount = bidRefunds[_auctionId][msg.sender];
        require(refundAmount > 0, "AuctionHandler: No bid found");
        bidRefunds[_auctionId][msg.sender] = 0;
        (bool sent, bytes memory data) = msg.sender.call{value: refundAmount}("");
        require(sent, "AuctionHandler: Failed to send Ether");

        emit BidRemoved(_auctionId, msg.sender);
    }

    // Claim NFT if address is winning bidder
    function claim(uint256 _auctionId) public {
        AuctionInfo storage thisAuction = auctionInfo[_auctionId];
        require(getBlockTimestamp() > thisAuction.endTime, "AuctionHandler: Auction is not over");
        require(!thisAuction.claimed, "AuctionHandler: Already claimed");
        Bid memory topBid = bids[_auctionId];
        require(msg.sender == topBid.bidder, "AuctionHandler: Only winner can claim");

        thisAuction.claimed = true;

        require(Converter(thisAuction.uToken).claimNFT(thisAuction.nftIndexForUToken, topBid.bidder), "AuctionHandler: Claim failed");

        emit ClaimedNFT(_auctionId, topBid.bidder);
    }

    function burnAndRedeem(address _uToken, uint256 _amount) public {
        require(vaultBalances[_uToken] > 0, "AuctionHandler: No vault balance to redeem from");

        uint256 redeemAmount = _amount.mul(vaultBalances[_uToken]).div(IERC20Upgradeable(_uToken).totalSupply());
        Converter(_uToken).burnFrom(msg.sender, _amount);
        vaultBalances[_uToken] = vaultBalances[_uToken].sub(redeemAmount);

        // Redeem ETH corresponding to uToken amount
        (bool sent, bytes memory data) = msg.sender.call{value: redeemAmount}("");
        require(sent, "AuctionHandler: Failed to send Ether");
    }

    // This function is for fee-taking
    function sendFee(uint256 _fees) internal {
        // Send fee to feeTo address
        (bool sent, bytes memory data) = feeTo.call{value: _fees}("");
        require(sent, "AuctionHandler: Failed to send Ether");
    }

    function setFactory(address _factory) public onlyOwner {
        factory = _factory;
    }

    function setAuctionParameters(uint _duration, uint8 _minBidMultiplier, uint _auctionExtension, uint8 _feeDivisor) public onlyOwner {
        require(_duration > 0 && _auctionExtension > 0, "AuctionHandler: Invalid parameters");
        require(_minBidMultiplier > 100 && _minBidMultiplier < 200, "Invalid multiplier");
        require(_feeDivisor > 1, "Invalid fee divisor");
        require(_feeDivisor > uint256(100).div(uint256(100).mul(_minBidMultiplier).div(100).sub(100)), "Invalid fee vs multiplier");
        duration = _duration;
        minBidMultiplier = _minBidMultiplier;
        auctionExtension = _auctionExtension;
        feeDivisor = _feeDivisor;
    }

    function setFeeTo(address _feeTo) public {
        require(msg.sender == feeToSetter, "AuctionHandler: Not feeToSetter");
        require(_feeTo != address(0), "AuctionHandler: Fee address cannot be zero address");
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) public {
        require(msg.sender == feeToSetter, "AuctionHandler: Not feeToSetter");
        feeToSetter = _feeToSetter;
    }

    function getBlockTimestamp() internal view returns (uint) {
        // solium-disable-next-line security/no-block-members
        return block.timestamp;
    }

    function onAuction(address uToken, uint256 nftIndexForUToken) external view returns (bool) {
        return auctionStarted[uToken][nftIndexForUToken];
    }
}