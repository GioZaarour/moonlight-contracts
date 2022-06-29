pragma solidity 0.6.12;

import "./interfaces/IVault.sol";
import './interfaces/IMoonFactory.sol';
import './interfaces/IMoonVaultProxyTransactionFactory.sol';
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MoonFactory is IMoonFactory, Initializable, OwnableUpgradeable {
    using SafeMathUpgradeable for uint;

    // Address that receives fees
    address public override feeTo;

    // Address of the vault implementation used for cheap clones
    address public override vaultImplementation;

    // Address that gets to set the feeTo address
    address public override feeToSetter;

    // List of moonToken addresses
    address[] public override moonTokens;

    address public override auctionHandler;

    //fee divisor taken on issuance of fractionalized tokens (paid in moonToken)
    uint256 public override feeDivisor; 

    //fee divisor taken on crowdfund contributions
    uint256 public override crowdfundFeeDivisor;

    uint256 public override moonTokenSupply;

    address public override proxyTransactionFactory;

    //2419000 or 4 weeks
    uint public override crowdfundDuration;

    uint public override usdCrowdfundingPrice;

    mapping(address => uint) public override getMoonToken; //maps address to the index of the moonToken in the moonTokens array

    mapping(address => address) public override getGovernorAlpha;

    event TokenCreated(address indexed caller, address indexed moonToken);

    function moonTokensLength() external override view returns (uint) {
        return moonTokens.length;
    }

    function owner() public override(IMoonFactory, OwnableUpgradeable) view returns (address) {
        return super.owner();
    }

    // Constructor just needs to know who gets to set feeTo address and default fee amount`
    function initialize(
        address _feeToSetter,
        uint256 _feeDivisor,
        uint256 _moonTokenSupply,
        address _proxyTransactionFactory, 
        uint _crowdfundDuration, 
        uint _crowdfundFeeDivisor,
        uint _usdCrowdfundingPrice
    ) public initializer {
        require(_feeToSetter != address(0), "Invalid feeToSetter address");
        __Ownable_init();
        feeToSetter = _feeToSetter;
        feeDivisor = _feeDivisor;
        moonTokenSupply = _moonTokenSupply;
        proxyTransactionFactory = _proxyTransactionFactory;
        crowdfundDuration = _crowdfundDuration;
        crowdfundFeeDivisor = _crowdfundFeeDivisor;
        usdCrowdfundingPrice = _usdCrowdfundingPrice;
    }

    function createMoonToken(
        string calldata name,
        string calldata symbol,
        bool enableProxyTransactions,
        bool crowdfundingMode ,
        uint256 supply
    ) external override returns (address, address) {
        require(bytes(name).length < 32, 'MoonFactory: MAX NAME');
        require(bytes(symbol).length < 16, 'MoonFactory: MAX TICKER');

        address issuer = msg.sender;
        address vault = deployMinimal(
            vaultImplementation,
            abi.encodeWithSignature("initialize(string,string,address,address)", name, symbol, issuer, address(this), crowdfundingMode, supply)
        );
        address vaultGovernorAlpha;
        if (enableProxyTransactions) {
            address vaultTimeLock;
            (vaultGovernorAlpha, vaultTimeLock) = IMoonVaultProxyTransactionFactory(proxyTransactionFactory).createProxyTransaction(vault, issuer);
            IVault(vault).setVaultTimeLock(vaultTimeLock); 
            getGovernorAlpha[vault] = vaultGovernorAlpha;
        }
        // Populate mapping
        getMoonToken[vault] = moonTokens.length;
        // Add to list
        moonTokens.push(vault);
        emit TokenCreated(msg.sender, vault);

        return (vault, address(vaultGovernorAlpha));
    }

    function setFeeTo(address _feeTo) external override {
        require(msg.sender == feeToSetter, 'Moon: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, 'Moon: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }

    function setCrowdfundDuration(uint _crowdfundDuration) external onlyOwner {
        crowdfundDuration = _crowdfundDuration;
    }

    function setCrowdfundFeeDivisor(uint _crowdfundFeeDivisor) external onlyOwner {
        crowdfundFeeDivisor = _crowdfundFeeDivisor;
    }

    function setUsdCrowdfundingPrice(uint _usdCrowdfundingPrice) external onlyOwner {
        usdCrowdfundingPrice = _usdCrowdfundingPrice;
    }

    function setVaultImplementation(address _vaultImplementation) onlyOwner external override {
        vaultImplementation = _vaultImplementation;
    }

    function setAuctionHandler(address _auctionHandler) onlyOwner external override {
        auctionHandler = _auctionHandler;
    }

    function setFeeDivisor(uint256 _feeDivisor) onlyOwner external override {
        feeDivisor = _feeDivisor;
    }

    function setSupply(uint256 _moonTokenSupply) onlyOwner external override {
        moonTokenSupply = _moonTokenSupply;
    }

    function setProxyTransactionFactory(address _proxyTransactionFactory) onlyOwner external override {
        proxyTransactionFactory = _proxyTransactionFactory;
    }

    // Adapted from https://github.com/OpenZeppelin/openzeppelin-sdk/blob/v2.6.0/packages/lib/contracts/upgradeability/ProxyFactory.sol#L18
    function deployMinimal(address _logic, bytes memory _data) public returns (address proxy) {
        // Adapted from https://github.com/optionality/clone-factory/blob/32782f82dfc5a00d103a7e61a17a5dedbd1e8e9d/contracts/CloneFactory.sol
        bytes20 targetBytes = bytes20(_logic);
        assembly {
            let clone := mload(0x40)
            mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(clone, 0x14), targetBytes)
            mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            proxy := create(0, clone, 0x37)
        }

        if (_data.length > 0) {
            (bool success,) = proxy.call(_data);
            require(success);
        }
    }
}
