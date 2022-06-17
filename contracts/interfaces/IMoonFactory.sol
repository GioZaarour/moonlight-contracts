pragma solidity >=0.5.0;

interface IMoonFactory {
    event TokenCreated(address indexed caller, address indexed moonToken);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
    function vaultImplementation() external view returns (address);

    function getMoonToken(address moonToken) external view returns (uint);
    function moonTokens(uint) external view returns (address);
    function moonTokensLength() external view returns (uint);
    function getGovernorAlpha(address moonToken) external view returns (address);
    function feeDivisor() external view returns (uint);
    function auctionHandler() external view returns (address);
    function moonTokenSupply() external view returns (uint);
    function owner() external view returns (address);
    function proxyTransactionFactory() external view returns (address);
    function crowdfundDuration() external view returns (uint);
    function crowdfundFeeDivisor() external view returns (uint);
    function usdCrowdfundingPrice() external view returns (uint);

    function createMoonToken(
        string calldata name,
        string calldata symbol,
        bool enableProxyTransactions, 
        bool crowdfundingMode ,
        uint256 supply
    ) external returns (address, address);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
    function setVaultImplementation(address) external;
    function setFeeDivisor(uint) external;
    function setAuctionHandler(address) external;
    function setSupply(uint) external;
    function setProxyTransactionFactory(address _proxyTransactionFactory) external;
}
