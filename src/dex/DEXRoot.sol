pragma ton-solidity >= 0.38.2;

/// @title LiquiSOR\DEXRoot
/// @author laugan
/// @notice Factory contract for pool deployment, adding TIP-3 tokens and overall DEX management

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "/home/yankin/ton/contracts/src/std/lib/TVM.sol";
import "/home/yankin/ton/contracts/src/dex/lib/DEX.sol";
import "/home/yankin/ton/contracts/src/dex/DEXPool.sol";
import "/home/yankin/ton/contracts/src/dex/int/IDEXRoot.sol";
import "/home/yankin/ton/contracts/src/tip3/int/ITIP3Root.sol";


contract DEXRoot is IDEXRoot {

    /* Attributes */    

    uint8 static iteration;

    mapping(address  => bytes) tokens_; // key - root, value - symbol
    
    TvmCell liqWalletCode_;
    TvmCell poolCode_;       
    address governance_;

    uint64 constant DEPLOY_FEE      = 1.5 ton;
    uint64 constant USAGE_FEE       = 0.1 ton;
    uint64 constant MESSAGE_FEE     = 0.05 ton;   
    uint64 constant CALLBACK_FEE    = 0.01 ton;  
    uint128 constant INITIAL_GAS    = 0.5 ton; 
    address constant ZERO_ADDRESS   = address.makeAddrStd(0, 0);   

    /// @dev Contract constructor.
    constructor() public {
      require(msg.pubkey() == tvm.pubkey(), DEX.ERROR_NOT_AUTHORIZED);
      tvm.accept();      
     }

    /* Gatters */  

    function getTokenExists(address rootAddress) external override view returns(bool) {
      return tokens_.exists(rootAddress);
    }

    function getPoolAddress(address _tokenA, address _tokenB) external override view returns (address poolAddress) {
        (address tokenX, address tokenY) = _pairRoutine(_tokenA, _tokenB);
        poolAddress = _expectedAddress(tokenX, tokenY);
    }

    /* User methods */    
     
   // import of tokens by users (requires value) 
   function importToken(address _rootAddr, bytes symbol) external override onlyOwnerAcceptOrPay {
     //ITIP3RootFungible(_rootAddr).info{ callback: onGetInfo, value: USAGE_FEE }();
     tokens_.add(_rootAddr, symbol);
   }
 
   /// Function for deployment of pair pools by users (requires value)
   function deployPool(address _tokenA, address _tokenB, address _walletA, address _walletB) external override onlyOwnerAcceptOrPay returns(address poolAddress) {

        // check enough value with message!!!
        //require(msg.value >= DEX.POOL_DEPLOY_FEE, DEX.ERROR_NOT_ENOUGH_VALUE);

        // token pair routine
        (address tokenX, address tokenY) = _pairRoutine(_tokenA, _tokenB);
        (address walletX, address walletY) = _tokenA < _tokenB ? (_walletA, _walletB) : (_walletB, _walletA);
        //bytes name = abi.encodePacked("0x4c4951534f523a474c443a504c54");//bytes(_pairName(tokenX, tokenY));
        //bytes symbol = abi.encodePacked("0x4c4951534f523a474c443a504c54");//bytes(_pairSymbol(tokenX, tokenY));
        // deploy pair pool contract
        poolAddress  = new DEXPool {
          code: poolCode_,
          value: DEPLOY_FEE,
          pubkey: 0,
          varInit: {
                dex_: address(this),
                name_: "LIQSOR:GLD:PLT",//_pairName(tokenX, tokenY),
                symbol_: "LIQSOR:GLD:PLT",//_pairSymbol(tokenX, tokenY),
                code_:  liqWalletCode_,                
                tokenX_:tokenX,
                tokenY_:tokenY
            }
          }(walletX, walletY); // constructor params

        return poolAddress;

   }

    /* Owner/Governance methods */  

    function updatePoolCode(TvmCell _cell) external onlyOwnerAcceptOrPay {
      //require(cellHash == tvm.hash(_cell), ERROR_WRONG_CODE_CRC);
      poolCode_ = _cell;
    }

    function updateLiqWalletCode(TvmCell _cell) external onlyOwnerAcceptOrPay {
      //require(cellHash == tvm.hash(_cell), ERROR_WRONG_CODE_CRC);
      liqWalletCode_ = _cell;
    }     

    function deployGovernance(address _govAddress) external onlyOwnerAcceptOrPay {
      require(_govAddress != ZERO_ADDRESS, DEX.ERROR_WRONG_VALUE);
      governance_ = _govAddress;
    }     

    /* Callbacks */  

    // callback from TIP-3 token root
   //function onGetInfo(uint256 rootKey, address rootOwner, bytes name , bytes symbol, uint8 decimals, TvmCell code) public internalOnlyPay {
       //require(hashes_.exists(tvm.hash(code)), ERROR_WRONG_CODE_CRC);
   //    tokens_.add(msg.sender, symbol);
   //}    
  
    /* Private part */  

     modifier internalOnlyPay() {
        require(msg.sender != ZERO_ADDRESS && msg.value >= USAGE_FEE,DEX.ERROR_NOT_ENOUGH_VALUE);   
        _reserveGas();
        _; // BODY
        msg.sender.transfer({ value: 0, flag: TVM.FLAG_ALL_BALANCE });  
    }

    // Modifier for governance functions
    // It checks for owner public key until governance is deployed,
    // then it accepts only governance' decisions
    // At the end, sends back gas if value was attached
    modifier onlyOwnerAcceptOrPay() {
        require(_isOwner(), DEX.ERROR_NOT_AUTHORIZED);
        if (msg.sender != ZERO_ADDRESS) {
            require(msg.value >= USAGE_FEE,DEX.ERROR_NOT_ENOUGH_VALUE);             
            _reserveGas();
        } else {
            tvm.accept();
        }
        _; // BODY
        if (msg.sender != ZERO_ADDRESS) {
            msg.sender.transfer({ value: 0, flag: TVM.FLAG_ALL_BALANCE });  
        } 
    }    

    function _reserveGas() internal inline returns (bool) {
        tvm.rawReserve(math.max(INITIAL_GAS, address(this).balance - msg.value), 2);
    }            

    // after deployment of governance, you're not the owner anymore!
    function _isOwner() internal inline view returns (bool) {
      return (
             (governance_ != ZERO_ADDRESS && msg.sender == governance_) || 
             (governance_ == ZERO_ADDRESS && msg.pubkey() == tvm.pubkey()) 
             );
    }          

    function _pairRoutine(address _tokenA, address _tokenB) private inline view returns (address tokenX, address tokenY) {
      // token pair routine
      require(_checkToken(_tokenA) && _checkToken(_tokenB),DEX.ERROR_UNKNOWN_TOKEN);
      require(_tokenA != _tokenB, DEX.ERROR_IDENTICAL_TOKENS);        
      (tokenX, tokenY) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
    }  

    function _checkToken(address _token) private inline view returns(bool) {
      return tokens_.exists(_token) && tokens_.fetch(_token).hasValue();
    }

    function _pairName(address _tokenX, address _tokenY) private view returns (string) {
      string str = "4c69717569534f5220506f6f6c207b";
      str.append(tokens_.fetch(_tokenX).get());
      str.append("2d");
      str.append(tokens_.fetch(_tokenY).get());
      str.append("7d");
      return bytes(str);
    }

    function _pairSymbol(address _tokenX, address _tokenY) private view returns (string) {
      string str = "4c51534f523a"; 
      str.append(tokens_.fetch(_tokenX).get());
      str.append("3a");
      str.append(tokens_.fetch(_tokenY).get());
      return bytes(str);  
    }

    function _expectedAddress(address _tokenX, address _tokenY) internal inline view returns (address)  {
        //bytes name = abi.encodePacked("0x4c4951534f523a474c443a504c54");//bytes(_pairName(tokenX, tokenY));
        //bytes symbol = abi.encodePacked("0x4c4951534f523a474c443a504c54");//bytes(_pairSymbol(tokenX, tokenY));
        TvmCell stateInit = tvm.buildStateInit({
            contr: DEXPool,
            varInit: {
                dex_: address(this),
                name_: "LIQSOR:GLD:PLT",
                symbol_: "LIQSOR:GLD:PLT",
                code_:  liqWalletCode_,                    
                tokenX_:_tokenX,
                tokenY_:_tokenY
            },        
            code: poolCode_
        });
        return address.makeAddrStd(0, tvm.hash(stateInit));
    }                 

}

