pragma ton-solidity >= 0.36.0;

/// @title Melnorme\IDexData
/// @author Augual.Team

interface IDexData {

    // TIP-3 token struct
    struct Tip3 {
        bytes name;  // TIP-3 name
        bytes symbol; // TIP-3 symbol/ticker
        uint8 decimals;  // TIP-3 decimals
        address rootAddr;    // RTW address of TIP-3
        uint256 rootKey;    // RPK of TIP-3
        TvmCell ttwCode;    // cell with TTW code
        uint128 balance;   // token balance
    }

    struct Pool {
        Tip3 tokenA;
        Tip3 tokenB;
    }    
}