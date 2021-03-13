pragma ton-solidity >= 0.38.2;

/// @title lib\TON
/// @author https://github.com/laugual
/// @notice Lib for common TON constants and functions

library TVM {
    
    // TVM message flags
    uint16 constant FLAG_VALUE_ONLY                     = 0; // carries funds equal to parameter value to destination. Forward fee is subtracted from parameter value.
    uint16 constant FLAG_VALUE_ADD_INBOUND              = 64; // carries funds equal to parameter value and all the remaining value of the inbound message.
    uint16 constant FLAG_ALL_BALANCE                    = 128; // carries all the remaining balance of the current smart contract. Parameter value is ignored. The contract's balance will be equal to zero.

    // TVM message flag modifiers (FLAG_ALL_BALANCE + FLAG_EXTRA_SELFDESTROY)
    uint16 constant FLAG_EXTRA_RESERVE_BALANCE          = 1; // means that the sender wants to pay transfer fees separately from contract's balance.
    uint16 constant FLAG_EXTRA_IGNORE_ERRORS            = 2; // means that any errors arising while processing this message during the action phase should be ignored.
    uint16 constant FLAG_EXTRA_SELFDESTROY              = 32; // means that the current account must be destroyed if its resulting balance is zero

}