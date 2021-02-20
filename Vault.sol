pragma ton-solidity >= 0.36.0;

/// @title Melnorme\Vault
/// @author Augual.Team

import "MathUint.sol";
import "IDexData.sol";
import "Pool.sol";

/// NOTE: ALWAYS CHECK:
/// 1. Who is sending the message (msg.sender)
/// 2. Who is owner of the message (msg.pubkey)
/// 3. What contract on the other end of the line? (All TIP-3 wallet interactions should check that it resolves against TIP-3 root)
/// 4. Sufficient gas
/// 5. Sufficient token or gram balance (if applicable)
/// 6. Replay attacks (if applicable)

contract Vault is IDexData {
    using MathUint for uint;

    /*
     * Attributes
     */

    /*    Exception codes:   */
    uint16 constant ERROR_NOT_AUTHORIZED        = 101; // Not authorized    
    uint16 constant ERROR_NOT_A_CONTRACT        = 102; // Not internal  
    uint16 constant ERROR_PAIR_NOT_SPECIFIED    = 103; // No pair specified        
    uint16 constant ERROR_ZERO_ADDRESS          = 104; // Empty address
    uint16 constant ERROR_IDENTICAL_TOKENS      = 105; // Both tokens in pair are identical   
    uint16 constant ERROR_UNKNOWN_TOKEN         = 106; // This token is not imported to DEX
    uint16 constant ERROR_PAIR_EXISTS           = 107; // This pair already deployed                  

    /// Constants
    uint64 constant DEX_QUERY_FEE = 0.02 ton;    
    uint64 constant DEX_POOL_DEPLOY_FEE = 1 ton + DEX_QUERY_FEE;
    uint64 constant MINIMUM_LIQUIDITY = 100;

    address governanceAddr;
    TvmCell poolCode;

    mapping(address => Tip3) tokens;

    mapping(address => mapping(address => address)) public getPool;
    address[] public pools;

    // Constant of minimum liquidity for trades
    //uint public constant MINIMUM_LIQUIDITY = 10**3;

    /*
     * Modifiers
     */

    // Modifier that allows function to accept external call only if it was signed
    // with contract owner's public key.
    modifier requireKey {

		    require(tvm.pubkey() != 0, ERROR_NOT_AUTHORIZED);      
        // Check that inbound message was signed with owner's public key.
        // Runtime function that obtains sender's public key.
        require(msg.pubkey() == tvm.pubkey(), ERROR_NOT_AUTHORIZED);

        // Runtime function that allows contract to process inbound messages spending
        // its own resources (it's necessary if contract should process all inbound messages,
        // not only those that carry value with them).
        tvm.accept();
        _;
    }

    // Modifier for checking owner or governance
    modifier governorOnly {

		    require(tvm.pubkey() != 0, ERROR_NOT_AUTHORIZED);       
        require(
        msg.pubkey() == tvm.pubkey() || 
        (msg.sender != address(0) && msg.sender == governanceAddr)
        , ERROR_NOT_AUTHORIZED);

        if (msg.sender == address(0)) {
        tvm.accept();
        }
        _;
    }    

    // Modifier that requires sender to have contract
    modifier contractOnly() {
        require(msg.sender != address(0), ERROR_NOT_A_CONTRACT);
        tvm.accept();        
        _;
    }

/// function modifier for logging
    modifier _logs_() {
        emit log(msg.sig, msg.sender);
        _;
    }

/// For future event logging
    event log(
        bytes4  indexed sig,
        address indexed caller
    ) anonymous;    


    /*
     * Internal functions
     */    

    // mint - mint liq token
    // burn - burn liq token
    // swap - swap liq token

    /*
     * Public functions
     */

    /// @dev Contract constructor.
    constructor() public requireKey {
     }

   // Adding a new TIP-3 token to the map
   // RIGHTS: GOVERNOR, INTERNAL+EXTERNAL
   // Can be created by usual users via UserDebot   
   function addToken(bytes _name, bytes _symbol, uint8 _decimals, address _rootAddr, uint256 _rootKey, TvmCell _ttwCode) public governorOnly {

       tokens.add(_rootAddr, Tip3(_name, _symbol, _decimals, _rootAddr, _rootKey, _ttwCode, 0));

       // emit tokenAdded // event
   }

   // Check token info by its address
   // RIGHTS: NO, INTERNAL+EXTERNAL
   function getToken(address _token) public view returns (Tip3 tokenInfo) {
     tokenInfo = tokens[_token];
   }

   // getTokens
  function getTokens() public view returns (address[] tokenAddress, bytes[] symbol, bytes[] name) {
    optional(address, Tip3) minToken = tokens.min();
    if (minToken.hasValue()) {
      (address key, Tip3 value) = minToken.get();
      tokenAddress.push(key);
      symbol.push(value.symbol);
      name.push(value.name);
      while(true) {
        optional(address, Tip3) nextToken = tokens.next(key);
        if (nextToken.hasValue()) {
          (address nextKey, Tip3 nextValue) = nextToken.get();
          tokenAddress.push(nextKey);
          symbol.push(nextValue.symbol);
          name.push(nextValue.name);
          key = nextKey;
        } else {
          break;
        }
      }
    }
  }   

  function addPoolCode(TvmCell _cell) external governorOnly {
    poolCode = _cell;
  }
 
   /// Function for deployment of pair pools
   // Can be created by usual users via UserDebot
   function deploy(address _tokenA, address _tokenB) public requireKey returns(address outPool) {

        // token addresses can't be empty
        require(_tokenA != address(0) && _tokenB != address(0), ERROR_ZERO_ADDRESS);

        // tokens can't be the same token
        require(_tokenA != _tokenB, ERROR_IDENTICAL_TOKENS);

        // tokens should be added previously to create pair on them
        require(tokens.exists(_tokenA) && tokens.exists(_tokenB), ERROR_UNKNOWN_TOKEN);

        // reorder pair, so impossible to create reverse pair pool
        (address tokenA, address tokenB) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);

        // IMPORTANT!
        //Use tokenA, tokenB from this point, not underscored, as they are already reordered

        // this pair pool shouldn't exist
        require(getPool[tokenA][tokenB] == address(0), ERROR_PAIR_EXISTS);     
        
        // тащим структуру Tip3 для использования в Pool
        Tip3 tokA = tokens[tokenA];
        Tip3 tokB = tokens[tokenB];

        // засовываем ключи
        //TvmCell signedCode = tvm.insertPubkey(poolCode, tvm.pubkey());
        //TvmCell stateInit1 = tvm.buildStateInit({contr: Pool, varInit: {_tokenA: tokA, _tokenB: tokB}, pubkey: tvm.pubkey(), code: poolCode});

        address poolAddr  = new PairPool {
          code: poolCode,
          value: DEX_POOL_DEPLOY_FEE,
          pubkey: tvm.pubkey(),
          varInit: {vaultAddr: address(this)}
          } (tokA, tokB); // constructor params

        getPool[tokenA][tokenB] = poolAddr;
        pools.push(poolAddr);

        // проверки
        // запись в мапу
        // tvm.accept

        return poolAddr;
        //return address(0);

        // emit tokenAdded // event

   }
   
   // getPools

   // getPairPrice
   // getPairLiquidity
   
   // Swap operation is made using the best chain of tokens and pools through Dijkstra's algorithm
   // https://en.wikipedia.org/wiki/Dijkstra%27s_algorithm   
   // Implementation algorithm: 
   // THE IMPLICIT PATH COST OPTIMIZATION IN DIJKSTRA ALGORITHM USING HASH MAP DATA STRUCTURE
   // authors: Mabroukah Amarif,  Ibtusam Alashoury
   // February, 2019
   // TODO: NFT Support
