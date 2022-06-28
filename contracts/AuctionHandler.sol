pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import './interfaces/IMoonFactory.sol';
import './Vault.sol';

contract AuctionHandler is Initializable, OwnableUpgradeable {
    using SafeMathUpgradeable for uint;

    struct AuctionInfo {
        uint startTime;
        uint endTime;
        address moonToken;
        uint256 nftIndexForMoonToken;
        bool claimable;
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
    // moonToken address to NFT index to auction index
    mapping(address => mapping(uint256 => uint256)) public auctionIndex;
    // moonToken address to NFT index to bool
    mapping(address => mapping(uint256 => bool)) public auctionStarted;
    // moonToken address to vault balances
    mapping(address => uint256) public vaultBalances;

    IMoonFactory public factory;
    // 36 hours
    uint public duration;
    // 105 = next bid must be 5% above top bid to be new top bid
    uint8 public minBidMultiplier;
    // 5 minutes
    uint public auctionExtension;
    // 50 (2%)
    uint8 public feeDivisor;

    address public feeToSetter;
    address public feeTo;

    event AuctionCreated(uint256 indexed auctionId, address indexed moonToken, uint256 nftIndexForMoonToken, uint startTime, uint indexed endTime);
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
        factory = IMoonFactory(_factory);
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

    function newAuction(address _moonToken, uint256 _nftIndexForMoonToken) public payable {
        require(IMoonFactory(factory).getMoonToken(_moonToken) != 0 || IMoonFactory(factory).moonTokens(0) == _moonToken, 
            "AuctionHandler: moonToken contract must be valid");
        require(Vault(_moonToken).active(), "AuctionHandler: Can not bid on inactive moonToken");
        //get the contract address and trigger price of the given NFT
        (address contractAddr, , , uint256 triggerPrice) = Vault(_moonToken).nfts(_nftIndexForMoonToken);
        //verify that the vault is not in crowdfund
        require(Vault(_moonToken).crowdfundingMode() == false, "AuctionHandler: newAuction: Can not bid on NFTs in crowdfunding mode");
        // Check that nft index exists on vault contract
        require(contractAddr != address(0), "AuctionHandler: NFT index must exist");
        // Check that bid meets reserve price
        require(triggerPrice <= msg.value, "AuctionHandler: Starting bid must be higher than trigger price");
        require(!auctionStarted[_moonToken][_nftIndexForMoonToken], "AuctionHandler: NFT already on auction");
        auctionStarted[_moonToken][_nftIndexForMoonToken] = true;

        uint256 currentIndex = auctionInfo.length;
        uint auctionEndTime = getBlockTimestamp().add(duration);

        auctionInfo.push(
            AuctionInfo({
                startTime: getBlockTimestamp(),
                endTime: auctionEndTime,
                moonToken: _moonToken,
                nftIndexForMoonToken: _nftIndexForMoonToken,
                claimable: false,
                claimed: false
            })
        );

        auctionIndex[_moonToken][_nftIndexForMoonToken] = currentIndex;
        uint256 fee = msg.value.div(feeDivisor);
        vaultBalances[_moonToken] = vaultBalances[_moonToken].add(msg.value.sub(fee));
        bids[currentIndex] = Bid(msg.sender, msg.value);
        sendFee(fee);

        emit AuctionCreated(currentIndex, _moonToken, _nftIndexForMoonToken, getBlockTimestamp(), auctionEndTime);
        emit BidCreated(currentIndex, msg.sender, msg.value, auctionEndTime);
    }

    function bid(uint256 _auctionId) public payable {
        AuctionInfo storage thisAuction = auctionInfo[_auctionId];
        require(getBlockTimestamp() < thisAuction.endTime, "AuctionHandler: Auction for NFT ended");
        require(Vault(thisAuction.moonToken).active(), "AuctionHandler: Can not bid on inactive moonToken");

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
        vaultBalances[thisAuction.moonToken] = vaultBalances[thisAuction.moonToken].add(msg.value).sub(topBid.amount).sub(fee);

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

    // after the auction ends, a proposer or the issuer must make a proposal to toggleClaimable() if they and the community want to sell the NFT
    //if vote goes through, this function will be called and the NFT will be claimable
    function toggleClaimable(uint256 _auctionId) public {
        AuctionInfo storage thisAuction = auctionInfo[_auctionId];
        //require that the sender is the vault's timelock or moonlight
        //post-beta remove allowing the curator to call this function
        require(msg.sender == Vault(thisAuction.moonToken).vaultTimeLock() || msg.sender == factory.owner() || msg.sender == Vault(thisAuction.moonToken).issuer(), "AuctionHandler::toggleClaimable : Only vault's timelock or moonlight can toggle claimable");
        require(getBlockTimestamp() > thisAuction.endTime, "AuctionHandler::toggleClaimable : Auction duration must have ended");

        thisAuction.claimable = !thisAuction.claimable;
    }


    // Claim NFT if address is winning bidder
    function claim(uint256 _auctionId) public {
        AuctionInfo storage thisAuction = auctionInfo[_auctionId];
        require(getBlockTimestamp() > thisAuction.endTime, "AuctionHandler: Auction or buffer period is not over");
        require(thisAuction.claimable, "AuctionHandler: claim: Auction is not claimable");
        require(!thisAuction.claimed, "AuctionHandler: Already claimed");
        Bid memory topBid = bids[_auctionId];
        require(msg.sender == topBid.bidder, "AuctionHandler: Only winner can claim");

        thisAuction.claimed = true;

        require(Vault(thisAuction.moonToken).claimNFT(thisAuction.nftIndexForMoonToken, topBid.bidder), "AuctionHandler: Claim failed");

        emit ClaimedNFT(_auctionId, topBid.bidder);
    }

    //how a user can withdraw pro-rata shares of auction proceeds
    function burnAndRedeem(address _moonToken, uint256 _amount) public {
        require(vaultBalances[_moonToken] > 0, "AuctionHandler: No vault balance to redeem from");

        uint256 redeemAmount = _amount.mul(vaultBalances[_moonToken]).div(IERC20Upgradeable(_moonToken).totalSupply());
        Vault(_moonToken).burnFrom(msg.sender, _amount);
        vaultBalances[_moonToken] = vaultBalances[_moonToken].sub(redeemAmount);

        // Redeem ETH corresponding to moonToken amount
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
        factory = IMoonFactory(_factory);
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
    
    function setFeeDivisor(uint256 _feeDivisor) external {
        require(msg.sender == factory.owner() || msg.sender == feeToSetter, "AuctionHandler::setFeeDivisor: Not allowed to set fee divisor");
        feeDivisor = _feeDivisor;

    }

    function getBlockTimestamp() internal view returns (uint) {
        // solium-disable-next-line security/no-block-members
        return block.timestamp;
    }

    function onAuction(address moonToken, uint256 nftIndexForMoonToken) external view returns (bool) {
        return auctionStarted[moonToken][nftIndexForMoonToken];
    }
}
