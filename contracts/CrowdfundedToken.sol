pragma solidity >=0.4.22 <0.9.0;

contract CrowdfundedToken {

    enum CrowdfundedTokenListingStatus {
        active,
        completed,
    }

    struct CrowdfundedNFT {
        address seller;
        address token;
        string name;
        uint floorPrice;
        uint numSharesFunded;
    }

    // memory will copy -> Listing memory listing = _listings[index];
    // storage will assign a pointer so it will affect the real value -> Listing storage listing = _listings[index];
    
    uint private _listingId = 0;
    mapping(uint => CrowdfundedNFT) private _listings;

    function listCrowdfundingToken(address token, string name, uint floorPrice) external {
        CrowdfundedNFT asset = CrowdfundedAsset(msg.sender, token, name, floorPrice, 0);
        _listingId++;
        _crowdfundedListings[_listingId] = asset;
    }

    function purchaseFragment(uint listingId, uint numShares) external {
        CrowdfundedAsset listing = crowdfunded_assets[listingId];
        listing.num_shares_funded += num_shares;

        CrowdfundedNFT storage nft = _listings[listingId];

        require(nft.numSharesFunded === nft.floorPrice, "Listing is not active");

    }
}