/**
* @param src address of the source token to exchange
* @param dst token address that will received
* @param amount amount to exchange
* @param minReturn minimal amount of the dst token that will receive (if result < minReturn then transaction fails)
* @param referral 1/20 from LP fees will be minted to referral wallet address (in liquidity token) (in case of address(0) no mints) 
* @return result received amount
*/
  // function swap(address src, address dst, uint256 amount, uint256 minReturn, address referral) external requireKey returns(uint256 result) {}

/**
* @dev provide liquidity to the pool and earn on trading fees
* @param amounts [amount0, amount1] for liquidity provision (each amount sorted by token0 and token1) 
* @param minAmounts minimal amounts that will be charged from sender address to liquidity pool (each amount sorted by token0 and token1) 
* @return fairSupply received liquidity token amount
*/
// function deposit(uint256[] calldata amounts, uint256[] calldata minAmounts) external requireKey returns(uint256 fairSupply) {}

/**
* @dev withdraw liquidity from the pool
* @param amount amount to burn in exchange for underlying tokens
* @param minReturns minimal amounts that will be transferred to sender address in underlying tokens  (each amount sorted by token0 and token1) 
*/
// function withdraw(uint256 amount, uint256[] memory minReturns) external {}

    /// Function for collecting Dex income
    // collect //requires owner or governance decision

    // deploy SMV Governance system
    // adds governance address as root
    // make additional checks
    // Can be deployed by owner via OwnerDebot

    // Second set of all main functions via SMV governance contract (addToken, deployPool and so on)
    // SMV function to destroy owner?

    // events
	
    // Function to receive plain transfers.
    receive() external {
    }
}

