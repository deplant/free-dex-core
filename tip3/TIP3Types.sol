pragma ton-solidity >= 0.36.0;

pragma AbiHeader expire;

contract TIP3Types {

    uint64 constant USAGE_FEE       = 0.005 ton;
    uint64 constant MESSAGE_FEE     = 0.001 ton;   
    uint64 constant CALLBACK_FEE    = 0.00001 ton;    
    
    uint16 ERROR_MESSAGE_SENDER_IS_NOT_MY_OWNER             = 100;
    uint16 ERROR_NOT_ENOUGH_BALANCE                         = 101;
    uint16 ERROR_MESSAGE_SENDER_IS_NOT_MY_ROOT              = 102;
    uint16 ERROR_MESSAGE_SENDER_IS_NOT_GOOD_WALLET          = 103;
    uint16 ERROR_WRONG_BOUNCED_HEADER                       = 104;
    uint16 ERROR_WRONG_BOUNCED_ARGS                         = 105;
    uint16 ERROR_NON_ZERO_REMAINING                         = 106;
    uint16 ERROR_NO_ALLOWANCE_SET                           = 107;
    uint16 ERROR_WRONG_SPENDER                              = 108;
    uint16 ERROR_NOT_ENOUGH_ALLOWANCE                       = 109;
    uint16 ERROR_LOW_MESSAGE_VALUE                          = 110;
    uint16 ERROR_DEFINE_WALLET_PUBLIC_KEY_OR_OWNER_ADDRESS  = 111;   
    uint16 ERROR_MESSAGE_RECEIVER_IS_NOT_GOOD_WALLET        = 112; 
    uint16 ERROR_NOT_ENOUGH_GAS                             = 113;   
    uint16 ERROR_DEFINE_WALLET_OWNERS                       = 114;        

}