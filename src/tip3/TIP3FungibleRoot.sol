pragma ton-solidity >= 0.38.2;

/// @title TIP3/Fungible Root Implementation
/// @author laugan

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "../std/lib/TVM.sol";
import "../std/lib/SafeUint.sol";
import "../tip3/lib/TIP3.sol";
import "../tip3/int/ITIP3Root.sol";
import "../tip3/TIP3FungibleWallet.sol";

contract TIP3FungibleRoot is ITIP3RootMetadata, ITIP3RootFungible {
    using SafeUint for uint128;

    /* varInit Attributes */

    uint256 static root_public_key_;
    address static root_owner_address_;    
    bytes static name_ ;
    bytes static symbol_;
    uint8 static decimals_;
    TvmCell static code_;  

    /* Other Attributes */    

    uint128 internal total_supply_;    
    uint128 internal total_granted_;    

    uint64 constant DEPLOY_FEE      = 1.5 ton;
    uint64 constant USAGE_FEE       = 0.1 ton;
    uint64 constant MESSAGE_FEE     = 0.05 ton;   
    uint64 constant CALLBACK_FEE    = 0.01 ton;  
    uint128 constant INITIAL_GAS    = 0.5 ton; 
    address constant ZERO_ADDRESS   = address.makeAddrStd(0, 0);        

    constructor() public {
        require(msg.pubkey() == tvm.pubkey() && root_public_key_ == msg.pubkey(), TIP3.ERROR_MESSAGE_SENDER_IS_NOT_MY_OWNER);
        tvm.accept();
    }

    /* Metadata Functions */

    function getTokenInfo() override external view returns (TokenDetails) {
        return TokenDetails(name_,
                            symbol_,
                            decimals_,
                            code_, 
                            total_supply_,   
                            total_granted_);        
    }    

    function callTokenInfo() override external responsible view responsibleOnlyPay returns (TokenDetails) {
        return{value: 0, flag: TVM.FLAG_VALUE_ADD_INBOUND}(TokenDetails(name_,
                                                                    symbol_,
                                                                    decimals_,
                                                                    code_, 
                                                                    total_supply_,   
                                                                    total_granted_));
    }

    function getWalletAddress(int8 workchainId, uint256 walletPubkey, address walletOwner) override external view returns (address) {
        return _expectedAddress(workchainId, walletPubkey, walletOwner);
    }

    function callWalletAddress(int8 workchainId, uint256 walletPubkey, address walletOwner) override external responsible view responsibleOnlyPay returns (address) {
        return {value: 0, flag: TVM.FLAG_VALUE_ADD_INBOUND}(_expectedAddress(workchainId, walletPubkey, walletOwner));
    }    

    /* Fungible Functions */  

    /// @notice Allows deploying the token wallet in a specified workchain and sending some tokens to it.
    function deployWallet(int8 workchainId, uint256 walletPubkey, address walletOwner, uint128 tokens, uint128 grams) override external onlyOwnerAcceptOrPay returns (address walletAddress) {
        require(tokens >= 0);
        require((walletOwner != ZERO_ADDRESS && walletPubkey == 0) ||
                (walletOwner == ZERO_ADDRESS && walletPubkey != 0),
                TIP3.ERROR_DEFINE_WALLET_PUBLIC_KEY_OR_OWNER_ADDRESS);

        walletAddress = new TIP3FungibleWallet{
            value: grams,
            code: code_,
            pubkey: walletPubkey,
            varInit: {
                root_address_: address(this),   
                wallet_public_key_: walletPubkey,
                wallet_owner_address_: walletOwner,    
                name_: name_,
                symbol_: symbol_,
                decimals_: decimals_,
                code_: code_
            },
            wid: workchainId
        }();

        ITIP3WalletFungible(walletAddress).accept(tokens);
        total_granted_ = total_granted_.add(tokens);
    }

    function deployEmptyWallet(int8 workchainId, uint256 walletPubkey, address walletOwner, uint128 grams) override external responsible returns (address walletAddress, TvmCell walletCode) {
        require((walletOwner != ZERO_ADDRESS && walletPubkey == 0) ||
                (walletOwner == ZERO_ADDRESS && walletPubkey != 0),
                TIP3.ERROR_DEFINE_WALLET_PUBLIC_KEY_OR_OWNER_ADDRESS);
        require(grams >= DEPLOY_FEE && msg.value >= USAGE_FEE + DEPLOY_FEE, TIP3.ERROR_LOW_MESSAGE_VALUE);

        walletAddress = new TIP3FungibleWallet{
            value: grams,
            code: code_,
            pubkey: walletPubkey,
            varInit: {
                root_address_: address(this),   
                wallet_public_key_: walletPubkey,
                wallet_owner_address_: walletOwner,    
                name_: name_,
                symbol_: symbol_,
                decimals_: decimals_,
                code_: code_
            },
            wid: workchainId
        }();

        walletCode = code_;

        return {value: 0, flag: TVM.FLAG_VALUE_ADD_INBOUND}(walletAddress, walletCode);
    }

    /// @notice Called by an external message only; sends tokens to the TTW. The function must call the accept function of the token wallet and increase the totalGranted value.
    function grant(address dest, uint128 tokens, uint128 grams) override external onlyOwnerAcceptOrPay {
        require(total_granted_.add(tokens) <= total_supply_, TIP3.ERROR_NOT_ENOUGH_BALANCE);
        ITIP3WalletFungible(dest).accept{ value: grams, bounce: true }(tokens);
        total_granted_ = total_granted_.add(tokens);
    }

    /// @notice Called by an external message only; emits tokens and increases totalSupply.
    function mint(uint128 tokens) override external onlyOwnerAcceptOrPay {
        total_supply_ = total_supply_.add(tokens);
    }

    /* Private part */

    modifier onlyOwnerAcceptOrPay() {
        require(_isInternalOwner() || _isExternalOwner(), TIP3.ERROR_MESSAGE_SENDER_IS_NOT_MY_OWNER);
        if (msg.sender != ZERO_ADDRESS) {
            require(msg.value >= USAGE_FEE,TIP3.ERROR_LOW_MESSAGE_VALUE);             
            _reserveGas();
        } else {
            tvm.accept();
        }
        _; // BODY
        if (msg.sender != ZERO_ADDRESS) {
            msg.sender.transfer({ value: 0, flag: 128 });  
        } 
    }    

    modifier internalOwnerPay() {
        require(msg.sender != ZERO_ADDRESS && msg.value >= USAGE_FEE,TIP3.ERROR_LOW_MESSAGE_VALUE);   
        _reserveGas();
        _; // BODY
        msg.sender.transfer({ value: 0, flag: TVM.FLAG_ALL_BALANCE });  
    }   

    modifier responsibleOnlyPay() {
        require(msg.sender != ZERO_ADDRESS && msg.value >= USAGE_FEE,TIP3.ERROR_LOW_MESSAGE_VALUE);   
        //_reserveGas();
        _; // BODY
        //msg.sender.transfer({ value: 0, flag: TVM.FLAG_ALL_BALANCE });  
    }           

    function _isInternalOwner() internal inline view returns (bool) {
        return root_owner_address_ != ZERO_ADDRESS && root_owner_address_ == msg.sender && root_public_key_ == 0;
    }

    function _isExternalOwner() internal inline view returns (bool) {
        return root_owner_address_ == ZERO_ADDRESS && root_public_key_ != 0 && root_public_key_ == msg.pubkey() && msg.pubkey() == tvm.pubkey();
    }       

    function _isContract() internal inline pure returns (bool) {
        return msg.sender != ZERO_ADDRESS;
    }            

    function _reserveGas() internal inline returns (bool) {
        tvm.rawReserve(math.max(INITIAL_GAS, address(this).balance - msg.value), 2);
    }        

    function _returnExtraGas() internal inline pure returns (bool) {
        if (_isContract()) {
            msg.sender.transfer({ value: 0, flag: 128 });
        }
    }       

    function _expectedAddress(int8 workchainId, uint256 walletPubkey, address walletOwner) internal inline view returns (address)  {
        TvmCell stateInit = tvm.buildStateInit({
            contr: TIP3FungibleWallet,
            varInit: {
                root_address_: address(this),   
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


}
