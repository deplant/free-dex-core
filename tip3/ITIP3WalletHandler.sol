pragma ton-solidity >= 0.36.0;

pragma AbiHeader expire;

/// @title Melnorme\IRootTokenContract
/// @author https://github.com/broxus
/// @notice Interface for implementing TIP-3 root contract methods

/// @notice TIP3 Extension: Handle Callbacks from Fungible
interface ITIP3WalletFungibleHandler {

    /// @notice Callback for internalTrasfer
    function onDeploy(
        uint16  status,        
        uint256 walletPubkey,   
        address walletOwner,               
        TvmCell payload,
        uint256 invokerPubkey,
        address invokerAddress
    ) external;    

    /// @notice Callback for internalTrasfer
    function onTokensReceived(
        uint16  status,         
        uint256 walletPubkey, 
        address walletOwner,                 
        uint128 tokens,
        TvmCell payload,
        uint256 invokerPubkey,
        address invokerAddress,
        address receivedFrom
    ) external;

    /// @notice Callback for internalTrasferFrom
    function onTokensSent(
        uint16  status,         
        uint256 walletPubkey,  
        address walletOwner,                
        uint128 tokens,
        TvmCell payload,
        uint256 invokerPubkey,
        address invokerAddress,
        address sentTo
    ) external;

    /// @notice Callback for approve
    function onSpendApproved(
        uint16  status,         
        uint256 walletPubkey,
        address walletOwner,                  
        uint128 tokens,
        TvmCell payload,
        uint256 invokerPubkey,
        address invokerAddress,
        address spender
    ) external;    

}

/// @notice TIP3 Extension: Handle Callbacks from Root Burnable
interface ITIP3WalletRootBurnableHandler {

    /// @notice Callback for burn
    function onBurned(
        uint16  status,         
        address walletPubkey,        
        uint128 tokens,
        TvmCell payload,
        uint256 invokerPubkey,
        address invokerAddress
    ) external;

}


