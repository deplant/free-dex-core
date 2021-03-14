pragma ton-solidity >= 0.38.2;

/// @title LiquiSOR\DEXPool
/// @author laugan
/// @notice Contract for providing liquidity and trading. In the same time it's a root contract for TIP-3 Liquidity token

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "../std/lib/TVM.sol";
import "../tip3/int/ITIP3Root.sol";
import "../tip3/int/ITIP3Wallet.sol";
import "../dex/int/IDEXPool.sol";
import "../dex/lib/DEX.sol";
import "../dex/TIP3LiquidityWallet.sol";

contract DEXPool is IDEXPool, ITIP3RootMetadata, ITIP3WalletNotifyHandler, ITIP3WalletBurnHandler {

    /*
     * Attributes
     */
   
    // Static 
    address static dex_; //  our owner
    bytes static name_;
    bytes static symbol_;
    TvmCell static code_;    
    address static tokenX_;
    address static tokenY_;

    uint8 constant decimals_ = 12;
    uint128 constant fee_ = 300; // real order gets virtual fee, not this one

    uint64 constant DEX_VALUE_FEE   = 0.005 ton;
    uint64 constant DEPLOY_FEE      = 1.5 ton;
    uint64 constant USAGE_FEE       = 0.2 ton;
    uint64 constant MESSAGE_FEE     = 0.05 ton;   
    uint64 constant CALLBACK_FEE    = 0.01 ton;  
    uint128 constant INITIAL_GAS    = 0.5 ton; 
    address constant ZERO_ADDRESS   = address.makeAddrStd(0, 0); 

    uint64 constant INIT_FEE = 3 ton; //USAGE_FEE + 3 * DEPLOY_FEE + 2 * MESSAGE_FEE + 2 * CALLBACK_FEE;
    uint64 constant CUSTOMER_FEE = 0.8 ton; //USAGE_FEE + 3 * MESSAGE_FEE + 2 * CALLBACK_FEE;

    uint128 constant MIN_TOKEN_AMOUNT = 1000; 
    uint16 constant ERROR_ADDITION_OVERFLOW         = 300;
    uint16 constant ERROR_SUBTRACTION_OVERFLOW      = 301;
    uint16 constant ERROR_MULTIPLY_OVERFLOW         = 302;   
    
    Token detailsX_;
    Token detailsY_;
    uint128 total_supply_;  

    mapping(uint256 => Transaction) transactions_;

    /// @dev Contract constructor.
    constructor(ITIP3RootMetadata.TokenDetails valueX, ITIP3RootMetadata.TokenDetails valueY) public {
        detailsX_.root = tokenX_;
        detailsY_.root = tokenY_;
        detailsX_.code = valueX.code;
        detailsY_.code = valueY.code;
        detailsX_.name = valueX.name;
        detailsY_.name = valueY.name;
        detailsX_.symbol = valueX.symbol;
        detailsY_.symbol = valueY.symbol;  
        detailsX_.decimals = valueX.decimals;
        detailsY_.decimals = valueY.decimals;     
        _deployWallets();             
                 
     }

    /* ---------------------------------------------------------------------------------- */ 
    /* TIP3 Metadata Functions */

    function getTokenInfo() override external view returns (TokenDetails) {
        return  ITIP3RootMetadata.TokenDetails(name_,
                            symbol_,
                            decimals_,
                            code_, 
                            total_supply_,   
                            total_supply_);        
    }    

    function callTokenInfo() override external responsible view returns (TokenDetails) {
        return {value: 0, flag: TVM.FLAG_VALUE_ADD_INBOUND }ITIP3RootMetadata.TokenDetails(name_,
                                                                                            symbol_,
                                                                                            decimals_,
                                                                                            code_, 
                                                                                            total_supply_,   
                                                                                            total_supply_);
    }          

    /// @notice Calculates wallet address with defined public key (getter)
    function getWalletAddress(int8 workchainId, uint256 walletPubkey, address walletOwner) override external view returns (address) {
        return _expectedAddress(address(this), walletPubkey, walletOwner);
    }

    /// @notice Calculates wallet address with defined public key (responsible)
    function callWalletAddress(int8 workchainId, uint256 walletPubkey, address walletOwner) override external responsible view returns (address)  {
        return {value: 0, flag: TVM.FLAG_VALUE_ADD_INBOUND}(_expectedAddress(address(this), walletPubkey, walletOwner));
    }

    /* ---------------------------------------------------------------------------------- */ 
    /* TIP3 Fungible Functions  */    

    function deployEmptyWallet(int8 workchainId, uint256 walletPubkey, address walletOwner, uint128 grams) external returns (address walletAddress, TvmCell walletCode) {
        tvm.accept();
        walletAddress = new TIP3LiquidityWallet{
            value: grams,
            pubkey: walletPubkey,
            varInit: {
                //root_public_key_: 0,
                root_address_: address(this),   
                wallet_public_key_: walletPubkey,
                wallet_owner_address_: walletOwner,    
                name_: name_,
                symbol_: symbol_,
                decimals_: decimals_,
                code_: code_
            },
            wid: workchainId,
            code: code_            
        }();
        walletCode = code_;
    }      

    /* ---------------------------------------------------------------------------------- */ 
    /* Pool Getters */  

    function getPoolDetails() external override view returns (PoolDetails details) {
        details = PoolDetails(
                            detailsX_.root, 
                            detailsX_.wallet,
                            detailsX_.balance, 
                            detailsY_.root,         
                            detailsY_.wallet, 
                            detailsY_.balance,
                            fee_,
                            total_supply_
                            );       
    }     

    function getSwapDetails(address _tokenAddress, uint128 _tokens) external override view returns (OrderDetails) {
        (Token inToken, Token outToken, ) = _processToken(_tokenAddress); // does checks and fills variables with token details

        (uint128 spotPrice, uint128 effectivePrice) = 
            (inToken.balance == 0 || outToken.balance == 0) ?
                (0,0) :
                (
                    _spotAmount(_tokens,inToken.balance, outToken.balance),
                    _effectiveAmount(_tokens, inToken.balance, outToken.balance, fee_)
                );

        return OrderDetails(spotPrice, effectivePrice);
    }     

    function getDepositDetails(address _tokenAddress, uint128 _tokens) external override view returns (OrderDetails) {
        (Token inToken, Token outToken, ) = _processToken(_tokenAddress); // does checks and fills variables with token details

        (uint128 secondAmount, uint128 liqAmount) = 
            (inToken.balance == 0 || outToken.balance == 0) ?
                (0,0) :
                (
                    _spotAmount(_tokens,inToken.balance, outToken.balance),
                    _tokensToLiq(
                                    _tokens, 
                                    _spotAmount(_tokens,inToken.balance, outToken.balance)
                                )
                );

        return OrderDetails(secondAmount, liqAmount);     
    }         

    function getWithdrawDetails(uint128 _tokens) external override view returns (OrderDetails) {

        (uint128 amountX, uint128 amountY) = 
            (detailsX_.balance == 0 || detailsY_.balance == 0) ?
                (0,0) :
                _liqToTokens(_tokens,total_supply_, detailsX_.balance, detailsY_.balance);        

        return OrderDetails(amountX, amountY);            
    }    

    /* ---------------------------------------------------------------------------------- */ 
    /* Pool Operations */  

    function swap(address _tokenAddress, uint256 _senderKey, address _senderOwner, uint128 _tokens, uint128 _minReturn) external override forCustomers {
        _expireTransactions();            
        uint256 owner = _processCustomer(_senderKey, _senderOwner); // sets owner from pubkey and address
        require(!_hasTransaction(owner), DEX.ERROR_ALREADY_IN_TRANSACTION);
        (Token inToken, Token outToken, bool xy) = _processToken(_tokenAddress); // does checks and fills variables with token details            

        uint128 outAmount = _effectiveAmount(_tokens,inToken.balance, outToken.balance, fee_);

        require(outAmount >= _minReturn, DEX.ERROR_MIN_RETURN_NOT_ACHIEVED);
        require(outToken.balance >= MIN_TOKEN_AMOUNT + _minReturn, DEX.ERROR_NOT_ENOUGH_LIQUIDITY);

        address from = _expectedAddress(inToken.root, _senderKey, _senderOwner);   

        Transaction tr = Transaction(
                                now, 
                                _senderKey, 
                                _senderOwner, 
                                Operation.SWAP, 
                                xy,  
                                0,
                                _tokens, 
                                0, 
                                0, 
                                _minReturn
        );

        transactions_.add(owner, tr);        
        ITIP3WalletNotify(from).internalTransferFromNotify{value: CUSTOMER_FEE, bounce: true}(inToken.wallet, _tokens, address(this));
    }

  function deposit(address _tokenAddress, uint256 _senderKey, address _senderOwner, uint128 _tokens, uint128 _maxSpend) external override forCustomers {
        _expireTransactions(); 
        uint256 owner = _processCustomer(_senderKey, _senderOwner); // sets owner from pubkey and address
        require(!_hasTransaction(owner), DEX.ERROR_ALREADY_IN_TRANSACTION);
        (Token inToken, Token outToken, bool xy) = _processToken(_tokenAddress); // does checks and fills variables with token details   

        // if it is first deposit, maxSpend is your desired amount of second token
        uint128 outAmount = (inToken.balance == 0 || outToken.balance == 0) ? _maxSpend : _spotAmount(_tokens,inToken.balance, outToken.balance); 
        require(outAmount <= _maxSpend, DEX.ERROR_MAX_GRAB_NOT_ACHIEVED);     
        require(outAmount >= MIN_TOKEN_AMOUNT && _tokens >= MIN_TOKEN_AMOUNT, DEX.ERROR_NOT_ENOUGH_LIQUIDITY);          

        address fromIn = _expectedAddress(inToken.root, _senderKey, _senderOwner); 
        Transaction tr = Transaction(
                                now, 
                                _senderKey, 
                                _senderOwner, 
                                Operation.DEPOSIT,
                                xy,  
                                0,   
                                _tokens, 
                                outAmount, 
                                0, 
                                _maxSpend  
        );
        transactions_.add(owner, tr);          
        ITIP3WalletNotify(fromIn).internalTransferFromNotify{value: CUSTOMER_FEE, bounce: true}(inToken.wallet, _tokens, address(this));  
    }
 
    function withdraw(uint256 _senderKey, address _senderOwner, uint128 _tokens) external override forCustomers {
        _expireTransactions(); 
        uint256 owner = _processCustomer(_senderKey, _senderOwner); // sets owner from pubkey and address

        require(!_hasTransaction(owner), DEX.ERROR_ALREADY_IN_TRANSACTION);
        require(detailsX_.balance > 0 && detailsY_.balance > 0, DEX.ERROR_NOT_ENOUGH_LIQUIDITY); 
        require(_tokens >= _minWithdrawLiq(total_supply_, detailsX_.balance, detailsY_.balance), DEX.ERROR_NOT_ENOUGH_LIQUIDITY); 

        // init transaction
        Transaction tr = Transaction(
                                now, 
                                _senderKey, 
                                _senderOwner, 
                                Operation.WITHDRAW, 
                                true,         
                                0, 
                                0, 
                                0, 
                                _tokens, 
                                0
        );

        transactions_.add(owner, tr);            
        address from = _expectedAddress(address(this), _senderKey, _senderOwner);
        ITIP3WalletRootBurnable(from).internalBurnFromRoot{value: CUSTOMER_FEE, bounce: true}(_tokens, address(this));        
    }     

    /* ---------------------------------------------------------------------------------- */ 
    /* Callbacks from TIP-3 */ 

   function _deployWallets() internal view {
        ITIP3RootFungible(tokenX_).deployEmptyWallet{ callback: DEXPool.onWalletDeploy, value: DEPLOY_FEE + USAGE_FEE + MESSAGE_FEE }(0, 0, address(this), DEPLOY_FEE);
        ITIP3RootFungible(tokenY_).deployEmptyWallet{ callback: DEXPool.onWalletDeploy, value: DEPLOY_FEE + USAGE_FEE + MESSAGE_FEE }(0, 0, address(this), DEPLOY_FEE);
   }   

   // callback from TIP-3 token root
   function onWalletDeploy(address walletAddress, TvmCell code) public forCallbacks {
        if ( msg.sender == tokenX_ && detailsX_.wallet == ZERO_ADDRESS) 
        {
            detailsX_.wallet = walletAddress;
            //detailsX_.code = code;
        } 
        else if (msg.sender == tokenY_ && detailsY_.wallet == ZERO_ADDRESS) 
        {
            detailsY_.wallet = walletAddress;
            //detailsY_.code = code;
        }
   }       

    ///@notice Callback from LiquidityWallet
    function onWalletBurn(address _tokenAddress, uint256 _senderKey, address _senderOwner, uint128 _tokens) public override forCallbacks {
        require(_tokenAddress == address(this),DEX.ERROR_UNKNOWN_TOKEN);
        address senderAddr = _expectedAddress(_tokenAddress, _senderKey, _senderOwner);
        require(msg.sender == senderAddr, DEX.ERROR_NOT_AUTHORIZED);        
        uint256 owner = _processCustomer(_senderKey, _senderOwner); // sets owner from pubkey and address

        Transaction tr = _processTransaction(owner);
        if (tr.operation == Operation.WITHDRAW && tr.stage == 0) {
            if (tr.amountLiq == _tokens) {
                tr.amountIn = math.muldiv(_tokens, detailsX_.balance, total_supply_);
                tr.amountOut = _spotAmount(tr.amountIn, detailsX_.balance, detailsY_.balance);
                ITIP3WalletFungible(detailsX_.wallet).internalTransferFrom{value: USAGE_FEE, bounce: true}(senderAddr, tr.amountIn);
                ITIP3WalletFungible(detailsY_.wallet).internalTransferFrom{value: USAGE_FEE, bounce: true}(senderAddr, tr.amountOut);
                _savepoint(owner, tr);
                _commit(owner); // pre-last command of whole transaction
            } else {
                _rollback(owner);
            }
        }
    }      

    ///@notice Callback from TIP-3 internalTransferNotify() function
    function onWalletReceive(address _tokenAddress, uint256 _receiverKey, address _receiverOwner, uint256 _senderKey, address _senderOwner, uint128 _tokens) public override forCallbacks {
        (Token inToken, Token outToken, bool xy) = _processToken(_tokenAddress); // does checks and fills variables with token details   
        require(msg.sender == inToken.wallet, DEX.ERROR_NOT_AUTHORIZED);
        uint256 owner = _processCustomer(_senderKey, _senderOwner); // sets owner from pubkey and address
        Transaction tr = _processTransaction(owner);

       if (tr.operation == Operation.SWAP && tr.stage == 0 && tr.amountIn == _tokens) {
                tr.amountOut = _effectiveAmount(_tokens,inToken.balance, outToken.balance, fee_);  
                if (tr.amountOut >= tr.limit) {
                    address to = _expectedAddress(outToken.root, _senderKey, _senderOwner);
                    _savepoint(owner, tr);
                    _commit(owner); // finish transaction
                    ITIP3WalletFungible(outToken.wallet).internalTransferFrom{value: TVM.FLAG_VALUE_ADD_INBOUND, bounce: true}(to, tr.amountOut);                    
                } else {
                    _rollback(owner);
                }
        }      
        else if (tr.operation == Operation.DEPOSIT && tr.stage == 0 &&tr.amountIn == _tokens)
        {
            tr.stage = 1;
            tr.amountOut = (inToken.balance == 0 || outToken.balance == 0) ? tr.limit : _spotAmount(_tokens, inToken.balance, outToken.balance);             
            _savepoint(owner, tr);
            address fromOut = _expectedAddress(outToken.root, _senderKey, _senderOwner);             
            ITIP3WalletNotify(fromOut).internalTransferFromNotify{flag: TVM.FLAG_VALUE_ADD_INBOUND, bounce: true}(outToken.wallet, tr.amountOut, address(this));              
        } 
        else if (tr.operation == Operation.DEPOSIT && tr.stage == 1 &&tr.amountOut == _tokens)
        {
            address to = _expectedAddress(address(this), _senderKey, _senderOwner);            
            _savepoint(owner, tr);
            _commit(owner); // finish transaction 
            ITIP3WalletFungible(to).accept{flag: TVM.FLAG_VALUE_ADD_INBOUND, bounce: true}(_tokensToLiq(tr.amountIn,tr.amountOut)); 
        }

    }     

    /* ---------------------------------------------------------------------------------- */ 
    /* Modifiers */  

   modifier forDEX() {
        require(msg.sender == dex_, DEX.ERROR_NOT_AUTHORIZED);
        _; // BODY
        msg.sender.transfer({ value: 0, flag: 64 });  
    }    

    modifier forCallbacks() {
        require(msg.value >= CALLBACK_FEE, DEX.ERROR_NOT_ENOUGH_VALUE);           
        //tvm.rawReserve(math.max(INITIAL_GAS, address(this).balance - msg.value), 2);
        _; // BODY
        //msg.sender.transfer({ value: 0, flag: TVM.FLAG_ALL_BALANCE });  
    }       

    modifier forCustomers() {
        tvm.accept(); // for tests 
        // later: msg.value() >= CUSTOMER_FEE
        require(_hasWallets(),DEX.ERROR_POOL_WALLETS_NOT_ADDED);        
        _; // BODY
        // later: msg.sender.transfer({ value: 0, flag: TVM.FLAG_ALL_BALANCE });  
    }    
    
    /* ---------------------------------------------------------------------------------- */ 
    /* Private Part */  

    function _expireTransactions() private {
        optional(uint256, Transaction) minRecord = transactions_.min();
        if (minRecord.hasValue()) {
        (uint256 minUser, Transaction minTrans) = minRecord.get();
        if (now >= minTrans.created + 1 minutes) { _rollback(minUser); }
            while(true) {
                optional(uint256, Transaction) nextRecord = transactions_.next(minUser);
                if (nextRecord.hasValue()) {
                (uint256 nextUser, Transaction nextTrans) = nextRecord.get();
                if (now >= nextTrans.created + 1 minutes) { _rollback(nextUser); }
                minUser = nextUser;
                } else {
                break;
                }
            }
        }
    }   

   ///@notice Balance update at the end of transaction
    function _commit(uint256 user) private { 
        Transaction tr = transactions_.fetch(user).get();

        if (tr.operation == Operation.WITHDRAW) {
            total_supply_ = sub(total_supply_,tr.amountLiq);  
            if (tr.xy) {
                detailsX_.balance = sub(detailsX_.balance,tr.amountIn);
                detailsY_.balance = sub(detailsY_.balance,tr.amountOut);
            } else {
                detailsY_.balance = sub(detailsY_.balance,tr.amountIn); 
                detailsX_.balance = sub(detailsX_.balance,tr.amountOut);            
            }            
        } else if (tr.operation == Operation.DEPOSIT) {
            total_supply_ = add(total_supply_,tr.amountLiq);   
            if (tr.xy) {
                detailsX_.balance = add(detailsX_.balance,tr.amountIn);
                detailsY_.balance = add(detailsY_.balance,tr.amountOut);
            } else {
                detailsY_.balance = add(detailsY_.balance,tr.amountIn); 
                detailsX_.balance = add(detailsX_.balance,tr.amountOut);            
            }                    
        } else if (tr.operation == Operation.SWAP) {
            if (tr.xy) {
                detailsX_.balance = add(detailsX_.balance,tr.amountIn);
                detailsY_.balance = sub(detailsY_.balance,tr.amountOut);
            } else {
                detailsY_.balance = add(detailsY_.balance,tr.amountIn); 
                detailsX_.balance = sub(detailsX_.balance,tr.amountOut);            
            }
        }

        delete transactions_[user]; 
    }  

    function _rollback(uint256 user) private {
        Transaction tr = transactions_.fetch(user).get();

        if (tr.operation == Operation.DEPOSIT && tr.stage == 1) {
            (address from, address to) = (tr.xy) ? (detailsX_.wallet, _expectedAddress(detailsX_.root, tr.extOwner, tr.intOwner)) : (detailsY_.wallet,  _expectedAddress(detailsY_.root, tr.extOwner, tr.intOwner));
            ITIP3WalletFungible(from).internalTransferFrom{value: MESSAGE_FEE, bounce: true}(to, tr.amountIn);
        } 

        delete transactions_[user];
    }      

    function _savepoint(uint256 user, Transaction tr) private inline {
        transactions_.getReplace(user, tr);
    }

    function _checkToken(address _token) private inline view returns(bool) {
      return tokenX_ == _token || tokenY_ == _token;
    }    

    function _hasTransaction(uint256 owner) private inline view returns (bool) {
        return transactions_.exists(owner);
    }    

   ///@notice Internal function for processing incoming counterparty information (its )
    function _processCustomer(uint256 _senderKey, address _senderOwner) private pure returns (uint256) {
        uint256 owner;
        if (_senderKey != 0 && _senderOwner == ZERO_ADDRESS) {
            owner = _senderKey;
        }
        else if (_senderKey == 0 && _senderOwner != ZERO_ADDRESS)  {
            owner = _senderOwner.value;
        } 
        else {
            revert(DEX.ERROR_NOT_AUTHORIZED);
        }    
        return owner;
    }

    function _processToken(address _tokenAddress) private view returns (Token inToken, Token outToken, bool xy) {
        if (_tokenAddress == tokenX_)
        {
            return (detailsX_, detailsY_, true);
        } 
        else if (_tokenAddress == tokenY_)
        {
            return (detailsY_, detailsX_, false);
        }
        else {
            revert(DEX.ERROR_UNKNOWN_TOKEN);
        }
    }

    function _processTransaction(uint256 owner) private view returns (Transaction) {
        optional(Transaction) opt = transactions_.fetch(owner);
        if (opt.hasValue()) {
            return opt.get();
        } else {
            revert(DEX.ERROR_UNKNOWN_TRANSACTION);
        }
    }


    function _hasWallets() private inline view returns (bool) {
        return detailsX_.wallet != ZERO_ADDRESS && detailsY_.wallet != ZERO_ADDRESS;
    }

    function _isContract() private inline pure returns (bool) {
        return msg.sender != ZERO_ADDRESS;
    }            

    function _reserveGas() private inline returns (bool) {
        tvm.rawReserve(math.max(INITIAL_GAS, address(this).balance + DEX_VALUE_FEE - msg.value), 2);
    }         

    function _expectedAddress(address _token, uint256 walletPubkey, address walletOwner) private view returns (address)  {
        TvmCell stateInit;
        if (_token == address(this)) {
            stateInit = tvm.buildStateInit({
                contr: TIP3LiquidityWallet,
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
            return address.makeAddrStd(0, tvm.hash(stateInit));
        } else if (_token == tokenX_ || _token == tokenY_ ) {
            Token tk = (_token == tokenX_) ? detailsX_ : detailsY_;
            stateInit = tvm.buildStateInit({
                contr: TIP3FungibleWallet,
                varInit: {
                    root_address_: tk.root,   
                    wallet_public_key_: walletPubkey,
                    wallet_owner_address_: walletOwner,    
                    name_: tk.name,
                    symbol_: tk.symbol,
                    decimals_: tk.decimals,
                    code_: tk.code
                },
                pubkey: walletPubkey,
                code: tk.code
            });  
            return address.makeAddrStd(0, tvm.hash(stateInit));          
        } else {
            return ZERO_ADDRESS;
        }
    }       

    function add(uint128 x, uint128 y) internal pure returns (uint128 z) {
        require((z = x + y) >= x, 301, ERROR_ADDITION_OVERFLOW);
        z = x + y;
    }

    function sub(uint128 x, uint128 y) internal pure returns (uint128 z) {
        require((z = x - y) <= x, 302, ERROR_SUBTRACTION_OVERFLOW);
        z = x - y;
    }

    function mul(uint128 x, uint128 y) internal pure returns (uint128 z) {
        require(y == 0 || (z = x * y) / y == x, 303, ERROR_MULTIPLY_OVERFLOW);
        z = x * y;
    }    
   
    function _effectiveAmount(uint128 amountIn , uint128 balanceIn, uint128 balanceOut, uint128 fee) internal pure returns (uint128) {
        return  sub(balanceOut,
                    math.muldiv(balanceIn, 
                                balanceOut,   
                                sub(
                                    add(balanceIn,amountIn),
                                    math.muldiv(amountIn, fee, uint128(1_000_000)) 
                                    ) 
                                ) 
                   );
    }     

    function _spotAmount(uint128 inAmount, uint128 inBalance, uint128 outBalance) internal inline pure returns (uint128) {        
        return math.muldiv(outBalance, inAmount, inBalance);
    }        

    function _tokensToLiq(uint128 inAmountX, uint128 inAmountY) internal inline pure returns (uint128) {
        return math.muldivc(inAmountX, inAmountY, MIN_TOKEN_AMOUNT * MIN_TOKEN_AMOUNT); 
    }     

    function _liqToTokens(uint128 amountIn, uint128 supplyIn, uint128 balanceX, uint128 balanceY) internal pure returns (uint128 outAmountX, uint128 outAmountY) {
        outAmountX = math.muldiv(amountIn, balanceX, supplyIn) * MIN_TOKEN_AMOUNT;
        outAmountY = _spotAmount(outAmountX, balanceX, balanceY) * MIN_TOKEN_AMOUNT;
    }   

    function _minDeposit(uint128 balanceX, uint128 balanceY) internal pure returns (uint128 outAmountX, uint128 outAmountY) {
        (outAmountX, outAmountY) = (balanceX > balanceY) ? 
        (math.muldivc(MIN_TOKEN_AMOUNT, balanceX, balanceY), MIN_TOKEN_AMOUNT) : 
        (MIN_TOKEN_AMOUNT, math.muldivc(MIN_TOKEN_AMOUNT, balanceY, balanceX));
    }      

    function _minWithdrawLiq(uint128 supplyIn, uint128 balanceX, uint128 balanceY) internal pure returns (uint128) {
       return (balanceX > balanceY) ? 
       math.muldivc(MIN_TOKEN_AMOUNT, supplyIn, balanceY) : 
       math.muldivc(MIN_TOKEN_AMOUNT, supplyIn, balanceX);   
    }         

}

