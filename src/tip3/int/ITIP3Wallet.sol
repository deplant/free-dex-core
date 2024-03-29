pragma ton-solidity >= 0.38.2;

/// @title TIP3/Wallet Interfaces Collection
/// @author laugan
/// @notice Set of interfaces for implementing TIP-3 Wallet

/// @notice TIP3 Metadata Wallet Interface
interface ITIP3WalletMetadata {

    /// @notice Returns the name of the token, e.g. “MyToken”.
    function getName() external view returns (bytes name);

    /// @notice Returns the token symbol, e.g. “GRM”.
    function getSymbol() external view returns (bytes symbol);

    /// @notice Returns the number of decimals the token uses; e.g. 8, means to divide the token amount by 100,000,000 to get its user representation.
    function getDecimals() external view returns (uint8 decimals);

    /// @notice Returns number of tokens owned by a wallet.
    function getBalance() external view returns (uint128 balance);

    /// @notice Returns the wallet WPK.
    function getWalletKey() external view returns (uint256 walletKey);

    /// @notice Returns the wallet internal owner.
    function getWalletOwner() external view returns (address walletOwner);     

    /// @notice Returns address of the root token wallet.  
    function getRootAddress() external view returns (address rootAddress);
     
}

/// @notice TIP3 Fungible Tokens Wallet Interface
interface ITIP3WalletFungible {

    struct AllowanceInfo {
        address spender_;        
        uint128 remainingTokens_;
    }            

    /// @notice Called by an external message only. Sends tokens to another token wallet.
    /// @dev The function must call internalTransfer function of destination wallet. The function must complete successfully if the token balance is less than the transfer value. Zero-value transfers must be treated as normal transfers. Transfer to zero address is not allowed.
    function transfer(address dest, uint128 tokens, uint128 grams) external;    

    /// @notice Called by an internal message only. Receives tokens from other token wallets.
    /// @dev The function must NOT call accept or other buygas primitives. The function must do a verification check that sender is a TTW using senderKey. 
    function internalTransfer(uint256 senderKey, address senderOwner, uint128 tokens) external;      

    /// @notice Called by an internal message only. Receives tokens from the RTW.
    /// @dev The function must check that the message is sent by the RTW.
    function accept(uint128 tokens) external;  

    /// @notice Allows the spender wallet to withdraw tokens from the wallet multiple times, up to the tokens amount. If current spender allowance is equal to remainingTokens, then overwrite it with tokens, otherwise, do nothing.
    function approve(address spender, uint128 remainingTokens, uint128 tokens) external; 

    /// @notice Returns the amount of tokens the spender is still allowed to withdraw from the wallet.
    function allowance() view external returns (AllowanceInfo allowance);

    /// @notice Called by an external message only; allows transferring tokens from the dest wallet to to the wallet.
    /// @dev The function must call the internalTransferFrom function of the dest contract and attach certain grams value to internal message.
    function transferFrom(address dest, address to, uint128 tokens, uint128 grams) external;

    /// @notice Called by an internal message only; transfers the tokens amount from the wallet to the to contract.
    /// @dev Must throw unless the message sender has a permission to withdraw such amount of tokens granted via the approve function. Must decrease the allowed number of tokens by the tokens value and call the internalTransfer function\. The function must throw, if the current allowed amount of tokens is less than tokens. Transfers of 0 values must be treated as normal transfers.
    function internalTransferFrom(address to, uint128 tokens) external;    
}

/// @notice TIP3 Extension: Support for Notifications
interface ITIP3WalletNotify {
   
    /// @notice Called by an internal message only. Receives tokens from other token wallets.
    /// @dev The function must NOT call accept or other buygas primitives. The function must do a verification check that sender is a TTW using senderKey. 
    function internalTransferNotify(uint256 senderKey, address senderOwner, uint128 tokens, address subscriber) external; 

    /// @notice Called by an internal message only; transfers the tokens amount from the wallet to the to contract.
    /// @dev Must throw unless the message sender has a permission to withdraw such amount of tokens granted via the approve function. Must decrease the allowed number of tokens by the tokens value and call the internalTransfer function\. The function must throw, if the current allowed amount of tokens is less than tokens. Transfers of 0 values must be treated as normal transfers.
    function internalTransferFromNotify(address to, uint128 tokens, address subscriber) external;                 

}

/// @notice TIP3 Extension: Burn by Root
interface ITIP3WalletRootBurnable {
    /// @notice Burns tokens (checks that sender is a root)
    function internalBurnFromRoot(uint128 tokens, address subscriber) external;
}

/// @notice TIP3 Extension: Notification Handler
interface ITIP3WalletNotifyHandler {

    /// @notice Notifies about operation
    function onWalletReceive(address _tokenAddress, uint256 _receiverKey, address _receiverOwner, uint256 _senderKey, address _senderOwner, uint128 _tokens) external;
}

/// @notice TIP3 Extension: Notification Handler
interface ITIP3WalletBurnHandler {

    /// @notice Notifies about operation
    function onWalletBurn(address _tokenAddress, uint256 _receiverKey, address _receiverOwner, uint128 _tokens) external;
}
