pragma ton-solidity >= 0.36.0;

/// @title Melnorme\IDexData
/// @author Augual.Team

contract DexTypes {          

    /* Exceptions */
    uint16 constant ERROR_NOT_AUTHORIZED            = 501; // Not authorized    
    uint16 constant ERROR_NOT_A_CONTRACT            = 502; // Not internal  
    uint16 constant ERROR_PAIR_NOT_SPECIFIED        = 503; // No pair specified        
    uint16 constant ERROR_ZERO_ADDRESS              = 504; // Empty address
    uint16 constant ERROR_IDENTICAL_TOKENS          = 505; // Both tokens in pair are identical   
    uint16 constant ERROR_UNKNOWN_TOKEN             = 506; // This token is not imported to DEX
    uint16 constant ERROR_PAIR_EXISTS               = 507; // This pair already deployed 
    uint16 constant ERROR_WRONG_VALUE               = 508; // Wrong number    
    uint16 constant ERROR_NOT_ENOUGH_VALUE          = 509; // Not enough value attached   
    uint16 constant ERROR_ZERO_AMOUNT               = 510; // Amount of tokens can't be zero  
    uint16 constant ERROR_INCORRRECT_TIP3           = 511; // Incorrect TIP3 wallet address  
    uint16 constant ERROR_NOT_ENOUGH_TOKENS         = 512; // Not enough TIP3 tokens in wallet
    uint16 constant ERROR_TOKEN_ALREADY_IMPORTED    = 513; // Not enough TIP3 tokens in wallet    
    uint16 constant ERROR_WRONG_CODE_CRC            = 514; // TvmCell code hash is not equal to hash provided       

    /* Constants */
    uint64 constant QUERY_FEE = 0.05 ton;   
    uint64 constant WALLET_DEPLOY_FEE = 1 ton; // for new token wallet        
    uint64 constant TOKEN_IMPORT_FEE = QUERY_FEE + WALLET_DEPLOY_FEE; // for new token wallet
    uint64 constant POOL_CONTRACT_FEE = 1 ton + QUERY_FEE; // for new pair contract
    uint64 constant POOL_DEPLOY_FEE = TOKEN_IMPORT_FEE + TOKEN_IMPORT_FEE + POOL_CONTRACT_FEE; // 1 root wallet + 1 provider wallet + 1 pair
    uint64 constant MINIMUM_LIQUIDITY = 100;
    uint128 constant SWAP_FEE = 333; // fee divisor for sum (1/MAX_FEE)
    uint64 constant MAX_SWAP_POOLS = 3;          

    // TIP-3 token struct
    struct TIP3 {
        bytes name;  // TIP-3 name
        bytes symbol; // TIP-3 symbol/ticker
        uint8 decimals;  // TIP-3 decimals
        address rootAddr;    // RTW address of TIP-3
        uint256 rootKey;    // RPK of TIP-3
        TvmCell ttwCode;    // cell with TTW code
        uint128 balance;   // token balance
    }

    struct Pool {
        TIP3 tokenA;
        TIP3 tokenB;
    }    

/// For future event logging
    event log(
        bytes4  indexed sig,
        address indexed caller
    ) anonymous;    

    event Deployed(
        address indexed pool,
        uint256 indexed pubkey,            
        address indexed tokenA,
        address indexed tokenB
    ) anonymous;    

    event Provided(
        address indexed pool,
        uint256 indexed pubkey,        
        uint128 indexed amountA,
        uint128 indexed amountB
    ) anonymous;      

    // Safery check of TIP3 sender address by comparison with code&pubkey of stored token
    function expectedAddress(uint256 _pubkey, TvmCell _code) internal pure returns (address)  {
        TvmCell stateInit = tvm.buildStateInit({ code: _code, pubkey: _pubkey }); 
        return address(tvm.hash(stateInit)); 
    }

}