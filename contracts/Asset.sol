pragma solidity >=0.4.22 <0.9.0;

contract CrowdfundedToken {

    enum AssetType {
        crowdfunding,
        tradable
    }

    // use chainlink to pay back if unsuccessful
    // a week with less than a certain amount of activity - refund
    // increasing the price depending on the activity - proably mostly centralized, not entirely though

    // always a dollar during crowdfunding
    struct ExpirationConditionTreshold = 0 // anything

    // initially have one eighth of the total supply

    struct Asset {
        uint256 _id;
        address seller;
        string name;
        uint value; // fixed until funding is complete
        uint numTokensFunded;
        uint numTokensTotal;
        AssetType type;
    }

    uint256 public numAssets = 0;

    function createToken() public {
    }    

    function changeToTradableType() public {

    }



}

