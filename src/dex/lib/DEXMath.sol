pragma ton-solidity >= 0.38.2;

/// @title LiquiSOR\DEXMath
/// @author laugan
/// @notice Library for all DEX internal math operations.

library DEXMath {     

    uint128 constant MIN_TOKEN_AMOUNT = 100; 
    uint16 constant ERROR_ADDITION_OVERFLOW         = 300;
    uint16 constant ERROR_SUBTRACTION_OVERFLOW      = 301;
    uint16 constant ERROR_MULTIPLY_OVERFLOW         = 302;    

    /**
    * @notice x + y; checks addition for overflow
    */
    function add(uint128 x, uint128 y) internal pure returns (uint128 z) {
        require((z = x + y) >= x, 301, ERROR_ADDITION_OVERFLOW);
        z = x + y;
    }

    /**
    * @notice x - y; checks subtraction for overflow
    */
    function sub(uint128 x, uint128 y) internal pure returns (uint128 z) {
        require((z = x - y) <= x, 302, ERROR_SUBTRACTION_OVERFLOW);
        z = x - y;
    }

    function mul(uint128 x, uint128 y) internal pure returns (uint128 z) {
        require(y == 0 || (z = x * y) / y == x, 303, ERROR_MULTIPLY_OVERFLOW);
        z = x * y;
    }    
   
    //GOOD
    function priceSwap(uint128 amountIn , uint128 balanceIn, uint128 balanceOut, uint128 fee) internal pure returns (uint128) {
        return  sub(balanceOut,
                    math.muldiv(balanceIn, 
                                balanceOut,   
                                sub(
                                    add(balanceIn,amountIn),
                                    mul(amountIn, fee) 
                                    ) 
                                ) 
                   );
    }     

    // GOOD
    function calcOtherToken(uint128 inAmount, uint128 inBalance, uint128 outBalance) internal pure returns (uint128) {        
        return math.muldiv(outBalance, inAmount, inBalance);
    }        

    // GOOD
    function tokensToLiq(uint128 inAmountX, uint128 inAmountY) internal pure returns (uint128) {
        return mul(inAmountX, inAmountY); 
    }     

    // GOOD
    function liqToTokens(uint128 amountIn, uint128 supplyIn, uint128 balanceX, uint128 balanceY) internal pure returns (uint128 outAmountX, uint128 outAmountY) {
        outAmountX = math.muldiv(amountIn, balanceX, supplyIn);
        outAmountY = calcOtherToken(outAmountX, balanceX, balanceY);
    }   

    // GOOD
    function minDeposit(uint128 balanceX, uint128 balanceY) internal pure returns (uint128 outAmountX, uint128 outAmountY) {
        (outAmountX, outAmountY) = (balanceX > balanceY) ? 
        (math.muldivc(MIN_TOKEN_AMOUNT, balanceX, balanceY), MIN_TOKEN_AMOUNT) : 
        (MIN_TOKEN_AMOUNT, math.muldivc(MIN_TOKEN_AMOUNT, balanceY, balanceX));
    }      

    function minWithdrawLiq(uint128 supplyIn, uint128 balanceX, uint128 balanceY) internal pure returns (uint128) {
       return (balanceX > balanceY) ? 
       math.muldivc(MIN_TOKEN_AMOUNT, supplyIn, balanceY) : 
       math.muldivc(MIN_TOKEN_AMOUNT, supplyIn, balanceX);   
    }                 

}