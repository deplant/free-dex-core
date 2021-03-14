pragma ton-solidity >= 0.38.2;

/// @title LiquiSOR\IDEXRoot
/// @author laugan
/// @notice Interface to work with DEXRoot


interface IDEXRoot 
{
    function getTokenExists(address rootAddress) external view returns(bool);
    function getPoolAddress(address _tokenA, address _tokenB) external view returns (address poolAddress);
    function importToken(address _rootAddr) external;
    function deployPool(address _tokenA, address _tokenB) external returns(address poolAddress);
    //function onGetInfo(ITIP3RootFungible.TokenDetails details) public;     
}