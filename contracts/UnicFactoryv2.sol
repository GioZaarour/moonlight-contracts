pragma solidity ^0.8.4;

import "./interfaces/IConverter.sol";
import "./interfaces/IUnicFactory.sol";
import "./interfaces/IUnicConverterProxyTransactionFactory.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
//import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol"; 
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
//import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UnicFactory is IUnicFactory, Initializable, OwnableUpgradeable {
    using SafeMathUpgradeable for uint;

    // Address that receives fees
    address public override feeTo;

    // Address of the converter implementation used for cheap clones
    address public override converterImplementation;

    // Address that gets to set the feeTo address
    address public override feeToSetter;

    // List of uToken addresses
    address[] public override uTokens;

    address public override auctionHandler;

    uint256 public override feeDivisor;

    uint256 public override uTokenSupply;

    // 200 UNIC airdrop
    uint256 public override constant airdropAmount = 200 * 1e18;

    address public override unic;

    bool public override airdropEnabled;

    address public override proxyTransactionFactory;

    mapping(address => uint) public override getUToken;

    mapping(address => address) public override getGovernorAlpha;

    mapping(address => bool) public override isAirdropCollection;

    mapping(address => bool) public override receivedAirdrop;

    //event TokenCreated(address indexed caller, address indexed uToken);

    function uTokensLength() external override view returns (uint) {
        return uTokens.length;
    }

    function owner() public override(IUnicFactory, OwnableUpgradeable) view returns (address) {
        return super.owner();
    }

    // Constructor just needs to know who gets to set feeTo address and default fee amount`

    function initialize(
        address _feeToSetter,
        uint256 _feeDivisor,
        uint256 _uTokenSupply,
        address _unic,
        address _proxyTransactionFactory
    ) public initializer {
        require(_feeToSetter != address(0) && _unic != address(0), "Invalid address");
        __Ownable_init();
        feeToSetter = _feeToSetter;
        feeDivisor = _feeDivisor;
        uTokenSupply = _uTokenSupply;
        unic = _unic;
        proxyTransactionFactory = _proxyTransactionFactory;
        airdropEnabled = false;
    }

    function createUToken(
        string calldata name,
        string calldata symbol,
        bool enableProxyTransactions
    ) external override returns (address, address) {
        require(bytes(name).length < 32, 'UnicFactory: MAX NAME');
        require(bytes(symbol).length < 16, 'UnicFactory: MAX TICKER');

        address issuer = msg.sender;
        address converter = deployMinimal(
            converterImplementation,
            abi.encodeWithSignature("initialize(string,string,address,address)", name, symbol, issuer, address(this))
        );
        address converterGovernorAlpha;
        if (enableProxyTransactions) {
            address converterTimeLock;
            (converterGovernorAlpha, converterTimeLock) = IUnicConverterProxyTransactionFactory(proxyTransactionFactory).createProxyTransaction(converter, issuer);
            IConverter(converter).setConverterTimeLock(converterTimeLock);
            getGovernorAlpha[converter] = converterGovernorAlpha;
        }
        // Populate mapping
        getUToken[converter] = uTokens.length;
        // Add to list
        uTokens.push(converter);
        IERC20(unic).approve(converter, airdropAmount);
        emit TokenCreated(msg.sender, converter);

        return (converter, address(converterGovernorAlpha));
    }

    function toggleAirdrop() onlyOwner external override {
        airdropEnabled = true;
    }

    function setFeeTo(address _feeTo) external override {
        require(msg.sender == feeToSetter, 'Unic: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, 'Unic: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }

    function setConverterImplementation(address _converterImplementation) onlyOwner external override {
        converterImplementation = _converterImplementation;
    }

    function setAuctionHandler(address _auctionHandler) onlyOwner external override {
        auctionHandler = _auctionHandler;
    }

    function setFeeDivisor(uint256 _feeDivisor) onlyOwner external override {
        feeDivisor = _feeDivisor;
    }

    function setSupply(uint256 _uTokenSupply) onlyOwner external override {
        uTokenSupply = _uTokenSupply;
    }

    function setProxyTransactionFactory(address _proxyTransactionFactory) onlyOwner external override {
        proxyTransactionFactory = _proxyTransactionFactory;
    }

    function setAirdropCollections(address[] calldata _airdrops, bool _isOn) onlyOwner external override {
        for (uint8 i = 0; i < _airdrops.length; i++) {
            isAirdropCollection[_airdrops[i]] = _isOn;
        }
    }

    function setAirdropReceived(address _user) external override {
        require(getUToken[msg.sender] != 0 || uTokens[0] == msg.sender,
            "sender must be vault");
        receivedAirdrop[_user] = true;
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