pragma ton-solidity >= 0.38.2;

/// @title TIP3/Fungible Wallet Implementation
/// @author laugan

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "../std/lib/TVM.sol";
import "../std/lib/SafeUint.sol";
import "../tip3/lib/TIP3.sol";
import "../tip3/int/ITIP3Wallet.sol";

contract TIP3FungibleWallet is ITIP3WalletMetadata, ITIP3WalletFungible, ITIP3WalletNotify {
    using SafeUint for uint128;

    /* varInit Attributes */

    address static root_address_;    
    uint256 static wallet_public_key_;
    address static wallet_owner_address_;
    bytes static name_ ;
    bytes static symbol_;
    uint8 static decimals_;
    int8 static wid_;
    TvmCell static code_;

    /* Other Attributes */    

    uint128 internal balance_ = 0;     
    AllowanceInfo allowance_;   

    uint64 constant DEPLOY_FEE      = 1.5 ton;
    uint64 constant USAGE_FEE       = 0.1 ton;
    uint64 constant MESSAGE_FEE     = 0.05 ton;   
    uint64 constant CALLBACK_FEE    = 0.01 ton;  
    uint128 constant INITIAL_GAS    = 0.5 ton; 
    address constant ZERO_ADDRESS   = address.makeAddrStd(0, 0);      

    constructor() public {
        tvm.accept();        
    }

    /* Metadata Functions */

    function getName() override external view returns (bytes name) {
        name = name_;
    }

    function getSymbol() override external view returns (bytes symbol) {
        symbol = symbol_;
    }

    function getDecimals() override external view returns (uint8 decimals) {
        decimals = decimals_;
    }

    function getBalance() override external view returns (uint128 balance) {
        balance = balance_;
    }

    function getWalletKey() override external view returns (uint256 walletKey) {
        walletKey = wallet_public_key_;
    }

    function getWalletOwner() override external view returns (address walletOwner) {
        walletOwner = wallet_owner_address_;
    }        
 
    function getRootAddress() override external view returns (address rootAddress) {
        rootAddress = root_address_;
    }        

    /* Fungible Functions */   

    function allowance() override external view returns (AllowanceInfo allowance) {
        //(spender, remainingTokens) = allowance_.unpack(); 
        allowance = allowance_;
    }    

    function accept(uint128 tokens) override external internalMessagePay {
        require(_isRoot(),TIP3.ERROR_MESSAGE_SENDER_IS_NOT_MY_ROOT);
        _receive(tokens);
    }          

    function internalTransfer(uint256 senderKey, address senderOwner, uint128 tokens) override external internalMessagePay {
        require(_isWallet(senderKey, senderOwner),TIP3.ERROR_MESSAGE_SENDER_IS_NOT_GOOD_WALLET);
        _receive(tokens);
    }           

    function internalTransferFrom(address to, uint128 tokens) override external {
        require(msg.sender != ZERO_ADDRESS && msg.value >= USAGE_FEE,TIP3.ERROR_LOW_MESSAGE_VALUE);   
        _spend(tokens);
        ITIP3WalletFungible(to).internalTransfer{ flag: TVM.FLAG_VALUE_ADD_INBOUND, bounce: true }(wallet_public_key_, wallet_owner_address_, tokens); 
    }       

    function transfer(address dest, uint128 tokens, uint128 grams) override external onlyExtOwnerAccept {
        require(balance_ >= tokens, TIP3.ERROR_NOT_ENOUGH_BALANCE);
        require(dest != ZERO_ADDRESS, TIP3.ERROR_MESSAGE_SENDER_IS_NOT_GOOD_WALLET);        
        require(address(this).balance > grams && grams >= USAGE_FEE, TIP3.ERROR_NOT_ENOUGH_GAS);
        balance_ -= tokens;        
        ITIP3WalletFungible(dest).internalTransfer{ value: grams, bounce: true }(wallet_public_key_, wallet_owner_address_, tokens);
    }        

    function transferFrom(address dest, address to, uint128 tokens, uint128 grams) override external onlyExtOwnerAccept {
        require(balance_ >= tokens, TIP3.ERROR_NOT_ENOUGH_BALANCE);
        require(dest != ZERO_ADDRESS, TIP3.ERROR_MESSAGE_SENDER_IS_NOT_GOOD_WALLET);        
        require(address(this).balance > grams && grams >= MESSAGE_FEE + MESSAGE_FEE, TIP3.ERROR_NOT_ENOUGH_GAS);        
        ITIP3WalletFungible(dest).internalTransferFrom{ value: grams, bounce: true }(to, tokens);
    }

    function approve(address spender, uint128 remainingTokens, uint128 tokens) override external onlyOwnerAcceptOrPay {
        if (allowance_.spender_ == spender) {
            require(allowance_.remainingTokens_ == remainingTokens || allowance_.remainingTokens_ == 0, TIP3.ERROR_NO_ALLOWANCE_SET);
        }
        _allow(tokens, spender);
    }   

   /* TIP3 Extension: Support for Notifications */      

    function internalTransferNotify(uint256 senderKey, address senderOwner, uint128 tokens, address subscriber) override external internalMessagePay {
        require(_isWallet(senderKey, senderOwner),TIP3.ERROR_MESSAGE_SENDER_IS_NOT_GOOD_WALLET);
        _receive(tokens);
        if (_hasSubscriber(subscriber)) { 
            ITIP3WalletNotifyHandler(subscriber).onWalletReceive{ flag: TVM.FLAG_VALUE_ADD_INBOUND, bounce: true }(root_address_, wallet_public_key_, wallet_owner_address_, senderKey, senderOwner, tokens);
        }
    }         

    function internalTransferFromNotify(address to, uint128 tokens, address subscriber) override external {
        require(msg.value >= USAGE_FEE,TIP3.ERROR_LOW_MESSAGE_VALUE);   
        _spend(tokens);
        ITIP3WalletNotify(to).internalTransferNotify{ flag: TVM.FLAG_VALUE_ADD_INBOUND, bounce: true }(wallet_public_key_, wallet_owner_address_, tokens, subscriber);       
    }      

    onBounce(TvmSlice body) external {
        tvm.accept();
        uint32 functionId = body.decode(uint32);
        if (functionId == tvm.functionId(ITIP3WalletFungible.internalTransfer)) {
            _receive(body.decode(uint128));
            if (wallet_owner_address_.value != 0) {
                _reserveGas();
                wallet_owner_address_.transfer({ value: 0, flag: 128 });
            }   
        } else if (functionId == tvm.functionId(ITIP3WalletNotify.internalTransferNotify)) {
            _receive(body.decode(uint128));
            if (wallet_owner_address_.value != 0) {
                _reserveGas();
                wallet_owner_address_.transfer({ value: 0, flag: 128 });
            }   
        }
    }       

    /* Private part */

    modifier internalOnlyPay() {
        require(msg.sender != ZERO_ADDRESS && msg.value >= USAGE_FEE,TIP3.ERROR_LOW_MESSAGE_VALUE);   
        _reserveGas();
        _; // BODY
        //msg.sender.transfer({ value: 0, flag: TVM.FLAG_ALL_BALANCE });  
    }

    modifier internalMessagePay() {
        require(msg.sender != ZERO_ADDRESS && msg.value >= MESSAGE_FEE,TIP3.ERROR_LOW_MESSAGE_VALUE);   
        _; // BODY
    }    

    modifier onlyOwnerAcceptOrPay() {
        require(_isInternalOwner() || _isExternalOwner(), TIP3.ERROR_MESSAGE_SENDER_IS_NOT_MY_OWNER);
        if (msg.sender != ZERO_ADDRESS) {
            require(msg.value >= USAGE_FEE,TIP3.ERROR_LOW_MESSAGE_VALUE);             
            _reserveGas();
        } else {
            tvm.accept();
        }
        _; // BODY
        //if (msg.sender != ZERO_ADDRESS) {
        //    msg.sender.transfer({ value: 0, flag: TVM.FLAG_ALL_BALANCE });  
        //} 
    }

    modifier onlyExtOwnerAccept() {
        require(_isExternalOwner(), TIP3.ERROR_MESSAGE_SENDER_IS_NOT_MY_OWNER);
        tvm.accept();        
        _; // BODY
    }    

    function _isRoot() internal inline view returns (bool) {
        return root_address_ == msg.sender;
    }

    function _isContract() internal inline pure returns (bool) {
        return msg.sender != ZERO_ADDRESS;
    }    

    function _isWallet(uint256 walletPubkey, address walletOwner) internal inline view returns (bool) {
        return msg.sender.value == _expectedAddress(walletPubkey, walletOwner).value;
    }        

    function _isInternalOwner() internal inline view returns (bool) {
        return wallet_owner_address_ != ZERO_ADDRESS && wallet_owner_address_ == msg.sender && wallet_public_key_ == 0;
    }

    function _isExternalOwner() internal inline view returns (bool) {
        return wallet_owner_address_ == ZERO_ADDRESS && wallet_public_key_ != 0 && wallet_public_key_ == msg.pubkey() && msg.pubkey() == tvm.pubkey();
    }       

    function _isSpender() internal inline view returns (bool) {
        return msg.sender == allowance_.spender_ && allowance_.spender_ != ZERO_ADDRESS;
    }     

    function _isAllowed(uint128 tokens) internal inline view returns (bool) {
        return tokens <= allowance_.remainingTokens_;
    }      

    function _hasSubscriber(address subscriber) internal inline pure returns (bool) {
        return subscriber != ZERO_ADDRESS;
    }        

    function _reserveGas() internal inline returns (bool) {
        tvm.rawReserve(math.max(INITIAL_GAS, address(this).balance - msg.value), 2);
    }        

    function _returnExtraGas() internal inline pure returns (bool) {
        if (_isContract()) {
            msg.sender.transfer({ value: 0, flag: TVM.FLAG_ALL_BALANCE });
        }
    }   

    function _expectedAddress(uint256 walletPubkey, address walletOwner) internal inline view returns (address)  {
        TvmCell stateInit = tvm.buildStateInit({
            contr: TIP3FungibleWallet,
            varInit: {
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
        return address.makeAddrStd(wid_, tvm.hash(stateInit));
    }         

    function _allow(uint128 tokens, address spender) virtual internal inline {
        allowance_ = AllowanceInfo(spender, tokens);
    }   

    function _receive(uint128 tokens) virtual internal inline {
        balance_ += tokens;    
    }     

    function _spend(uint128 tokens) internal inline {
        if (!_isInternalOwner()) {
            require(_isSpender(),TIP3.ERROR_WRONG_SPENDER);
            require(_isAllowed(tokens),TIP3.ERROR_NOT_ENOUGH_ALLOWANCE);                      
        }
        require(balance_ >= tokens,TIP3.ERROR_NOT_ENOUGH_BALANCE);
        balance_ -= tokens;    
        
        allowance_ = AllowanceInfo(allowance_.spender_, allowance_.remainingTokens_ - tokens);
    }     

}
