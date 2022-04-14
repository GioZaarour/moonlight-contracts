pragma solidity >=0.4.22 <0.9.0;

contract CrowdfundedToken {

    enum CrowdfundedTokenListingStatus {
        active,
        completed,
    }

    struct CrowdfundedNFT {
        uint256 _id;
        address seller;
        string name;
        uint floorPrice;
        uint numSharesFunded;
        uint numSharesTotal;
        CrowdfundedTokenListingStatus status;
        constructor(uint256 _index, address _seller, string _name, uint256 _floorPrice, uint256 _numSharesFunded, uint256 _numSharesTotal) public {
            _id = _index;
            seller = _seller;
            name = _name;
            floorPrice = _floorPrice;
            numSharesFunded = _numSharesFunded;
            numSharesTotal = _numSharesTotal;
            status = CrowdfundedTokenListingStatus.active;
        }
    }
    uint256 public numAssets = 0;

    mapping (address => mapping (uint256 => CrowdfundedNFT)) private ownershipData;

    function createCrowdfundingToken(string name, uint floorPrice, uint numSharesTotal) public {

        // first, check if floor price & num shares are valid
        
        // instentiate the asset & add to global mapping
        numAssets++;
        CrowdfundedNFT newAsset = CrowdfundedNFT(numAssets, msg.sender, name, floorPrice, 0, numSharesTotal, status);
        ownershipData[msg.sender][newCrowdfundedNFT._id] = newCrowdfundedNFT;
    }    

    // function purchaseFragment(uint listingId, uint numShares) external {
    //     CrowdfundedAsset listing = crowdfunded_assets[listingId];
    //     listing.num_shares_funded += num_shares;

    //     CrowdfundedNFT storage nft = _listings[listingId];

    //     require(nft.numSharesFunded === nft.floorPrice, "Listing is not active");
    // }
}

    // memory will copy -> Listing memory listing = _listings[index];
    // storage will assign a pointer so it will affect the real value -> Listing storage listing = _listings[index];