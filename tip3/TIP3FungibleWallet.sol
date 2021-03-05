pragma ton-solidity >= 0.36.0;

pragma AbiHeader expire;

import "ITIP3Wallet.sol";
import "ITIP3WalletHandler.sol";
import "TIP3Types.sol";
import "SafeUint.sol";

contract TIP3FungibleWallet is TIP3Types, ITIP3WalletMetadata, ITIP3WalletFungible {
    using SafeUint for uint128;

    /* varInit Attributes */

    uint256 static root_public_key_;
    address static root_address_;    
    uint256 static wallet_public_key_;
    address static wallet_owner_address_;    
    bytes static name_ ;
    bytes static symbol_;
    uint8 static decimals_;
    TvmCell static code_;  

    /* Other Attributes */    

    uint128 internal balance_ = 0;     
    optional(AllowanceInfo) allowance_; 
    uint128 internal initial_gas_ = 0.1 ton;   

    constructor(address subscriber, TvmCell payload) public {
    tvm.accept();
    if (!(root_address_.value != 0 && root_public_key_ != 0)) { 
        if (_hasSubscriber(subscriber)) {             
            ITIP3WalletFungibleHandler(subscriber).onDeploy{value: CALLBACK_FEE}(ERROR_DEFINE_WALLET_PUBLIC_KEY_OR_OWNER_ADDRESS,
                                                                                wallet_public_key_,   
                                                                                wallet_owner_address_,               
                                                                                payload,
                                                                                msg.pubkey(),
                                                                                msg.sender                                                                              
                                                                                ); 
        }
        revert(ERROR_DEFINE_WALLET_PUBLIC_KEY_OR_OWNER_ADDRESS);
    }    
    if (!(
         (wallet_public_key_ != 0 && wallet_owner_address_.value == 0 && msg.pubkey() == tvm.pubkey() && tvm.pubkey() == wallet_public_key_) || 
         (wallet_public_key_ == 0 &&  wallet_owner_address_.value != 0 && msg.sender == wallet_owner_address_)
        )) { 
        if (_hasSubscriber(subscriber)) {             
            ITIP3WalletFungibleHandler(subscriber).onDeploy{value: CALLBACK_FEE}(ERROR_DEFINE_WALLET_OWNERS,
                                                                                wallet_public_key_,   
                                                                                wallet_owner_address_,               
                                                                                payload,
                                                                                msg.pubkey(),
                                                                                msg.sender                                                                              
                                                                                ); 
        }
        revert(ERROR_DEFINE_WALLET_OWNERS);
    }    
    if (_hasSubscriber(subscriber)) {             
        ITIP3WalletFungibleHandler(subscriber).onDeploy{value: CALLBACK_FEE}(0,
                                                                                wallet_public_key_,   
                                                                                wallet_owner_address_,               
                                                                                payload,
                                                                                msg.pubkey(),
                                                                                msg.sender                                                                              
                                                                                ); 
    }      
  }

    /* Metadata Functions */

    /// @notice Returns the name of the token, e.g. “MyToken”.
    function getName() override external view returns (bytes name) {
        name = name_;
    }

    /// @notice Returns the token symbol, e.g. “GRM”.
    function getSymbol() override external view returns (bytes symbol) {
        symbol = symbol_;
    }

    /// @notice Returns the number of decimals the token uses; e.g. 8, means to divide the token amount by 100,000,000 to get its user representation.
    function getDecimals() override external view returns (uint8 decimals) {
        decimals = decimals_;
    }

    /// @notice Returns number of tokens owned by a wallet.
    function getBalance() override external view returns (uint128 balance) {
        balance = balance_;
    }

    /// @notice Returns the wallet WPK.
    function getWalletKey() override external view returns (uint256 walletKey) {
        walletKey = wallet_public_key_;
    }

    /// @notice Returns the wallet internal owner.
    function getWalletOwner() override external view returns (address walletOwner) {
        walletOwner = wallet_owner_address_;
    }        

    /// @notice Returns address of the root token wallet.  
    function getRootPubkey() override external view returns (uint256 rootKey) {
        rootKey = root_public_key_;
    }    

    /// @notice Returns address of the root token wallet.  
    function getRootAddress() override external view returns (address rootAddress) {
        rootAddress = root_address_;
    }        

    /* Fungible Functions */   

    /// @notice Returns the amount of tokens the spender is still allowed to withdraw from the wallet.
    function allowance() override external view returns (address spender, uint256 remainingTokens) {
        if (allowance_.hasValue()) {
            spender = allowance_.get().spender_;
            remainingTokens = allowance_.get().remainingTokens_;
        } else {
            spender = address.makeAddrStd(0, 0);
            remainingTokens = 0; 
        }
    }    

    /// @notice Called by an internal message only. Receives tokens from the RTW.
    /// @dev The function must check that the message is sent by the RTW.
    function accept(uint128 tokens, address subscriber, TvmCell payload) override external paidInternalReturnExtra {
        if (!_isRoot()) { 
            if (_hasSubscriber(subscriber)) { _callback_receive(ERROR_MESSAGE_SENDER_IS_NOT_MY_ROOT, tokens, msg.sender, subscriber, payload); }
            revert(ERROR_MESSAGE_SENDER_IS_NOT_MY_ROOT);
        } 
        _receive(tokens);
        if (_hasSubscriber(subscriber)) { _callback_receive(0, tokens, msg.sender, subscriber, payload); }
    }          

    /// @notice Called by an internal message only. Receives tokens from other token wallets.
    /// @dev The function must NOT call accept or other buygas primitives. The function must do a verification check that sender is a TTW using senderKey. 
    function internalTransfer(uint256 senderKey, address senderOwner, uint128 tokens, address subscriber, TvmCell payload) override external paidInternalReturnExtra {
        if (!_isWallet(senderKey, senderOwner)) { 
            if (_hasSubscriber(subscriber)) { _callback_receive(ERROR_MESSAGE_SENDER_IS_NOT_GOOD_WALLET, tokens, msg.sender, subscriber, payload); }
            revert(ERROR_MESSAGE_SENDER_IS_NOT_GOOD_WALLET);
        }
        _receive(tokens);
        if (_hasSubscriber(subscriber)) { _callback_receive(0, tokens, msg.sender, subscriber, payload); }
    }       

    /// @notice Called by an internal message only; transfers the tokens amount from the wallet to the to contract.
    /// @dev Must throw unless the message sender has a permission to withdraw such amount of tokens granted via the approve function. Must decrease the allowed number of tokens by the tokens value and call the internalTransfer function\. The function must throw, if the current allowed amount of tokens is less than tokens. Transfers of 0 values must be treated as normal transfers.
    function internalTransferFrom(address to, uint128 tokens, address subscriber, TvmCell payload) override external paidInternalReturnExtra {
        if (!_isInternalOwner()) {
            if (!allowance_.hasValue()) { 
                if (_hasSubscriber(subscriber)) { _callback_send(ERROR_NO_ALLOWANCE_SET, tokens, to, subscriber, payload); }
                revert(ERROR_NO_ALLOWANCE_SET);
            }
            if (!_isSpender()) { 
                if (_hasSubscriber(subscriber)) { _callback_send(ERROR_WRONG_SPENDER, tokens, to, subscriber, payload); }
                revert(ERROR_WRONG_SPENDER);
            }
            if (!_isAllowed(tokens)) { 
                if (_hasSubscriber(subscriber)) { _callback_send(ERROR_NOT_ENOUGH_ALLOWANCE, tokens, to, subscriber, payload); }
                revert(ERROR_NOT_ENOUGH_ALLOWANCE);
            }                        
        }

        if (balance_ < tokens) { 
            if (_hasSubscriber(subscriber)) { _callback_send(ERROR_NOT_ENOUGH_BALANCE, tokens, to, subscriber, payload); }
            revert(ERROR_NOT_ENOUGH_BALANCE);
        }

        _send(tokens);
        allowance_.set(AllowanceInfo(allowance_.get().spender_, allowance_.get().remainingTokens_ - tokens));
        ITIP3WalletFungible(to).internalTransfer{ value: MESSAGE_FEE, bounce: true }(wallet_public_key_, wallet_owner_address_, tokens, subscriber, payload);

        if (_hasSubscriber(subscriber)) { _callback_send(0, tokens, to, subscriber, payload); }
    }   

    /// @notice Called by an external message only. Sends tokens to another token wallet.
    /// @dev The function must call internalTransfer function of destination wallet. The function must complete successfully if the token balance is less than the transfer value. Zero-value transfers must be treated as normal transfers. Transfer to zero address is not allowed.
    function transfer(address dest, uint128 tokens, uint128 grams) override external onlyExternalOwner {
        require(balance_ >= tokens, ERROR_NOT_ENOUGH_BALANCE);
        require(dest.value != 0, ERROR_MESSAGE_SENDER_IS_NOT_GOOD_WALLET);        
        require(address(this).balance > grams && grams >= USAGE_FEE, ERROR_NOT_ENOUGH_GAS);
        tvm.accept();
        _send(tokens);
        TvmBuilder builder;
        ITIP3WalletFungible(dest).internalTransfer{ value: grams, bounce: true }(wallet_public_key_, wallet_owner_address_, tokens, address(0), builder.toCell());
    }        

    /// @notice Called by an external message only; allows transferring tokens from the dest wallet to to the wallet.
    /// @dev The function must call the internalTransferFrom function of the dest contract and attach certain grams value to internal message.
    function transferFrom(address dest, address to, uint128 tokens, uint128 grams) override external onlyExternalOwner {
        require(balance_ >= tokens, ERROR_NOT_ENOUGH_BALANCE);
        require(dest.value != 0, ERROR_MESSAGE_SENDER_IS_NOT_GOOD_WALLET);        
        require(address(this).balance > grams && grams >= USAGE_FEE, ERROR_NOT_ENOUGH_GAS);        
        tvm.accept();
        TvmBuilder builder;
        ITIP3WalletFungible(dest).internalTransferFrom{ value: grams, bounce: true }(to, tokens, address(0), builder.toCell());
    }

    /// @notice Allows the spender wallet to withdraw tokens from the wallet multiple times, up to the tokens amount. If current spender allowance is equal to remainingTokens, then overwrite it with tokens, otherwise, do nothing.
    function approve(address spender, uint128 remainingTokens, uint128 tokens, address subscriber, TvmCell payload) override external onlyOwner {
        if (_isInternalOwner()) {
            require(msg.sender.value != 0 && msg.value >= USAGE_FEE,ERROR_LOW_MESSAGE_VALUE);             
            _reserveGas();
        } else {
            tvm.accept();
        }
        
        if (allowance_.hasValue()) {
            if (allowance_.get().remainingTokens_ != remainingTokens) { 
                if (_hasSubscriber(subscriber)) { _callback_allow(ERROR_NO_ALLOWANCE_SET, tokens, spender, subscriber, payload); }
                revert(ERROR_NO_ALLOWANCE_SET);
            }
        } else {
            if (remainingTokens != 0) { 
                if (_hasSubscriber(subscriber)) { _callback_allow(ERROR_NON_ZERO_REMAINING, tokens, spender, subscriber, payload); }
                revert(ERROR_NON_ZERO_REMAINING);
            }            
        }
        if (_hasSubscriber(subscriber)) { _callback_allow(0, tokens, spender, subscriber, payload); }
        _allow(tokens, spender);

        _returnExtraGas();
    }   

    /* Private part */
    modifier paidInternalReturnExtra() {
        // we'll not callback this REQUIRE to defend our gas
        // also, existing value defends us against external calls
        require(msg.sender.value != 0 && msg.value >= USAGE_FEE,ERROR_LOW_MESSAGE_VALUE);   
        // we're reserving everything aside from message value, but no less than initial_gas value 
        _reserveGas();

        _;

        // returning extra gas
        msg.sender.transfer({ value: 0, flag: 128 });  
    }

    modifier onlyOwner() {
        require(_isInternalOwner() || _isExternalOwner(), ERROR_MESSAGE_SENDER_IS_NOT_MY_OWNER);
        _;
    }

    modifier onlyExternalOwner() {
        require(_isExternalOwner(), ERROR_MESSAGE_SENDER_IS_NOT_MY_OWNER);
        _;
    }    

    function _isRoot() internal inline view returns (bool) {
        return root_address_ == msg.sender;
    }

    function _isContract() internal inline pure returns (bool) {
        return msg.sender.value != 0;
    }    

    function _isWallet(uint256 walletPubkey, address walletOwner) internal inline view returns (bool) {
        return msg.sender == _expectedAddress(walletPubkey, walletOwner);
    }        

    function _isInternalOwner() internal inline view returns (bool) {
        return wallet_owner_address_.value != 0 && wallet_owner_address_ == msg.sender && wallet_public_key_ == 0;
    }

    function _isExternalOwner() internal inline view returns (bool) {
        return wallet_owner_address_.value == 0 && wallet_public_key_ != 0 && wallet_public_key_ == msg.pubkey() && msg.pubkey() == tvm.pubkey();
    }       

    function _isSpender() internal inline view returns (bool) {
        return msg.sender == allowance_.get().spender_;
    }     

    function _isAllowed(uint128 tokens) internal inline view returns (bool) {
        return tokens <= allowance_.get().remainingTokens_;
    }      

    function _hasSubscriber(address subscriber) internal inline pure returns (bool) {
        return subscriber.value != 0;
    }        

    function _reserveGas() internal inline view returns (bool) {
        tvm.rawReserve(math.max(initial_gas_, address(this).balance - msg.value), 2);
    }        

    function _returnExtraGas() internal inline pure returns (bool) {
        if (_isContract()) {
            msg.sender.transfer({ value: 0, flag: 128 });
        }
    }   

    function _expectedAddress(uint256 walletPubkey, address walletOwner) private view returns (address)  {

        TvmCell stateInit = tvm.buildStateInit({
            contr: TIP3FungibleWallet,
            varInit: {
                root_public_key_: root_public_key_,
                root_address_: root_address_,   
                wallet_public_key_: walletPubkey,
                wallet_owner_address_: walletOwner,    
                name_: name_,
                symbol_: symbol_,
                decimals_: decimals_,
                code_: code_
            },
            pubkey: walletPubkey,
            code: code_
        });

        return address(tvm.hash(stateInit));
    }         

    function _allow(uint128 tokens, address spender) private inline {
        allowance_.set(AllowanceInfo(spender, tokens));
    }   

    function _send(uint128 tokens) private inline {
        balance_.sub(tokens);
    }   

    function _receive(uint128 tokens) private inline {
        balance_.add(tokens);
    }     

    function _callback_allow(uint16 status, uint128 tokens, address spender, address subscriber, TvmCell payload) inline internal view {
        ITIP3WalletFungibleHandler(subscriber).onSpendApproved{value: CALLBACK_FEE}(
                                                                                status,                
                                                                                wallet_public_key_,   
                                                                                wallet_owner_address_, 
                                                                                tokens,                                                                                              
                                                                                payload,
                                                                                msg.pubkey(),
                                                                                msg.sender,
                                                                                spender                                                                                
                                                                                );     
    }       

    function _callback_send(uint16 status, uint128 tokens, address to, address subscriber, TvmCell payload) inline internal view {
            ITIP3WalletFungibleHandler(subscriber).onTokensSent{value: CALLBACK_FEE}(
                                                                                status,                
                                                                                wallet_public_key_,   
                                                                                wallet_owner_address_, 
                                                                                tokens,                                                                                              
                                                                                payload,
                                                                                msg.pubkey(),
                                                                                msg.sender,
                                                                                to                                                                                
                                                                                ); 
    }       

    function _callback_receive(uint16 status, uint128 tokens, address from, address subscriber, TvmCell payload) inline internal view {
            ITIP3WalletFungibleHandler(subscriber).onTokensReceived{value: CALLBACK_FEE}(
                                                                                status,                
                                                                                wallet_public_key_,   
                                                                                wallet_owner_address_,    
                                                                                tokens,                                                                                           
                                                                                payload,
                                                                                msg.pubkey(),
                                                                                msg.sender,
                                                                                from                                                                                
                                                                                ); 
    }          

}
