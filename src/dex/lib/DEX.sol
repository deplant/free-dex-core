pragma ton-solidity >= 0.38.2;

/// @title LiquiSOR\DEX
/// @author laugan

library DEX {          

    /* Constants */

    uint128 constant INITIAL_GAS     = 1.0 ton;    
    
    uint64 constant QUERY_FEE = 0.05 ton;   
    uint64 constant WALLET_DEPLOY_FEE = 1 ton; // for new token wallet        
    uint64 constant TOKEN_IMPORT_FEE = QUERY_FEE + WALLET_DEPLOY_FEE; // for new token wallet
    uint64 constant POOL_CONTRACT_FEE = 1 ton + QUERY_FEE; // for new pair contract
    uint64 constant POOL_DEPLOY_FEE = TOKEN_IMPORT_FEE + TOKEN_IMPORT_FEE + POOL_CONTRACT_FEE; // 1 root wallet + 1 provider wallet + 1 pair
    uint64 constant MINIMUM_LIQUIDITY = 100;
    uint64 constant SWAP_FEE = 333; // fee divisor for sum (1/MAX_FEE)
    uint64 constant MAX_SWAP_POOLS = 3;          

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
    uint16 constant ERROR_TOKEN_ALREADY_IMPORTED    = 513; // Token already exists in DEX    
    uint16 constant ERROR_WRONG_CODE_CRC            = 514; // TvmCell code hash is not equal to hash provided  
    uint16 constant ERROR_POOL_WALLETS_NOT_ADDED    = 515; // Checks that pool wallets are in place  
    uint16 constant ERROR_MIN_RETURN_NOT_ACHIEVED   = 516; // Checks that return amount for swap will be better than limit           
    uint16 constant ERROR_MAX_GRAB_NOT_ACHIEVED     = 517; // Checks that amount of second token to grab is less than limit
    uint16 constant ERROR_UNKNOWN_TRANSACTION       = 518; // Unknown transaction   
    uint16 constant ERROR_ALREADY_IN_TRANSACTION    = 519; // You already have a transaction active (it will expire in 1 minute)    
    uint16 constant ERROR_NOT_ENOUGH_LIQUIDITY      = 520; // There is not enough liquidity in the pool for this operation   

}