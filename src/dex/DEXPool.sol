pragma ton-solidity >= 0.38.2;

/// @title LiquiSOR\DEXPool
/// @author laugan
/// @notice Contract for providing liquidity and trading. In the same time it's a root contract for TIP-3 Liquidity token

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "/home/yankin/ton/contracts/src/std/lib/TVM.sol";
import "/home/yankin/ton/contracts/src/tip3/int/ITIP3Root.sol";
import "/home/yankin/ton/contracts/src/tip3/int/ITIP3Wallet.sol";
import "/home/yankin/ton/contracts/src/dex/int/IDEXPool.sol";
import "/home/yankin/ton/contracts/src/dex/lib/DEX.sol";
import "/home/yankin/ton/contracts/src/dex/TIP3LiquidityWallet.sol";

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
    uint64 constant USAGE_FEE       = 0.1 ton;
    uint64 constant MESSAGE_FEE     = 0.05 ton;   
    uint64 constant CALLBACK_FEE    = 0.01 ton;  
    uint128 constant INITIAL_GAS    = 0.5 ton; 
    address constant ZERO_ADDRESS   = address.makeAddrStd(0, 0); 

    uint64 constant INIT_FEE = 3 ton; //USAGE_FEE + 3 * DEPLOY_FEE + 2 * MESSAGE_FEE + 2 * CALLBACK_FEE;
    uint64 constant CUSTOMER_FEE = 0.1 ton; //USAGE_FEE + 3 * MESSAGE_FEE + 2 * CALLBACK_FEE;

    uint128 constant MIN_TOKEN_AMOUNT = 100; 
    uint16 constant ERROR_ADDITION_OVERFLOW         = 300;
    uint16 constant ERROR_SUBTRACTION_OVERFLOW      = 301;
    uint16 constant ERROR_MULTIPLY_OVERFLOW         = 302;   
    
    Token detailsX_;
    Token detailsY_;
    uint128 total_supply_;  

    mapping(uint256 => Transaction) transactions_;

    /// @dev Contract constructor.
    constructor(address walletX, address walletY) public {
        //tvm.accept();
        detailsX_.root = tokenX_;
        detailsY_.root = tokenY_;
        detailsX_.wallet = walletX;
        detailsY_.wallet = walletY;
     }

    /* TIP3 Metadata Functions */

    function getName() override external view returns (bytes name) {
        name = name_;
    }

    function getSymbol() override  external view returns (bytes symbol) {
        symbol = symbol_;
    }

    function getDecimals() override  external view returns (uint8 decimals) {
        decimals = decimals_;
    }

    function getRootKey() override  external view returns (uint256 rootKey) {
        rootKey = uint256(0);
    }

    function getRootOwner() override  external view returns (address rootOwner) {
        rootOwner = dex_;
    }  

    function getTotalSupply() override  external view returns (uint128 totalSupply) {
        totalSupply = total_supply_;
    }

    function getTotalGranted() override  external view returns (uint128 totalGranted) {
        totalGranted = total_supply_;
    }

    function getWalletCode() override  external view returns (TvmCell walletCode) {
        walletCode = code_;
    }

    function getWalletAddress(int8 workchainId, uint256 walletPubkey, address walletOwner) override external view returns (address walletAddress) {
        walletAddress = _expectedAddress(address(this), walletPubkey, walletOwner);
    } 

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

    /* Pool Getters */  

    function getPoolDetails() external override view returns (PoolDetails details) {
        details = PoolDetails(detailsX_.root, 
                            detailsX_.wallet,
                            detailsX_.balance, 
                            detailsY_.root,         
                            detailsY_.wallet, 
                            detailsY_.balance,
                            fee_,
                            total_supply_);       
    }     

    function getSwapDetails(address _tokenAddress, uint128 _tokens) external override view returns (OrderDetails details) {
        require(_checkToken(_tokenAddress),DEX.ERROR_UNKNOWN_TOKEN);
        require(_hasWallets(),DEX.ERROR_POOL_WALLETS_NOT_ADDED);
        (Token tokIn, Token out) = (_tokenAddress == tokenX_) ? (detailsX_, detailsY_) : (detailsY_, detailsX_);
        uint128 spotPrice;
        uint128 effectivePrice;           
        if (tokIn.balance == 0 || out.balance == 0) {
            spotPrice = 0;
            effectivePrice = 0;
        } else {
            spotPrice = calcOtherToken(_tokens,tokIn.balance, out.balance);
            effectivePrice = priceSwap(_tokens, tokIn.balance, out.balance, fee_);
        }

        details = OrderDetails(spotPrice, effectivePrice);
    }     

    function getDepositDetails(address _tokenAddress, uint128 _tokens) external override view returns (OrderDetails details) {
        require(_checkToken(_tokenAddress),DEX.ERROR_UNKNOWN_TOKEN);
        require(_hasWallets(),DEX.ERROR_POOL_WALLETS_NOT_ADDED);
        (Token tokIn, Token out) = (_tokenAddress == tokenX_) ? (detailsX_, detailsY_) : (detailsY_, detailsX_);
        uint128 secondAmount = (tokIn.balance == 0 || out.balance == 0) ? 0 : calcOtherToken(_tokens,tokIn.balance, out.balance); 
        uint128 liqAmount = tokensToLiq(_tokens, secondAmount);
        details = OrderDetails(secondAmount, liqAmount);        
    }         

    function getWithdrawDetails(uint128 _tokens) external override view returns (OrderDetails details) {
        require(_hasWallets(),DEX.ERROR_POOL_WALLETS_NOT_ADDED);
        (uint128 amountX, uint128 amountY) = liqToTokens(_tokens,total_supply_, detailsX_.balance, detailsY_.balance);
        details = OrderDetails(amountX, amountY);            
    }    

        

    /* Pool Operations */  
    function swap(address _tokenAddress, uint256 _senderKey, address _senderOwner, uint128 _tokens, uint128 _minReturn) external override customerOnlyPay {
        require(_checkToken(_tokenAddress),DEX.ERROR_UNKNOWN_TOKEN);
        require(_hasWallets(),DEX.ERROR_POOL_WALLETS_NOT_ADDED);
        require(detailsX_.balance > 0 && detailsY_.balance > 0,DEX.ERROR_NOT_ENOUGH_LIQUIDITY);
        require((_senderKey != 0 && _senderOwner == ZERO_ADDRESS) ||
        (_senderKey == 0 && _senderOwner != ZERO_ADDRESS)
        ,DEX.ERROR_NOT_AUTHORIZED);      
        require(!transactions_.exists(_senderKey + _senderOwner.value), DEX.ERROR_ALREADY_IN_TRANSACTION);
            
        (Token tokIn, Token out) = _tokenAddress == tokenX_ ? (detailsX_, detailsY_) : (detailsY_, detailsX_);
        uint128 outAmount = priceSwap(_tokens,tokIn.balance, out.balance, fee_);

        require(outAmount >= _minReturn, DEX.ERROR_MIN_RETURN_NOT_ACHIEVED);
        require(out.balance - outAmount >= MIN_TOKEN_AMOUNT, DEX.ERROR_NOT_ENOUGH_LIQUIDITY);

        address from = _expectedAddress(tokIn.root, _senderKey, _senderOwner);   

        // init transaction
        (bool xy, uint128 amountX, uint128 amountY) = _tokenAddress == tokenX_ ? (true, _tokens, uint128(0)) : (false, uint128(0), _tokens);
        Transaction tr = Transaction(
                                now, 
                                _senderKey, 
                                _senderOwner, 
                                Operation.SWAP, 
                                xy,  
                                0,
                                amountX, 
                                amountY, 
                                0, 
                                _minReturn, 
                                0 
        );
        transactions_.add(_senderKey + _senderOwner.value, tr);        

        ITIP3WalletNotify(from).internalTransferFromNotify{value: MESSAGE_FEE, bounce: true}(tokIn.wallet, _tokens, address(this));

        _expireTransactions();
    }

  function deposit(address _tokenAddress, uint256 _senderKey, address _senderOwner, uint128 _tokens, uint128 _maxSpend) external override customerOnlyPay {
        require(_checkToken(_tokenAddress),DEX.ERROR_UNKNOWN_TOKEN);
        require(_hasWallets(),DEX.ERROR_POOL_WALLETS_NOT_ADDED);
        require((_senderKey != 0 && _senderOwner == ZERO_ADDRESS) ||
        (_senderKey == 0 && _senderOwner != ZERO_ADDRESS)
        ,DEX.ERROR_NOT_AUTHORIZED);
        require(!transactions_.exists(_senderKey + _senderOwner.value), DEX.ERROR_ALREADY_IN_TRANSACTION);

        (Token tokIn, Token out) = _tokenAddress == tokenX_ ? (detailsX_, detailsY_) : (detailsY_, detailsX_);

        // if it is first deposit, maxSpend is your desired amount of second token
        uint128 outAmount = (tokIn.balance == 0 || out.balance == 0) ? _maxSpend : calcOtherToken(_tokens,tokIn.balance, out.balance); 
        require(outAmount <= _maxSpend, DEX.ERROR_MAX_GRAB_NOT_ACHIEVED);       

        address toIn = _expectedAddress(tokIn.root, _senderKey, _senderOwner); 
        address toOut = _expectedAddress(tokIn.root, _senderKey, _senderOwner); 

        // init transaction
        (bool xy, uint128 amountX, uint128 amountY) = _tokenAddress == tokenX_ ? (true, _tokens, outAmount) : (false, outAmount, _tokens);
        Transaction tr = Transaction(
                                now, 
                                _senderKey, 
                                _senderOwner, 
                                Operation.DEPOSIT,
                                xy,  
                                0,   
                                amountX, 
                                amountY, 
                                0, 
                                0, 
                                _maxSpend  
        );
        transactions_.add(_senderKey + _senderOwner.value, tr);          

        ITIP3WalletNotify(tokIn.wallet).internalTransferFromNotify{value: USAGE_FEE, bounce: true}(toIn, _tokens, address(this));
        ITIP3WalletNotify(out.wallet).internalTransferFromNotify{value: USAGE_FEE, bounce: true}(toOut, outAmount, address(this));

        _expireTransactions();      
    }
 
    function withdraw(uint256 _senderKey, address _senderOwner, uint128 _tokens) external override customerOnlyPay {
        require(_hasWallets(),DEX.ERROR_POOL_WALLETS_NOT_ADDED);
        require((_senderKey != 0 && _senderOwner == ZERO_ADDRESS) ||
        (_senderKey == 0 && _senderOwner != ZERO_ADDRESS)
        ,DEX.ERROR_NOT_AUTHORIZED);
        require(!transactions_.exists(_senderKey + _senderOwner.value), DEX.ERROR_ALREADY_IN_TRANSACTION);
        require(_tokens >= minWithdrawLiq(total_supply_, detailsX_.balance, detailsY_.balance), DEX.ERROR_NOT_ENOUGH_LIQUIDITY); 

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
                                0, 
                                0 
        );
        transactions_.add(_senderKey + _senderOwner.value, tr);            

        _burn(_senderKey, _senderOwner, _tokens);

        _expireTransactions();
    }     


      /* Callbacks from TIP-3 */  

   // callback from TIP-3 token root
   /*function onWalletDeploy(address walletAddress, TvmCell code) public internalOnlyPay {
        if ( msg.sender == tokenX_ && detailsX_.wallet == ZERO_ADDRESS) 
        {
            detailsX_.wallet = walletAddress;
            detailsX_.code = code;
        } 
        else if (msg.sender == tokenY_ && detailsY_.wallet == ZERO_ADDRESS) 
        {
            detailsY_.wallet = walletAddress;
            detailsY_.code = code;
        }
   }       */

    ///@notice Callback from LiquidityWallet
    function onWalletBurn(address _tokenAddress, uint256 _senderKey, address _senderOwner, uint128 _tokens) public override internalOnlyPay {
        require(_tokenAddress == address(this),DEX.ERROR_UNKNOWN_TOKEN);
        address senderAddr = _expectedAddress(_tokenAddress, _senderKey, _senderOwner);
        uint256 sender = _senderKey + _senderOwner.value;

        if(msg.sender == senderAddr) {
            require(transactions_.exists(sender),DEX.ERROR_UNKNOWN_TRANSACTION);
                Transaction trans = transactions_.fetch(sender).get();
                if (trans.operation == Operation.WITHDRAW && trans.stage == 0) {
                    if (trans.amountLiq == _tokens) {
                            //(trans.amountX, trans.amountY) = DEXMath.liqToTokens(_tokens, total_supply_, detailsX_.balance, detailsY_.balance);
                            trans.amountX = math.muldiv(_tokens, detailsX_.balance, total_supply_);
                            trans.amountY = calcOtherToken(trans.amountX, detailsX_.balance, detailsY_.balance);
                            ITIP3WalletFungible(detailsX_.wallet).internalTransferFrom{value: MESSAGE_FEE, bounce: true}(senderAddr, trans.amountX);
                            ITIP3WalletFungible(detailsY_.wallet).internalTransferFrom{value: MESSAGE_FEE, bounce: true}(senderAddr, trans.amountY);
                            _confirmTransaction(sender, trans); // pre-last command of whole transaction
                    } else {
                        _cancelTransaction(sender);
                    }
                }
        } else {
            revert(DEX.ERROR_NOT_AUTHORIZED);
        }
    }      

    ///@notice Callback from TIP-3 internalTransferNotify() function
    function onWalletReceive(address _tokenAddress, uint256 _receiverKey, address _receiverOwner, uint256 _senderKey, address _senderOwner, uint128 _tokens) public override internalOnlyPay {
        require(_checkToken(_tokenAddress),DEX.ERROR_UNKNOWN_TOKEN);
        (Token tokIn, Token out ) = (_tokenAddress == tokenX_) ? (detailsX_, detailsY_) : (detailsY_, detailsX_);
        address receiverAddr = _expectedAddress(_tokenAddress, _receiverKey, _receiverOwner);
        address senderAddr = _expectedAddress(_tokenAddress, _senderKey, _senderOwner);
        
        uint256 receiver = _receiverKey + _receiverOwner.value;
        uint256 sender = _senderKey + _senderOwner.value;
     
        if(msg.sender == tokIn.wallet) {
            require(transactions_.exists(sender),DEX.ERROR_UNKNOWN_TRANSACTION);
            _processAnswer(sender, true, receiverAddr, senderAddr, tokIn, out, _tokens);
        } else if (tokIn.wallet == senderAddr && 
                    msg.sender == receiverAddr) {
            require(transactions_.exists(receiver),DEX.ERROR_UNKNOWN_TRANSACTION);
            _processAnswer(receiver, false, receiverAddr, senderAddr, tokIn, out, _tokens);
        } else {
            revert(DEX.ERROR_NOT_AUTHORIZED);
        }
    }     

   modifier vaultOnly() {
        require(msg.sender == dex_, DEX.ERROR_NOT_AUTHORIZED);
        if (msg.sender != ZERO_ADDRESS) {
            require(msg.value >= USAGE_FEE,DEX.ERROR_NOT_ENOUGH_VALUE);             
            _reserveGas();
        } else {
            tvm.accept();
        }
        _; // BODY
        if (msg.sender != ZERO_ADDRESS) {
            msg.sender.transfer({ value: 0, flag: 128 });  
        } 
    }    

    modifier internalOnlyPay() {
        require(msg.sender != ZERO_ADDRESS && msg.value >= CALLBACK_FEE, DEX.ERROR_NOT_ENOUGH_VALUE);           
        tvm.rawReserve(math.max(INITIAL_GAS, address(this).balance - msg.value), 2);
        _; // BODY
        msg.sender.transfer({ value: 0, flag: TVM.FLAG_ALL_BALANCE });  
    }       

    modifier customerOnlyPay() {
        tvm.accept(); // for tests
        //require(msg.sender != ZERO_ADDRESS && msg.value >= CUSTOMER_FEE, DEX.ERROR_NOT_ENOUGH_VALUE);   
        require(_hasWallets(),DEX.ERROR_POOL_WALLETS_NOT_ADDED);        
        //_reserveGas();
        _; // BODY
        //msg.sender.transfer({ value: 0, flag: TVM.FLAG_ALL_BALANCE });  
    }    
    

    /* Private Part */  

   function _processAnswer(uint256 user, bool toDex, address receiverAddr, address senderAddr, Token tokenThis, Token tokenThat, uint128 tokens) private {
        // senders, receivers and existence of transaction are checked on this point
        Transaction trans = transactions_.fetch(user).get();
        
        if (trans.operation == Operation.SWAP && trans.stage == 0 && toDex) {
            if (trans.xy && trans.amountX == tokens) {
                trans.amountY = priceSwap(tokens,tokenThis.balance, tokenThat.balance, fee_);  
                if (trans.amountY >= trans.minReturn) {
                    ITIP3WalletFungible(tokenThat.wallet).internalTransferFrom{value: MESSAGE_FEE, bounce: true}(senderAddr, trans.amountY);
                    _confirmTransaction(user, trans); // pre-last command of whole transaction
                } else {
                    _cancelTransaction(user);
                }
            } else if (trans.xy && trans.amountY == tokens) {
                trans.amountX = priceSwap(tokens, tokenThis.balance, tokenThat.balance, fee_);    
                if (trans.amountX >= trans.minReturn) {
                    ITIP3WalletFungible(tokenThat.wallet).internalTransferFrom{value: MESSAGE_FEE, bounce: true}(senderAddr, trans.amountX);
                    _confirmTransaction(user, trans); // pre-last command of whole transaction
                } else {
                    _cancelTransaction(user);
                }
            } else {
                _cancelTransaction(user);
            }
        }      
        else if (trans.operation == Operation.DEPOSIT && trans.stage == 0 && toDex) {
            if (trans.amountX == tokens || trans.amountY == tokens) {
                Transaction tr = transactions_.fetch(user).get();
                tr.stage = 1;
                transactions_.getReplace(user, tr);
            } else {
                _cancelTransaction(user);
            }
        }   
        else if (trans.operation == Operation.DEPOSIT && trans.stage == 1 && toDex) {
            if (trans.amountX == tokens || trans.amountY == tokens) {
                    ITIP3WalletFungible(senderAddr).accept{value: MESSAGE_FEE, bounce: true}(tokensToLiq(trans.amountX,trans.amountY)); 
                    _confirmTransaction(user, trans); // pre-last command of whole transaction
            } else {
                _cancelTransaction(user);
            }
        }
    } 



   ///@notice Balance update at the end of transaction
    function _confirmTransaction(uint256 user, Transaction _transaction) private { 
        if (_transaction.operation == Operation.WITHDRAW) {
            total_supply_ = add(total_supply_,_transaction.amountLiq); 
            detailsX_.balance = sub(detailsX_.balance,_transaction.amountX);
            detailsY_.balance = sub(detailsY_.balance,_transaction.amountY);
        } else if (_transaction.operation == Operation.DEPOSIT) {
            total_supply_ = sub(total_supply_,_transaction.amountLiq); 
            detailsX_.balance = add(detailsX_.balance,_transaction.amountX);
            detailsY_.balance = add(detailsY_.balance,_transaction.amountY);            
        } else if (_transaction.operation == Operation.SWAP) {
            if (_transaction.xy) {
                detailsX_.balance = add(detailsX_.balance,_transaction.amountX);
                detailsY_.balance = sub(detailsY_.balance,_transaction.amountY);
            } else {
                detailsY_.balance = add(detailsY_.balance,_transaction.amountY); 
                detailsX_.balance = sub(detailsX_.balance,_transaction.amountX);            
            }
        }
        //balanceK_ = mul(detailsX_.balance,detailsY_.balance); // update K constant
        //_updateDAMM(); // update virtual balances
        delete transactions_[user]; // last command of whole transaction
    }  
           

    function _expireTransactions() private {
        optional(uint256, Transaction) minRecord = transactions_.min();
        if (minRecord.hasValue()) {
        (uint256 minUser, Transaction minTrans) = minRecord.get();
        if (now >= minTrans.created + 1 minutes) { _cancelTransaction(minUser); }
            while(true) {
                optional(uint256, Transaction) nextRecord = transactions_.next(minUser);
                if (nextRecord.hasValue()) {
                (uint256 nextUser, Transaction nextTrans) = nextRecord.get();
                if (now >= nextTrans.created + 1 minutes) { _cancelTransaction(nextUser); }
                minUser = nextUser;
                } else {
                break;
                }
            }
        }
    }        

    function _cancelTransaction(uint256 user) private {
        // for now, cancel only deletes transactions, without returning funds
        delete transactions_[user];
    }      

    function _burn(uint256 walletPubkey, address walletOwner, uint128 tokens) private view returns (address walletAddress) {
        walletAddress = _expectedAddress(address(this), walletPubkey, walletOwner);
        ITIP3WalletRootBurnable(walletAddress).internalBurnFromRoot{value: MESSAGE_FEE, bounce: true}(tokens, address(this));
    }       

    function _checkToken(address _token) private inline view returns(bool) {
      return tokenX_ == _token || tokenY_ == _token;
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
   
    function priceSwap(uint128 amountIn , uint128 balanceIn, uint128 balanceOut, uint128 fee) internal pure returns (uint128) {
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

    function calcOtherToken(uint128 inAmount, uint128 inBalance, uint128 outBalance) internal inline pure returns (uint128) {        
        return math.muldiv(outBalance, inAmount, inBalance);
    }        

    function tokensToLiq(uint128 inAmountX, uint128 inAmountY) internal inline pure returns (uint128) {
        return mul(inAmountX, inAmountY); 
    }     

    function liqToTokens(uint128 amountIn, uint128 supplyIn, uint128 balanceX, uint128 balanceY) internal pure returns (uint128 outAmountX, uint128 outAmountY) {
        outAmountX = math.muldiv(amountIn, balanceX, supplyIn);
        outAmountY = calcOtherToken(outAmountX, balanceX, balanceY);
    }   

    function minDeposit(uint128 balanceX, uint128 balanceY) internal pure returns (uint128 outAmountX, uint128 outAmountY) {
        (outAmountX, outAmountY) = (balanceX > balanceY) ? 
        (math.muldivc(MIN_TOKEN_AMOUNT, balanceX, balanceY), MIN_TOKEN_AMOUNT) : 
        (MIN_TOKEN_AMOUNT, math.muldivc(MIN_TOKEN_AMOUNT, balanceY, balanceX));
    }      

    function minWithdrawLiq(uint128 supplyIn, uint128 balanceX, uint128 balanceY) internal pure returns (uint128) {
       return (balanceX > balanceY) ? 
       math.muldivc(MIN_TOKEN_AMOUNT, supplyIn, balanceY) : 
       math.muldivc(MIN_TOKEN_AMOUNT, supplyIn, balanceX);   
    }         

}

