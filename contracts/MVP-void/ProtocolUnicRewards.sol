pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "./abstract/EmergencyWithdrawable.sol";
import "./interfaces/IProtocolUnicRewards.sol";

contract ProtocolUnicRewards is Initializable, IProtocolUnicRewards, PausableUpgradeable, EmergencyWithdrawable {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct UserInfo {
        uint256 unicEarned;
        uint256 unicHarvested;
    }

    IERC20Upgradeable public unic;
    mapping(address => UserInfo) public userInfo;

    event LogUnicAdded(address indexed user, uint256 amount);
    event LogUnicHarvested(address indexed user, uint256 amount);

    function initialize(address unicAddress) public initializer {
        unic = IERC20Upgradeable(unicAddress);
        __Ownable_init();
    }

    function reward(address userAddress, uint256 amount) override external whenNotPaused {
        require(amount > 0, "ProtocolUnicRewards: Amount must be greater than zero");

        UserInfo storage currentUser = userInfo[userAddress];
        currentUser.unicEarned = currentUser.unicEarned.add(amount);

        emit LogUnicAdded(userAddress, amount);
    }

    function harvest() override external whenNotPaused {
        uint256 availableReward = userInfo[msg.sender].unicEarned.sub(userInfo[msg.sender].unicHarvested);

        require(availableReward > 0, "ProtocolUnicRewards: No rewards available");
        require(unic.balanceOf(address(this)) > availableReward, "ProtocolUnicRewards: Not enough balance to harvest");

        userInfo[msg.sender].unicHarvested = userInfo[msg.sender].unicHarvested.add(availableReward);
        unic.transfer(msg.sender, availableReward);
        emit LogUnicHarvested(msg.sender, availableReward);
    }

    function pendingReward() external view returns (uint256) {
        return userInfo[msg.sender].unicEarned.sub(userInfo[msg.sender].unicHarvested);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}
