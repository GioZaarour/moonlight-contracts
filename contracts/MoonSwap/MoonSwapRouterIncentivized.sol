pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "../interfaces/IProtocolMoonRewards.sol";
import "./interfaces/IMoonSwapV2Router02.sol";

contract MoonSwapRouterIncentivized is Initializable, PausableUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeMathUpgradeable for uint256;

    uint256 private constant ONE_ETHER = 1 ether;

    IMoonSwapV2Router02 public router;
    IProtocolMoonRewards public rewarder;

    struct WhitelistEntry {
        bool whitelisted;
    }

    uint256 public rewardPerEth;
    uint256 public budgetPerBlock;
    uint256 public totalRewardsGiven;
    bool public whitelistEnabled;

    mapping(address => WhitelistEntry) public whitelist;

    function initialize(
        address routerAddress,
        address rewarderAddress,
        uint256 rewardPerEthAmount,
        uint256 budgetPerBlockAmount
    ) public initializer {
        router = IMoonSwapV2Router02(routerAddress);
        rewarder = IProtocolMoonRewards(rewarderAddress);
        rewardPerEth = rewardPerEthAmount;
        budgetPerBlock = budgetPerBlockAmount;

        totalRewardsGiven = 0;
        whitelistEnabled = false;

        __Ownable_init();
    }

    function _assignReward(uint256 value, address[] calldata path) private {
        bool assignReward = true;
        if (whitelistEnabled) {
            for (uint8 i = 0; i < path.length; i++) {
                if (!whitelist[path[i]].whitelisted) {
                    assignReward = false;
                    break;
                }
            }
        }

        if (assignReward && value > 0) {
            uint256 reward = value.mul(rewardPerEth).div(ONE_ETHER);

            if (budgetPerBlock > 0) {
                uint256 actualReward = totalRewardsGiven.add(reward).sub(block.number.mul(budgetPerBlock));
                totalRewardsGiven += actualReward;

                rewarder.reward(msg.sender, actualReward);
            } else {
                rewarder.reward(msg.sender, reward);
            }
        }
    }

    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
    external
    payable
    whenNotPaused
    nonReentrant
    returns (uint[] memory amounts)
    {
        _assignReward(msg.value, path);
        return router.swapExactETHForTokens(amountOutMin, path, to, deadline);
    }

    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
    external
    whenNotPaused
    nonReentrant
    returns (uint[] memory amounts)
    {
        amounts = router.swapExactTokensForETH(amountIn, amountOutMin, path, to, deadline);

        if (amounts.length > 0) {
            _assignReward(amounts[amounts.length - 1], path);
        }

        return amounts;
    }

    function addToWhitelist(address tokenAddress, bool whitelisted) external onlyOwner {
        whitelist[tokenAddress] = WhitelistEntry({
            whitelisted: whitelisted
        });
    }

    function setWhitelistEnabled(bool enabled) external onlyOwner {
        whitelistEnabled = enabled;
    }

    function setRewardPerEth(uint256 rewardPerEthAmount) external onlyOwner {
        rewardPerEth = rewardPerEthAmount;
    }

    function setBudgetPerBlock(uint256 budgetPerBlockAmount) external onlyOwner {
        budgetPerBlock = budgetPerBlockAmount;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}
