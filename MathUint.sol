pragma ton-solidity >= 0.36.0;

/// @title Melnorme\MathUint
/// @author Augual.Team

library MathUint {

    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, 301, "MathUint: add overflow!");
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, 302, "MathUint: subtract overflow!");
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, 303, "MathUint: multiply overflow!");
    }

}