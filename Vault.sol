pragma ton-solidity >= 0.36.0;

/// @title Melnorme\Vault
/// @author Augual.Team
/// @notice Contract for managing new tokens and pool deployment

import "math/SafeUint.sol";
import "DexTypes.sol";
import "Pool.sol";
//import "RootTokenContract.sol";

/// NOTE: ALWAYS CHECK:
/// 1. Who is sending the message (msg.sender)
/// 2. Who is owner of the message (msg.pubkey)
/// 3. What contract on the other end of the line? (All TIP-3 wallet interactions should check that it resolves against TIP-3 root)
/// 4. Sufficient gas
/// 5. Sufficient token or gram balance (if applicable)
/// 6. Replay attacks (if applicable)

interface ICommonRootTokenContract {

    function deployEmptyWallet( uint128 grams,
                                uint256 wallet_public_key_,
                                address owner_address_,
                                address gas_back_address
                              ) external;
}    

contract Vault is DexTypes {
    using SafeUint for uint;
    //using SafeTIP3 for address;

    /*
     * Attributes
     */


    TvmCell static liqWalletCode;
    TvmCell static poolCode;     

    address governanceAddr;
    uint128 initialBalance;

    uint128 fee = 3000; // fee divisor for sum (1/MAX_FEE)

    mapping(address  => address) tokens; // key - root, value - wallet

    /*
     * Modifiers
     */

    // Modifier for user functions
    // It accepts both internal and external messages
    // At the end, sends back gas if value was attached
    modifier forUsers {

      if (msg.sender != address(0)) {
        tvm.rawReserve(math.max(initialBalance, address(this).balance - msg.value), 2); 
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

    // Modifier for governance functions
    // It checks for owner public key until governance is deployed,
    // then it accepts only governance' decisions
    // At the end, sends back gas if value was attached
    modifier governorOnly {

      if (governanceAddr != address(0)) {
        require(msg.sender == governanceAddr, DexTypes.ERROR_NOT_AUTHORIZED);
        tvm.rawReserve(math.max(initialBalance, address(this).balance - msg.value), 2); 
      }
      else {
        require(msg.pubkey() != 0 && msg.pubkey() == tvm.pubkey(), DexTypes.ERROR_NOT_AUTHORIZED);
        tvm.accept();
      }

      _;

      if (msg.sender != address(0)) {
          msg.sender.transfer({ value: 0, flag: 128 }); 
      }    

    }    

    /*
     * Internal functions
     */    

    /*
     * Public functions
     */

    /// @dev Contract constructor.
    constructor() public {
      tvm.accept();      
      initialBalance = address(this).balance;
     }

   // Adding a new TIP-3 token to the map
   // RIGHTS: GOVERNOR, INTERNAL+EXTERNAL
   // Can be created by usual users via UserDebot   
   function addToken(address _rootAddr) external forUsers {

        // check enough value with message!!!
        //require(msg.value >= TOKEN_IMPORT_FEE, DexTypes.ERROR_NOT_ENOUGH_VALUE);

       // deploy DEX TTW for this token with 0 balance
       address walletAddr = ICommonRootTokenContract(_rootAddr).deployEmptyWallet{value: TOKEN_IMPORT_FEE}(
        WALLET_DEPLOY_FEE,
        0, // no public key of user
        address(this), // owner is DEX
        msg.sender != address(0) ? msg.sender : address(this) // gas back to invoker
    );

       tokens.add(_rootAddr, walletAddr);

       // emit tokenAdded // event
   }

   // Check token info by its address
   // RIGHTS: NO, INTERNAL+EXTERNAL
   //function getToken(address _token) public view returns (TIP3 tokenInfo) {
   //  tokenInfo = tokens[_token];
   //}

   // getTokens
  /*function getTokens() public view returns (address[] tokenAddress, bytes[] symbol, bytes[] name) {
    optional(address, TIP3) minToken = tokens.min();
    if (minToken.hasValue()) {
      (address key, TIP3 value) = minToken.get();
      tokenAddress.push(key);
      symbol.push(value.symbol);
      name.push(value.name);
      while(true) {
        optional(address, TIP3) nextToken = tokens.next(key);
        if (nextToken.hasValue()) {
          (address nextKey, TIP3 nextValue) = nextToken.get();
          tokenAddress.push(nextKey);
          symbol.push(nextValue.symbol);
          name.push(nextValue.name);
          key = nextKey;
        } else {
          break;
        }
      }
    }
  }   */

 
   /// Function for deployment of pair pools
   // Can be created by usual users via UserDebot
   function deploy(address _tokenA, address _tokenB) external requireKey returns(address outPool) {

        // check enough value with message!!!
        require(msg.value >= POOL_DEPLOY_FEE, DexTypes.ERROR_NOT_ENOUGH_VALUE);

        // token addresses can't be empty
        require(_tokenA != address(0) && _tokenB != address(0), DexTypes.ERROR_ZERO_ADDRESS);

        // tokens can't be the same token
        require(_tokenA != _tokenB, DexTypes.ERROR_IDENTICAL_TOKENS);

        // tokens should be added previously to create pair on them
        //require(tokens.exists(_tokenA) && tokens.exists(_tokenB), DexTypes.ERROR_UNKNOWN_TOKEN);

        // reorder pair, so impossible to create reverse pair pool
        (address tokenA, address tokenB) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);

        // !!IMPORTANT!!
        // !!Using tokenA, tokenB from this point, not underscored, as they are already reordered

        // this pair pool shouldn't exist
        //require(pools[tokenA][tokenB] == address(0), DexTypes.ERROR_PAIR_EXISTS);  
        
        // retrieve structures
        //TIP3 tokA = tokens[tokenA];
        //TIP3 tokB = tokens[tokenB];

        string poolName = "DEX Liquidity {".append(tokA.symbol).append("-").append(tokB.symbol).append("}");
        string poolSymbol = "DX-".append(tokA.symbol).append("-").append(tokB.symbol);

        //TvmCell stateInit = tvm.buildStateInit({varInit: {  name: poolName,
       //               symbol: poolSymbol,
        //              decimals: 9,
        //              code: tokLiq.ttwCode }, pubkey: tvm.pubkey(), code: liqRootCode});
        //tvm.deploy(stateInit, TvmCell payload, TOKEN_IMPORT_FEE, 0) returns(address);

        // deploy pair pool contract
        address poolAddr  = new PairPool {
          code: poolCode,
          value: POOL_CONTRACT_FEE,
          pubkey: tvm.pubkey(),
          varInit: {vaultAddr: address(this) , tokenA: tokenA, tokenB: tokenB, dexWalletA: tokens[tokenA], dexWalletB: tokens[tokenB]}
          }(); // constructor params

        pools[tokenA][tokenB] = poolAddr;
        pools.push(poolAddr);

        // проверки
        // запись в мапу
        // tvm.accept

        /*emit Deployed(
            poolAddr,
            tokenA,
            tokenB
        );*/

        return poolAddr;

   }


  function updateFee(uint16 newFee) external governorOnly {
      require(newFee > 0, DexTypes.ERROR_WRONG_VALUE);
      fee = newFee;
  }     

  function updatePoolCode(TvmCell _cell, uint256 cellHash) external governorOnly {
    require(cellHash == tvm.hash(_cell), ERROR_WRONG_CODE_CRC);
    poolCode = _cell;
  }

  function updateLiqWalletCode(TvmCell _cell, uint256 cellHash) external governorOnly {
    require(cellHash == tvm.hash(_cell), ERROR_WRONG_CODE_CRC);
    liqWalletCode = _cell;
  }     

  function deployGovernance(address _govAddress) external governorOnly {
    require(_govAddress != 0, ERROR_WRONG_VALUE);
    governanceAddr = _govAddress;
  }     

    /// Function for collecting Dex income
    // collect //requires owner or governance decision

    // deploy SMV Governance system
    // adds governance address as root
    // make additional checks
    // Can be deployed by owner via OwnerDebot

    // Second set of all main functions via SMV governance contract (addToken, deployPool and so on)
    // SMV function to destroy owner?

    // events

}

