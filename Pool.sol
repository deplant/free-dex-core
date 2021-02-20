pragma ton-solidity >= 0.36.0;

/// @title Melnorme\Pool
/// @author Augual.Team

import "MathUint.sol";
import "IDexData.sol";
import "ITokenWallet.sol";


/// NOTE: ALWAYS CHECK:
/// 1. Who is sending the message (msg.sender)
/// 2. Who is owner of the message (msg.pubkey)
/// 3. What contract on the other end of the line? (All TIP-3 wallet interactions should check that it resolves against TIP-3 root)
/// 4. Sufficient gas
/// 5. Sufficient token or gram balance (if applicable)
/// 6. Replay attacks (if applicable)

contract PairPool is IDexData /*, ITokenWallet */ {
    using MathUint for uint;

    /*
     * Attributes
     */

    /*    Exception codes:   */
    uint16 constant ERROR_WRONG_TOKEN    = 151; // There is no such token in this pair
    //uint16 constant ERROR_NOT_A_CONTRACT    = 102; // Not internal  
    //uint16 constant ERROR_NOT_A_USER_WALLET = 103; // Not wallet         

    // Constructor-time variables
    Tip3 tokenA;
    Tip3 tokenB;

    address static public vaultAddr; // Factory that created Trinity

    bool closed; // is pool closed? Closed Pool doesn't accept trades on its pair

    // Constant of minimum liquidity for trades
    //uint public constant MINIMUM_LIQUIDITY = 10**3;

    /*
     * Modifiers
     */

    // Modifier that allows function to accept external call only if it was signed
    // with contract owner's public key.
    modifier requireKey {
        // Check that inbound message was signed with owner's public key.
        // Runtime function that obtains sender's public key.
        require(msg.pubkey() == tvm.pubkey(), 100);

        // Runtime function that allows contract to process inbound messages spending
        // its own resources (it's necessary if contract should process all inbound messages,
        // not only those that carry value with them).
        tvm.accept();
        _;
    }

    // Modifier that requires sender to have contract
    modifier vaultOnly() {
        require(msg.sender != address(0) && msg.sender == vaultAddr);
        _;
    }    



    /*
     * Internal functions
     */

    // function to check
    function _expectedAddress(uint256 _walletPubkey, address _token) private view returns (address)  {

        require(tokenA.rootAddr== _token || tokenB.rootAddr== _token, ERROR_WRONG_TOKEN);

        TvmCell signedCode;

        if (tokenA.rootAddr== _token) {
            signedCode = tvm.insertPubkey(tokenA.ttwCode, _walletPubkey); // insert contragent pubkey to stateInit
 
        } else {
            signedCode = tvm.insertPubkey(tokenB.ttwCode, _walletPubkey); // insert contragent pubkey to stateInit
        }
        TvmCell stateInit = tvm.buildStateInit({ code:signedCode}); // build it
        return address(tvm.hash(stateInit)); // return address for verification
    }



    /*
     * Public functions
     */

    /// @dev Contract constructor.
    constructor(Tip3 _tokenA, Tip3 _tokenB) public vaultOnly {
        // REQUIRE creator IS factory
        // REQUIRE permitted creator
        tokenA = _tokenA;
        tokenB = _tokenB;

        // REQUIRE token1 to be TIP-3
        // REQUIRE token2 to be TIP-3 
        // REQUIRE get_address(this,token1,token2,msg.pubkey())  - sends bounce on this address to check

        // accept token1 address
        // accept token2 address


     }

/// function for providing liquidity
 function provide() public {
    //ITokenWallet(acc.addr).getBalance_InternalOwner{value: 0, flag: 64, bounce: true} (tvm.functionId(onGetBalance));
 }


 /// function for staking 
 /// You're transferring funds to DePool, they will still be counted as your liquidity because you can't transfer them anywhere
 /// You can vote with these funds through DePool too
 // stake

 //  events

}

