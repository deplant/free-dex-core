pragma ton-solidity >= 0.38.2;

/// @title TIP3/Root Interfaces Collection
/// @author laugan
/// @notice Set of interfaces for implementing TIP-3 Root

/// @notice TIP3 Metadata Root Interface
interface ITIP3RootMetadata {

    /// @notice Returns the name of the token - e.g. “MyToken”.
    function getName() external view returns (bytes name);

    /// @notice Returns the token symbol. E.g. “GRM”.
    function getSymbol() external view returns (bytes symbol);

    /// @notice Returns the number of decimals the token uses; e.g. 8, means to divide the token amount by 1,000,000,00 to get its user representation.
    function getDecimals() external view returns (uint8 decimals);

    /// @notice Returns the RTW public key.
    function getRootKey() external view returns (uint256 rootKey);

    /// @notice Returns the RTW internal owner.
    function getRootOwner() external view returns (address rootOwner);

    /// @notice Returns the total number of minted tokens.
    function getTotalSupply() external view returns (uint128 totalSupply);

    /// @notice Returns the total number of granted tokens.
    function getTotalGranted() external view returns (uint128 totalGranted);

    /// @notice Returns code of token wallet (as tree of cells).
    function getWalletCode() external view returns (TvmCell walletCode);

    /// @notice Calculates wallet address with defined public key.
    function getWalletAddress(int8 workchainId, uint256 walletPubkey, address walletOwner) external view returns (address walletAddress);
}

/// @notice TIP3 Fungible Tokens Root Interface
interface ITIP3RootFungible {

    /// @notice Allows deploying the token wallet in a specified workchain and sending some tokens to it. By owner.
    function deployWallet(int8 workchainId, uint256 walletPubkey, address walletOwner, uint128 tokens, uint128 grams) external returns (address walletAddress);

    /// @notice Allows deploying the token wallet in a specified workchain and sending some tokens to it. By regular user.
    function deployEmptyWallet(int8 workchainId, uint256 walletPubkey, address walletOwner, uint128 grams) external responsible returns (address walletAddress, TvmCell walletCode);    

    /// @notice Called by an external message only; sends tokens to the TTW. The function must call the accept function of the token wallet and increase the totalGranted value.
    function grant(address dest, uint128 tokens, uint128 grams) external;

    /// @notice Called by an external message only; emits tokens and increases totalSupply.
    function mint(uint128 tokens) external;

    function info() external responsible view returns (uint256 rootKey, address rootOwner, bytes name , bytes symbol, uint8 decimals, TvmCell code);
}