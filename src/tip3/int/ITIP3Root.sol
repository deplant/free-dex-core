pragma ton-solidity >= 0.38.2;

/// @title TIP3/Root Interfaces Collection
/// @author laugan
/// @notice Set of interfaces for implementing TIP-3 Root

/// @notice TIP3 Metadata Root Interface
interface ITIP3RootMetadata {

    struct TokenDetails { 
        bytes name;
        bytes symbol;
        uint8 decimals;        
        TvmCell code;
        uint128 totalSupply;
        uint128 totalGranted; 
    }        

    function getTokenInfo() external view returns (TokenDetails);

    function callTokenInfo() external responsible view returns (TokenDetails);

    /// @notice Calculates wallet address with defined public key (getter)
    function getWalletAddress(int8 workchainId, uint256 walletPubkey, address walletOwner) external view returns (address);

    /// @notice Calculates wallet address with defined public key (responsible)
    function callWalletAddress(int8 workchainId, uint256 walletPubkey, address walletOwner) external responsible view returns (address);

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

}