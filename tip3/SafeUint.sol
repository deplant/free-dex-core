pragma ton-solidity >= 0.36.0;

/// @title Melnorme\SafeUint
/// @author Augual.Team

library SafeUint {

    function add(uint128 x, uint128 y) internal pure returns (uint128 z) {
        require((z = x + y) >= x, 301, "SafeUint: add overflow!");
    }

    function sub(uint128 x, uint128 y) internal pure returns (uint128 z) {
        require((z = x - y) <= x, 302, "SafeUint: subtract overflow!");
    }

    function mul(uint128 x, uint128 y) internal pure returns (uint128 z) {
        require(y == 0 || (z = x * y) / y == x, 303, "SafeUint: multiply overflow!");
    }

}