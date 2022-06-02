pragma solidity >=0.5.0;

interface IMoonFactory {
    event TokenCreated(address indexed caller, address indexed moonToken);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
    function converterImplementation() external view returns (address);

    function getMoonToken(address moonToken) external view returns (uint);
    function moonTokens(uint) external view returns (address);
    function moonTokensLength() external view returns (uint);
    function getGovernorAlpha(address moonToken) external view returns (address);
    function feeDivisor() external view returns (uint);
    function auctionHandler() external view returns (address);
    function moonTokenSupply() external view returns (uint);
    function airdropAmount() external view returns (uint);
    function airdropEnabled() external view returns (bool);
    function moon() external view returns (address); //exclude
    function isAirdropCollection(address collection) external view returns (bool);
    function receivedAirdrop(address user) external view returns (bool);
    function owner() external view returns (address);
    function proxyTransactionFactory() external view returns (address);

    function createMoonToken(
        string calldata name,
        string calldata symbol,
        bool enableProxyTransactions, 
        bool crowdfundingMode
    ) external returns (address, address);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
    function setConverterImplementation(address) external;
    function setFeeDivisor(uint) external;
    function setAuctionHandler(address) external;
    function setSupply(uint) external;
    function setProxyTransactionFactory(address _proxyTransactionFactory) external;
    function setAirdropCollections(address[] calldata, bool) external;
    function setAirdropReceived(address) external;
    function toggleAirdrop() external;
}
