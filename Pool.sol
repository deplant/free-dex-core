pragma ton-solidity >= 0.36.0;

/// @title Melnorme\Pool
/// @author Augual.Team
/// @notice Contract for providing liquidity to pool and trading. In the same time it's a root contract for Liquidity token

import "math/SafeUint.sol";
import "tip3/LiquidityRoot.sol";
import "DexTypes.sol";

/// NOTE: ALWAYS CHECK:
/// 1. Who is sending the message (msg.sender)
/// 2. Who is owner of the message (msg.pubkey)
/// 3. What contract on the other end of the line? (All TIP-3 wallet interactions should check that it resolves against TIP-3 root)
/// 4. Sufficient gas
/// 5. Sufficient token or gram balance (if applicable)
/// 6. Replay attacks (if applicable)

contract PairPool is DexTypes, LiquidityRoot /*, ITokenWallet */ {
    using SafeUint for uint;

    /*
     * Attributes
     */
   
    // Static 
    address static vaultAddr;
    address static tokenA;
    address static tokenB;
    address static dexWalletA;
    address static dexWalletB;    
   
    uint128 balanceA; // real balance (token A)
    uint128 balanceB; // real balance (token B)
    uint128 balanceK; // K = A*B

    uint128 virtualA;
    uint128 virtualB;
    uint128 virtualK;    

    uint128 baseFee; // real order gets virtual fee, not this one
    uint128 minLiquidity;

    bool closed; // is pool closed? Closed Pool doesn't accept trades on its pair

    // Constant of minimum liquidity for trades
    //uint public constant MINIMUM_LIQUIDITY = 10**3;

    /*
     * Modifiers
     */

    // Modifier for user functions
    // It accepts both internal and external messages
    // At the end, sends back gas if value was attached
    modifier forUsers {

      if (msg.sender != address(0)) {
        tvm.rawReserve(math.max(start_gas_balance, address(this).balance - msg.value), 2); 
      }
      else if (msg.pubkey() != 0) {      
        tvm.accept();        
      }
      else {
        tvm.revert(ERROR_NOT_AUTHORIZED);
      }

      _;

      if (msg.sender != address(0)) {
          msg.sender.transfer({ value: 0, flag: 128 }); 
      }      
    }

    // Modifier that requires sender to be our Vault
    modifier vaultOnly() {
        require(msg.sender != address(0) && msg.sender == vaultAddr, ERROR_NOT_AUTHORIZED);
        _;
    }    



    /*
     * Internal functions
     */

    // checks sender's TIP3 wallet for correctness
    function checkSenderTIP3(TIP3 _token) internal pure returns (address)  {
        return expectedAddress(msg.pubkey(),_token.ttwCode);
    }

    /*
     * Public functions
     */

    /// @dev Contract constructor.
    constructor(uint128 _baseFee,
                bytes _name,
                bytes _symbol,
                uint8 _decimals,
                TvmCell _wallet_code
                ) public vaultOnly {
        // REQUIRE creator IS factory
        // REQUIRE permitted creator
        //tokenA = _tokenA;
        //tokenB = _tokenB;

        // REQUIRE token1 to be TIP-3
        // REQUIRE token2 to be TIP-3 
        // REQUIRE get_address(this,token1,token2,msg.pubkey())  - sends bounce on this address to check

        // accept token1 address
        // accept token2 address
                
        root_public_key = 0;
        root_owner_address = msg.sender;

        total_supply = 0;
        paused = false;

        start_gas_balance = address(this).balance;

        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        wallet_code = _wallet_code;

        baseFee = _baseFee;

     }

/**
* @notice Method to provide liquidity to the pool and receive liquidity tokens
* @param _tokenA [amount0, amount1] for liquidity provision (each amount sorted by token0 and token1) 
* @param _tokenB [amount0, amount1] for liquidity provision (each amount sorted by token0 and token1) 
* @param _amountA [amount0, amount1] for liquidity provision (each amount sorted by token0 and token1) 
* @param _amountB [amount0, amount1] for liquidity provision (each amount sorted by token0 and token1) 
* @return liqResult received liquidity token amount
* @return liqWallet received liquidity address
*/
 function provide(address _tokenA, address _tokenB, uint128 _amountA, uint128 _amountB, address _walletA, address _walletB) external forUsers 
    returns(uint128 liqResult, address liqWallet) {

        // check enough value with message!!!
        require(msg.value >= TOKEN_IMPORT_FEE || 
                (msg.pubkey() != address(0) && address(this).balance >= TOKEN_IMPORT_FEE)
        , DexTypes.ERROR_NOT_ENOUGH_VALUE
        );

        // Can't start a pair with empty amounts
        require(_amountA > 0 && _amountB > 0, DexTypes.ERROR_ZERO_AMOUNT);

        // reorder pair, so impossible to create reverse pair pool
        (address rootAddrA, address rootAddrB) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
        //(TIP3 tokA, TIP3 tokB) = _tokenA < _tokenB ? (tokenA, tokenB) : (tokenB, tokenA);        
        (uint128 amountA, uint128 amountB) = _tokenA < _tokenB ? (_amountA, _amountB) : (_amountB, _amountA);
        (uint128 walletA, uint128 walletB) = _tokenA < _tokenB ? (_walletA, _walletB) : (_walletB, _walletA);        

        // tokens should correspond to pool
        require(tokenA.rootAddr == rootAddrA && tokenB.rootAddr == rootAddrB, DexTypes.ERROR_UNKNOWN_TOKEN);

        // IMPORTANT!
        //Use tokenA, tokenB from this point, not underscored, as they are already reordered

        //address senderWalletA = checkSenderTIP3(tokA); 
        //address senderWalletB = checkSenderTIP3(tokB);

 // WRONG! ADDRESS SHOULD BE DEX WALLET, NOT ROOT
    ITONTokenWallet(walletA).approve(dexWalletA, 0, amountA);
    ITONTokenWallet(walletA).internalTransferFrom(dexWalletA, amountA) ;

    ITONTokenWallet(walletB).approve(dexWalletB, 0, amountB);
    ITONTokenWallet(walletB).internalTransferFrom(dexWalletB, amountB) ;

        balanceA  += amountA;
        balanceB  += amountB;   
        balanceK = balanceA * balanceB;

        liqResult = amountA * amountB;

       // deploys a wallet of provider
      // and mints some liqToken to it
        liqWallet =            deployWallet(liqResult,
                                            0.5 ton,
                                            msg.pubkey(), // public key of provider
                                            address(0), // owner is empty
                                            address(this) // gas back to this contract
                                            );
 }


   // Swap operation is made using the best chain of tokens and pools through Dijkstra's algorithm
   // https://en.wikipedia.org/wiki/Dijkstra%27s_algorithm   
   // Implementation algorithm: 
   // THE IMPLICIT PATH COST OPTIMIZATION IN DIJKSTRA ALGORITHM USING HASH MAP DATA STRUCTURE
   // authors: Mabroukah Amarif,  Ibtusam Alashoury
   // February, 2019
   // TODO: NFT Support
/**
* @param src token address that will be sent to DEX
* @param dst token address that will be received by Trader
* @param srcAmount amount to sell (you can specify only sell or only buy)
* @param dstAmount amount to buy (you can specify only sell or only buy)
* @param minReturn minimal amount that will be received/sent (if result < minReturn then transaction fails)
* @param referral 1/20 from LP fees will be minted to referral wallet address (in liquidity token) (in case of address(0) no mints) 
* @return result received amount
*/
  function swap(uint128 srcAmount, uint128 dstAmount, address src, address dst, uint128 minReturn, address referral) external returns(uint256 result) {

    // определ
    //unit128 sellAmount = uniBalanceOf(address(this)).sub(src.isETH() ? msg.value : 0),

    // balanceA.sub(amount)
    // balanceB.sub()

      //  if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
      //  if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens

  //address providerAddr;
  //providerAddr.check(msg.pubkey(), tokenA.code);

   // !!! sell tokenA

    // seller_pays_tokenA_amount = x    
    // tokenA_new_pool = tokenA_old_pool + x
    // tokenB_new_pool = tokenA_old_pool * tokenB_old_pool / ( tokenA_old_pool + x - x * SWAP_FEE)
    // seller_receives_tokenB_amount = tokenB_old_pool - tokenB_new_pool

    // !!! buy tokenA

    // buyer_receives_tokenA_amount = x
    // tokenA_new_pool = tokenA_old_pool - x
    // tokenB_new_pool = tokenA_old_pool * tokenB_old_pool / (tokenA_old_pool - x  - x * SWAP_FEE)
    // buyer_pays_tokenB_amount = tokenB_new_pool - tokenB_old_pool 

    // emit Swapped

}

/**
* @dev withdraw liquidity from the pool
* @param amount amount to burn in exchange for underlying tokens
* @param minReturns minimal amounts that will be transferred to sender address in underlying tokens  (each amount sorted by token0 and token1) 
*/
// function withdraw(uint256 amount, uint256[] memory minReturns) external {}

 /// function for staking 
 /// You're transferring funds to DePool, they will still be counted as your liquidity because you can't transfer them anywhere
 /// You can vote with these funds through DePool too
 // stake

 //  events
 




}

