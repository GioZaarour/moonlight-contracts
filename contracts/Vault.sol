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
import "./interfaces/IVault.sol";
import "./abstract/ERC20VotesUpgradeable.sol";

//for chainlink price feed
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";

contract Vault is IVault, IProxyTransaction, Initializable, ERC1155ReceiverUpgradeable, ERC20VotesUpgradeable, OwnableUpgradeable {
    using SafeMathUpgradeable for uint;

    //list of target NFTs for crowdfunding
    struct TargetNft {
        address nftContract;
        uint tokenId;
        uint amount;
        uint buyNowPrice;
    }

    mapping(uint256 => TargetNft) public targetNfts;
    uint256 public targetNFTIndex;

    // List of NFTs that have been deposited
    struct NFT {
    	address contractAddr;
    	uint256 tokenId;
        uint256 amount;
        uint256 triggerPrice;
    }

    mapping(uint256 => NFT) public nfts;
    // Current index and length of nfts
    uint256 public currentNFTIndex;
    // If active, NFTs can’t be withdrawn
    bool public active; //default in solidity is false
    address public issuer;
    uint256 public cap; //whatever the current supply of tokens is
    address public vaultTimeLock;
    IMoonFactory public factory;

    ////////////////CROWDFUND////////////////////
    //whether or not this is currently in crowdfund stage
    bool public crowdfundingMode;
    //current crowdfund goal based on buy now prices
    uint256 public crowdfundGoal;
    //how much funded so far
    uint256 public fundedSoFar;
    //tracking how much stake users have in this crowdfund
    mapping (address => uint) public ethContributed;
    mapping (address => uint) public amountOwned;
    //tracking how much contribution fees have been collected to the vault
    uint256 contributionFees;
    //chainlink aggregator interface for price feed
    AggregatorV3Interface internal priceFeed;
    //how much ETH the crowdfund token is worth, (artificially) set upon creation by the crowdfund creator at $10 per token (must use chainlink price oracle)
    uint public moonTokenCrowdfundingPrice;
    //crowdfund time tracking
    uint public duration;
    uint public startTime;
    uint public endTime;

    event Deposited(uint256[] tokenIDs, uint256[] amounts, uint256[] triggerPrices, address indexed contractAddr);
    event Refunded();
    event Issued();
    event TriggerPriceUpdate(uint256[] indexed nftIndex, uint[] price);
    event TargetAdded(uint256[] tokenIDs, uint256[] amounts, uint256[] buyNowPrices, address[] indexed contractAddr);
    event TargetUpdated(uint256 indexed targetNftIndex, uint256 tokenID, uint256 amount, address indexed contractAddr);
    event UpdatedGoal(uint256 newGoal);
    event BuyPriceUpdate(uint256[] indexed targetNftIndex, uint[] buyNowPrices);
    event PurchasedCrowdfund(address indexed buyer, uint256 amount);
    event WithdrawnCrowdfund(address indexed user);
    event CrowdfundSuccess();
    event BoughtNfts();
    event TerminatedCrowdfund();

    bytes private constant VALIDATOR = bytes('JCMY');

    function initialize (
        string memory name,
        string memory symbol,
        address _issuer,
        address _factory, 
        bool _crowdfundingMode, 
        uint256 _supply
    )
        public
        initializer
        returns (bool)
    {
        require(_issuer != address(0) && _factory != address(0), "Invalid address");
        __Ownable_init();
        __ERC20_init(name, symbol);
        crowdfundingMode = _crowdfundingMode;
        issuer = _issuer; //issuer is curator
        factory = IMoonFactory(_factory);

        if (_crowdfundingMode) {
            startTime = getBlockTimestamp();
            endTime = startTime.add(factory.crowdfundDuration());
            /**
            * Network: Kovan
            * Aggregator: ETH/USD
            * Address: 0x9326BFA02ADD2366b30bacB125260Af641031331
            * set the price feed. change to eth mainnet after testing is done
            */
            priceFeed = AggregatorV3Interface(0x9326BFA02ADD2366b30bacB125260Af641031331);

            //set the moonToken CrowdfundingPrice (a temporary price during crowdfund)= 10 dollars of ETH
            moonTokenCrowdfundingPrice = (uint256)(10**18).mul( factory.usdCrowdfundingPrice().div( uint(getLatestPrice()).div(10**8) ) ); //convert ether to wei by * 10^18
        }
        else {
            cap = _supply;
        }

        return true;
    }

    function getLatestPrice() public view returns (int) {
        (
            /*uint80 roundID*/,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();
        return price;
    }

    function burn(address _account, uint256 _amount) public {
        require(msg.sender == factory.auctionHandler(), "Vault: Only auction handler can burn");
        super._burn(_account, _amount);
    }

    function setCurator(address _issuer) external {
        require(active, "Vault: Tokens have not been issued yet");
        require(msg.sender == factory.owner() || msg.sender == issuer, "Vault: Not vault manager or issuer");

        issuer = _issuer;
    }

    function setTriggers(uint256[] calldata _nftIndex, uint256[] calldata _triggerPrices) external {
        require(msg.sender == issuer, "Vault: Only issuer can set trigger prices");
        require(_nftIndex.length <= 50, "Vault: A maximum of 50 trigger prices can be set at once");
        require(_nftIndex.length == _triggerPrices.length, "Array length mismatch");
        require(crowdfundingMode == false, "Vault: Crowdfund is on");

        for (uint8 i = 0; i < 50; i++) {
            if (_nftIndex.length == i) {
                break;
            }
            // require(!IGetAuctionInfo(factory.auctionHandler()).onAuction(address(this), _nftIndex[i]), "Vault: Already on auction");
            nfts[_nftIndex[i]].triggerPrice = _triggerPrices[i];
        }

        emit TriggerPriceUpdate(_nftIndex, _triggerPrices);
    }

    function setVaultTimeLock(address _vaultTimeLock) public override {
        require(msg.sender == address(factory), "Vault: Only factory can set vaultTimeLock");
        require(_vaultTimeLock != address(0), "Invalid address");
        vaultTimeLock = _vaultTimeLock;
    }

    //can add multiple NFTs with this but only if they come from the same collection (contractAddr)
    //otherwise will have to call this func multiple times for different NFT contracts
    //notify user that buy now price is for the whole bundle
    function addTargetNft(uint256[] calldata tokenIDs, uint256[] calldata amounts, uint256[] calldata buyNowPrices, address[] calldata contractAddr) external {
        require(msg.sender == issuer, "Vault: Only issuer can add target NFTs");
        require(tokenIDs.length <= 50, "Vault: A maximum of 50 tokens can be added in one go");
        require(tokenIDs.length > 0, "Vault: You must specify at least one token ID");
        require(tokenIDs.length == buyNowPrices.length, "Array length mismatch");
        require(crowdfundingMode == true, "Vault: Crowdfund is not on");

        for (uint8 i = 0; i < 50; i++){
            if (i == tokenIDs.length) {
                break;
            }

            //if it is an ERC1155 we will take the amounts[] they give us
            if(ERC165CheckerUpgradeable.supportsInterface(contractAddr[i], 0xd9b67a26)) {
                targetNfts[targetNFTIndex++] = TargetNft(contractAddr[i], tokenIDs[i], amounts[i], buyNowPrices[i]);
            }
            //else it is ERC721 and amounts will always be 1
            else {
                targetNfts[targetNFTIndex++] = TargetNft(contractAddr[i], tokenIDs[i], 1, buyNowPrices[i]);
            }

        }
        
        /*
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
        } */
        
        //update the crowdfund goal
        updateCrowdfundGoal();
        emit TargetAdded(tokenIDs, amounts, buyNowPrices, contractAddr);
    }

    function setBuyNowPrices(uint256[] calldata _targetNftIndex, uint256[] calldata _buyNowPrices) external {
        //important note that for erc1155, buy-now price is of the whole batch (of amount)
        //post-MVP: chainlink => opensea API. update periodically
        require(msg.sender == issuer, "Vault: Only issuer can set buy prices");
        require(_targetNftIndex.length <= 50, "Vault: A maximum of 50 buy prices can be set at once");
        require(_targetNftIndex.length == _buyNowPrices.length, "Array length mismatch");
        require(crowdfundingMode == true, "Vault: Crowdfund is not on");
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
        require(crowdfundingMode == true, "Vault: Crowdfund is not on");
        crowdfundGoal = 0;

        //post-MVP: automatically update buy prices here, then make setBuyNowPrices() as onlyOwner

        for (uint8 i = 0; i < targetNFTIndex; i++) {
            crowdfundGoal += targetNfts[i].buyNowPrice;
        }
        emit UpdatedGoal(crowdfundGoal);

    }

    // deposits an nft using the transferFrom action of the NFT contractAddr
    //can only do from one contract address at a time because transfer function is either ERC721 or ERC1155
    function deposit(uint256[] calldata tokenIDs, uint256[] calldata amounts, uint256[] calldata triggerPrices, address contractAddr) external {
        require(msg.sender == issuer, "Vault: Only issuer can deposit");
        require(tokenIDs.length <= 50, "Vault: A maximum of 50 tokens can be deposited in one go");
        require(tokenIDs.length > 0, "Vault: You must specify at least one token ID");
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

    // Function that locks deposited NFTs as collateral and issues the moonTokens to the issuer
    //puts the entire token supply (the "cap") in th issuers wallet (**for non-crowdfund mode)
    function issue() external {
        require(msg.sender == issuer, "Vault: Only issuer can issue the tokens");
        require(active == false, "Vault: Token is already active");
        require(crowdfundingMode == false, "Vault: Crowdfund is on");

        active = true;
        address feeTo = factory.feeTo();
        uint256 feeAmount = 0;  
        if (feeTo != address(0)) {
            feeAmount = cap.div(factory.feeDivisor());
            _mint(feeTo, feeAmount);
        }

        uint256 amount = cap - feeAmount;
        _mint(issuer, amount);

        emit Issued();
    }

    //handles minting new tokens for crowdfunding mode, whether crowdfund creator or anyone else
    function purchaseCrowdfunding(uint amount) external payable {
        uint beforeFees = amount.mul(moonTokenCrowdfundingPrice);
        uint fee = beforeFees.div(factory.crowdfundFeeDivisor());
        uint requiredAmount = beforeFees.add(fee);

        require (msg.value >= requiredAmount, "Vault: Not enough ETH sent");
        require (crowdfundingMode == true, "Vault: Crowdfund is not on");
        require(active == false, "Vault: Token is already active");
        require(getBlockTimestamp() < endTime, "Vault: Crowdfund has terminated");

        //first case: conbribution balance (including this contribution) is less than or equal to the crowdfundgoal
        if ( address(this).balance.sub(contributionFees) <= crowdfundGoal) {
            _mint(msg.sender, amount);

            amountOwned[msg.sender] = amountOwned[msg.sender].add(amount);
            ethContributed[msg.sender] = ethContributed[msg.sender].add(msg.value);
            //increment total fees accrued in contract
            contributionFees = contributionFees.add(fee);
            fundedSoFar = fundedSoFar.add( msg.value.sub(fee) );

            emit PurchasedCrowdfund(msg.sender, amount);
        }
        //second case: this message's value made money in contract exceed the crowdfund goal
        else {
            // If the contribution balance before this contribution was already greater than the funding cap, then we should revert immediately.
            require(
                fundedSoFar < crowdfundGoal,
                "Crowdfund: Funding cap already reached"
            );
            // Otherwise, the contribution helped us reach the crowdfund goal. We should
            // take what we can until the funding cap is reached, and refund the rest.
            uint256 eligibleEth = crowdfundGoal - fundedSoFar;
            // Otherwise, we process the contribution as if it were the minimal amount.
            uint256 properAmount = eligibleEth.div(moonTokenCrowdfundingPrice);
            _mint(msg.sender, properAmount);

            amountOwned[msg.sender] = amountOwned[msg.sender].add(properAmount);
            ethContributed[msg.sender] = ethContributed[msg.sender].add(eligibleEth.add(fee));
            //increment total fees accrued in contract
            contributionFees = contributionFees.add(fee);
            fundedSoFar = fundedSoFar.add( eligibleEth );

            // Refund the sender with their contribution (e.g. 2.5 minus the diff - e.g. 1.5 = 1 ETH)
            msg.sender.transfer(msg.value.sub(eligibleEth.sub(fee)));

            emit PurchasedCrowdfund(msg.sender, properAmount);
        }
    }

    //users withdraw their contributions if the crowdfund ended or was terminated
    //need backend time tracker to check progress status when duration ends and then notify users to withdraw if goal is not reached by then
    function withdrawCrowdfunding() external {
        require(ethContributed[msg.sender] > 0, "Vault: You have no ETH to withdraw");
        require(crowdfundingMode == true, "Vault: Crowdfund is not on");
        require(getBlockTimestamp() > endTime, "Vault: Crowdfund has not ended yet");
        require(fundedSoFar < crowdfundGoal, "Vault: Crowdfund has not failed");

        super._burn(msg.sender, amountOwned[msg.sender]); //burn their tokens
        msg.sender.transfer(ethContributed[msg.sender]); //send them back their ETH

        //update ethContributed and amountOwned for msg.sender
        amountOwned[msg.sender] = 0;
        ethContributed[msg.sender] = 0;

        //emit event
        emit WithdrawnCrowdfund(msg.sender);
    } 

    //function to call when target NFT is delisted or bought before crowdfunding succeeds
    //or if the issuer wants to terminate for any other reason
    function terminateCrowdfund() external {
        require(msg.sender == issuer || msg.sender == factory.owner(), "Vault: terminateCrowdfund(): only issuer or owner can terminate");
        require(crowdfundingMode == true, "Vault: terminateCrowdfund(): Crowdfund is not on");

        //this is the best way to stop people from calling purchaseCrowdfunding() because if we set 
        //crowdfundingMode = false then the contract will reject any calls to withdrawCrowdfunding()
        endTime = 0;
        //now need to prompt users via notification to withdrawCrowdfunding()
        emit TerminatedCrowdfund();
    }

    //another alternative if the target NFT is delisted or bought before crowdfunding succeeds
    function updateTarget(uint _targetNftIndex, uint256 _tokenID, uint256 _amount, uint256 buyNowPrice, address _contractAddr) external {
        require(msg.sender == issuer || msg.sender == factory.owner(), "Vault: updateTargets(): only issuer or owner can update");
        require(crowdfundingMode == true, "Vault: updateTargets(): Crowdfund is not on");
        require(getBlockTimestamp() < endTime, "Vault: updateTargets(): Crowdfund has ended");

        //update targetNFTs
        targetNfts[_targetNftIndex].tokenId = _tokenID;
        targetNfts[_targetNftIndex].amount = _amount;
        targetNfts[_targetNftIndex].buyNowPrice = buyNowPrice;
        targetNfts[_targetNftIndex].nftContract = _contractAddr;

        updateCrowdfundGoal();
        emit TargetUpdated(_targetNftIndex, _tokenID, _amount, _contractAddr);
    }

    //need some frontend/backend progress tracker (funded so far/goal) to be able to call this function on time
    //only call this function when funded so far > goal
    function crowdfundSuccess() external {
        require (crowdfundingMode == true, "Vault: Crowdfund is not on");
        require (fundedSoFar >= crowdfundGoal, "Vault: Crowdfund has not succeeded");

        //set all the variables to stop the crowdfund phase and prepare for NFT purchase
        crowdfundingMode = false;
        active = true;
        cap = totalSupply();

        address feeTo = factory.feeTo();
        //send all ETH crowdfunding fees to moonlight
        if (feeTo != address(0)) {
            payable(feeTo).transfer(contributionFees);
        }

        //emit event
        emit CrowdfundSuccess();

        //call buy function
        betaBuyNfts();
    }

    //this releases funds to the crowdfund creator so they can manually make the purchase(s)
    //post-MVP remove this for buyNftsCrowdfunding()
    //obviously this is a bad function since curator can run off with funds, but for beta, moonlight will be the only curator -- take out the funds, buy NFT, and deposit it into vault
    function betaBuyNfts() internal {
        require (fundedSoFar >= crowdfundGoal && crowdfundGoal != 0, "Vault: Crowdfund was never on or has not succeeded yet");
        require(active == true, "Vault: Token is not active");

        payable(issuer).transfer(address(this).balance);

        //emit bought event
        emit BoughtNfts();
    }

    /**
     * Buy the target NFT(s) by calling target NFT's contract with calldata supplying value
     * Emits a Bought event upon success; reverts otherwise
     */
     /*
     //make this capable of buying ALL the target NFTs ?
    function buyNftsCrowdfunding(
        uint256 _targetNFTIndex,
        uint256 _value,
        bytes calldata _calldata
    ) public {
        require (fundedSoFar >= crowdfundGoal && crowdfundGoal != 0, "Vault: Crowdfund was never on or has not succeeded yet");
        require(active == true, "Vault: Token is not active");
        // ensure the caller is issuer OR this contract
        // ensure the the target NFT index is valid
        // check that the _value being spent is not more than available in vault
        // check that the value being spent is not zero
        //check that the value being spent is less than or equal to the buy price of the NFT
        
        // require that the NFT is NOT owned by the Vault
        require(
            _getOwner(_targetNFTIndex) != address(this),
            "PartyBuy::buy: own token before call"
        );
        // execute the calldata on the target contract
        //figure out a way to verify that calldata is executing purchase of the correct token ID
        (bool _success, bytes memory _returnData) = address(targetNfts[_targetNFTIndex].nftContract).call{value: _value}(_calldata);
        // require that the external call succeeded
        require(_success, string(_returnData));
        // require that the NFT is owned by the Vault
        require(
            _getOwner(_targetNFTIndex) == address(this),
            "PartyBuy::buy: failed to buy token"
        );

        //**ADD THE PURCHASED NFT TO nfts[] MAPPING

        // emit Bought event
        // **after purchase is done, make sure to track the new vault asset in nfts[] mapping
    } */

    //helper function to see who owns an NFT
    /*
    function _getOwner(uint _targetNFTIndex) internal view returns (address _owner) {
        (bool _success, bytes memory _returnData) = address(targetNfts[_targetNFTIndex].nftContract)
            .staticcall(abi.encodeWithSignature("ownerOf(uint256)", targetNfts[_targetNFTIndex].tokenId));
        if (_success && _returnData.length > 0) {
            _owner = abi.decode(_returnData, (address));
            return _owner;
        }
    }
    */

    // Function that allows NFTs to be refunded (prior to issue being called)
    function refund(address _to) external {
        require(!active, "Vault: Contract is already active - cannot refund");
        require(msg.sender == issuer, "Vault: Only issuer can refund");
        require(crowdfundingMode == false, "Vault: refund: crowdfunding is on");

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
        require(msg.sender == factory.auctionHandler(), "Vault: Not auction handler");

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
     * @dev implements the proxy transaction used by {VaultTimeLock-executeTransaction}
     */
    function forwardCall(address target, uint256 value, bytes calldata callData) external override payable returns (bool success, bytes memory returnData) {
        require(target != address(factory), "Vault: No proxy transactions calling factory allowed");
        require(msg.sender == vaultTimeLock, "Vault: Caller is not the vaultTimeLock contract");
        return target.call{value: value}(callData);
    }

    function getBlockTimestamp() internal view returns (uint) {
        // solium-disable-next-line security/no-block-members
        return block.timestamp;
    }
}
