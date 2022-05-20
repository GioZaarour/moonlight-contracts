pragma solidity >=0.4.22 <0.9.0;

contract FractionalToken {

    enum AssetType {
        crowdfunding,
        tradable
    }

    address parentAsset;
    uint numShares;
    uint numSharesTotal; // always going to be fixed after funding
    AssetType type;

    // send to address, number of shares to send
    // an algorithm to define the price of the shares
    function transferSharesTo(address buyer) {
        // might create a new token for the user who made the purchase.

        // check if the buyer already has a token - if so increase it!
        // if not, create a new token for the buyer
    }

    
    function changeToTradableType() public {

    }

}