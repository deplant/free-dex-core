pragma ton-solidity >= 0.36.0;

/// @title Melnorme\SafeUint
/// @author Augual.Team

library SafeUint {

    uint16 constant ERROR_ADDITION_OVERFLOW         = 300;
    uint16 constant ERROR_SUBTRACTION_OVERFLOW      = 301;
    uint16 constant ERROR_MULTIPLY_OVERFLOW         = 302;    

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

}