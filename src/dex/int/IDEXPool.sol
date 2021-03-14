pragma ton-solidity >= 0.38.2;

/// @title LiquiSOR\IDEXPool
/// @author laugan
/// @notice Interfaces for work with DEXPool contract

interface IDEXPool {
    
    enum Operation { SWAP , DEPOSIT , WITHDRAW }

    struct Token { 
        address root;
        address wallet; // token DEX wallet address
        TvmCell code; // token wallet code  
        bytes name;
        bytes symbol;
        uint8 decimals;        
        uint128 balance; // token real balance
        //uint128 virt; // token virtual balance
        }

    struct Transaction {
        uint64 created;
        uint256 extOwner;
        address intOwner;
        Operation operation;
        bool xy; // x->y:true, y->x:false        
        uint8 stage;   
        uint128 amountIn; 
        uint128 amountOut;
        uint128 amountLiq;
        uint128 limit;  
    }      

    struct PoolDetails {
        address rootX;
        address walletX;
        uint128 balanceX;
        address rootY;         
        address walletY; 
        uint128 balanceY;
        uint128 providerFee;
        uint128 balanceLiq;         
    }     

    struct OrderDetails {
        uint128 firstParam;
        uint128 secondParam;    
    }     

    /* Getters */     

    /// @notice Getter to receive info about pool (wallets, balances and so on)
    function getPoolDetails() external view returns (PoolDetails details);

    /// @notice Getter to receive info about SWAP conditions with specified amount of tokens 
    /// @param _tokenAddress - root address of token that you want to sell
    /// @param _tokens - amount of tokens that you want to sell           
    /// @return details - OrderDetails structure (firstParam - amount for spot price, secondParam - amount at effective price (including fee and slippage))
    function getSwapDetails(address _tokenAddress, uint128 _tokens) external view returns (OrderDetails details);

    /// @notice Getter to receive info about DEPOSIT conditions with specified amount of tokens 
    /// @param _tokenAddress - root address of token that you want to deposit
    /// @param _tokens - amount of tokens that you want to deposit
    /// @return details - OrderDetails structure (firstParam - amount of second token that you need to put, secondParam - amount of liquidity token you will receive)
    function getDepositDetails(address _tokenAddress, uint128 _tokens) external view returns (OrderDetails details);

    /// @notice Getter to receive info about WITHDRAW conditions with specified amount of tokens 
    /// @param _tokens - amount of liquidity tokens that you want to return to DEX           
    /// @return details - OrderDetails structure (firstParam - amount of X token of Pool that you will receive, secondParam - amount of Y token of Pool that you will receive)    
    function getWithdrawDetails(uint128 _tokens) external view returns (OrderDetails details);

    /* Operations */  

    /// @notice SWAP operation 
    /// @param _tokenAddress - root address of token that you want to sell 
    /// @param _senderKey - your owner credential (if you're owning TIP-3 through public key, or 0 if not)
    /// @param _senderOwner - your owner credential (if you're owning TIP-3 through internal contract, or 0 if not)      
    /// @param _tokens - amount of tokens that you want to sell        
    /// @param _minReturn - minimum amount of 2nd token in the pair that you should receive to you wallet (or SWAP will fail)
    function swap(address _tokenAddress, uint256 _senderKey, address _senderOwner, uint128 _tokens, uint128 _minReturn) external;

    /// @notice DEPOSIT operation 
    /// @param _tokenAddress - root address of token that you want to deposit 
    /// @param _senderKey - your owner credential (if you're owning TIP-3 through public key, or 0 if not)
    /// @param _senderOwner - your owner credential (if you're owning TIP-3 through internal contract, or 0 if not)           
    /// @param _tokens - amount of tokens that you want to deposit
    /// @param _maxSpend - maximum amount of 2nd token in the pair that will be taken from your wallet (or DEPOSIT will fail). If you're the first provider of liquidity, this param is the exact amount of 2nd that you will send and establish price.
    function deposit(address _tokenAddress, uint256 _senderKey, address _senderOwner, uint128 _tokens, uint128 _maxSpend) external;

    /// @notice WITHDRAW operation 
    /// @param _senderKey - your owner credential (if you're owning TIP-3 through public key, or 0 if not)
    /// @param _senderOwner - your owner credential (if you're owning TIP-3 through internal contract, or 0 if not)          
    /// @param _tokens - amount of liquidity tokens that you want to return to DEX    
    function withdraw(uint256 _senderKey, address _senderOwner, uint128 _tokens) external;

        
}