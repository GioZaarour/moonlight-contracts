pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Receiver.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Copied from https://github.com/sushiswap/sushiswap/blob/master/contracts/MasterChef.sol
// Modified by 0xLeia

contract PointFarm is ERC1155Burnable, ERC1155Receiver, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    bytes private constant VALIDATOR = bytes('JCNH');

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of points
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accPointsPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accPointsPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 uToken;           // Address of LP token contract.
        uint256 lastRewardBlock;  // Last block number that points distribution occurs.
        uint256 accPointsPerShare; // Accumulated points per share, times 1e18. See below.
    }

    // Whitelist mapping of address to bool
    mapping(address => bool) public whitelist;
    // Mapping of uToken to shopIDs
    mapping(address => uint256) public shopIDs;
    uint256 public currentShopIndex = 0;
    // Points created per block.
    uint256 public pointsPerBlock;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // The block number when pointfarming starts.
    uint256 public startBlock;

    address public shop;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    // New events so that the graph works
    event Add(address uToken, bool withUpdate);
    event MassUpdatePools();
    event UpdatePool(uint256 pid);
    event URI(string _uri);

    constructor(
        uint256 _pointsPerBlock,
        uint256 _startBlock,
        string memory _uri
    )
        public
        ERC1155(_uri)
    {
        pointsPerBlock = _pointsPerBlock;
        startBlock = _startBlock;
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
        emit URI(newuri);
    }

    // Unless being used for redeem, points are non transferrable
    function safeBatchTransferFrom(address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) override virtual public {
        require(from == address(this) || to == address(this), "Points can not be transferred out");
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) override virtual public {
        require(from == address(this) || to == address(this), "Points can not be transferred out");
        super.safeTransferFrom(from, to, id, amount, data);
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new uToken to the pool. Can only be called by the shop contract.
    function add(IERC20 _uToken, bool _withUpdate) public {
        require(msg.sender == shop, "PointFarm: Only shop contract can add");
        require(!whitelist[address(_uToken)]);
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        poolInfo.push(PoolInfo({
            uToken: _uToken,
            lastRewardBlock: lastRewardBlock,
            accPointsPerShare: 0
        }));

        whitelist[address(_uToken)] = true;
        shopIDs[address(_uToken)] = currentShopIndex++;

        emit Add(address(_uToken), _withUpdate);
    }

    // Return rewards over the given _from to _to block.
    function getRewards(uint256 _from, uint256 _to) public view returns (uint256) {
        return _to.sub(_from).mul(pointsPerBlock);
    }

    // View function to see pending points on frontend.
    function pendingPoints(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accPointsPerShare = pool.accPointsPerShare;
        uint256 uTokenSupply = pool.uToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && uTokenSupply != 0) {
            uint256 pointReward = getRewards(pool.lastRewardBlock, block.number);
            accPointsPerShare = accPointsPerShare.add(pointReward.mul(1e18).div(uTokenSupply));
        }
        return user.amount.mul(accPointsPerShare).div(1e18).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }

        emit MassUpdatePools();
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 uTokenSupply = pool.uToken.balanceOf(address(this));
        if (uTokenSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 pointReward = getRewards(pool.lastRewardBlock, block.number);
        pool.accPointsPerShare = pool.accPointsPerShare.add(pointReward.mul(1e18).div(uTokenSupply));
        pool.lastRewardBlock = block.number;

        emit UpdatePool(_pid);
    }

    // Deposit uTokens to PointFarm to farm points.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accPointsPerShare).div(1e18).sub(user.rewardDebt);
            if(pending > 0) {
                bytes memory data;
                _mint(msg.sender, _pid, pending, data);
            }
        }
        if(_amount > 0) {
            pool.uToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accPointsPerShare).div(1e18);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw uTokens from PointFarm.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accPointsPerShare).div(1e18).sub(user.rewardDebt);
        if(pending > 0) {
            bytes memory data;
            _mint(msg.sender, _pid, pending, data);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.uToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accPointsPerShare).div(1e18);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.uToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // Set mint rate
    function setMintRules(uint256 _pointsPerBlock) public onlyOwner {
        pointsPerBlock = _pointsPerBlock;
    }

    function setStartBlock(uint256 _startBlock) public onlyOwner {
        require(block.number < startBlock, "start block can not be modified after it has passed");
        require(block.number < _startBlock, "new start block needs to be in the future");
        startBlock = _startBlock;
    }

    // Change shop address
    function setShop(address _shop) public onlyOwner {
        shop = _shop;
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
}
