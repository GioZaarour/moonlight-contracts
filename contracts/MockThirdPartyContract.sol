pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

// Test contract for proxy transactions
contract MockThirdPartyContract {

    event Verified(bool verified);
    event Payed(uint256 amount);

    function verifyOwnership(address tokenContract, uint256 tokenId) public {
        emit Verified(IERC721(tokenContract).ownerOf(tokenId) == msg.sender);
    }

    function pay() public payable {
        emit Payed(msg.value);
    }
}
