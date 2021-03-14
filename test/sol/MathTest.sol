pragma ton-solidity >=0.38.2;

library B {     

    function B2(uint128 value) public pure returns (uint128) {        
        return 20;
    }     

    // GOOD
    function B1(uint128 amountIn) public pure returns (uint128 outAmountX, uint128 outAmountY) {
        outAmountX = 10;
        outAmountY = B2(10);
    }   
}

contract A {

    struct SomeVal {
        uint128 amountX; 
        uint128 amountY;
    }       

    mapping(uint256 => SomeVal) list1_;    

    function func1(address _tokenAddress, uint256 _senderKey, address _senderOwner, uint128 _tokens) public {
        list1_.add(_senderKey,SomeVal(uint128(10),uint128(20)));
        SomeVal trans = list1_.fetch(_senderKey).get();
        (trans.amountX, trans.amountY) = B.B1(10);
    }          

}