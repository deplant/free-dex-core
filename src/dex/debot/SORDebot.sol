pragma ton-solidity >= 0.38.2;

/// @title LiquiSOR\SORDebot
/// @author laugan
/// @notice Debot for customer and liquidity provider interations.

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

//================================================================================
//
import "../../dex/lib/DEX.sol";
import "../../std/debot/Debot.sol";
import "../../std/debot/Terminal/Terminal.sol";
import "../../std/debot/AddressInput/AddressInput.sol";
import "../../std/debot/NumberInput/NumberInput.sol";
import "../../dex/int/IDEXPool.sol";
import "../../dex/int/IDEXRoot.sol";
import "../../tip3/int/ITIP3Root.sol";
import "../../tip3/int/ITIP3Wallet.sol";

//================================================================================
//

contract SORDebot is Debot 
{
    address static dexAddress;
    address constant ZERO_ADDRESS   = address.makeAddrStd(0, 0);    
    uint128 constant USAGE_FEE       = 0.1 ton;    

    enum State { NONE, TIP3_VIEW_BALANCE , TIP3_TRANSFER , TIP3_APPROVE , DEX_VIEW, DEX_DEPOSIT, DEX_SWAP, DEX_WITHDRAW }

    optional(uint256) pk;

    // Account Context - exists until account change
    uint256 userPubkey_;
    address userRoot_;
    ITIP3RootMetadata.TokenDetails userTokenDetails_;
    address userWallet_;    

    // User Context - restarts in main menu
    State ctx_action;
    address ctx_dest;
    uint128 ctx_tokens;              
    uint128 ctx_grams;
    uint128 ctx_remainingTokens;  
    address ctx_spender;        
    uint128 ctx_balance;
    uint128 ctx_limit; // for minReturn and maxGrab     
    address ctx_swapToken;
    address ctx_pool;         
    address ctx_2ndWallet;
    address ctx_liqWallet; 
    uint128 ctx_liqReturn;          

    //TIP3 userWalletInfo;
    //UserAction userAction;
    ITIP3WalletFungible.AllowanceInfo walletAllowance;
    
	function getRequiredInterfaces() public pure returns (uint256[] interfaces) {
        return [Terminal.ID, AddressInput.ID, NumberInput.ID];
	}
    function getInfo() public pure returns (string name, string version, string publisher, string key, string author, address support, string hello, string language) {
        name = "SORDebot";
        version = "0.1.0";
        publisher = "laugan";
        key = "DeBot for LiquiSOR DEX";
        author = "laugan";
        support = ZERO_ADDRESS;
        hello = "Welcome to SORDebot, a LiquiSOR DEX customer DeBot!";
        language = "en";
    }    

    // @notice Define DeBot version and title here.
    function getVersion() public override returns (string name, uint24 semver) 
    {
        (name, semver) = ("SORDebot", _version(0, 1, 0));
    }

    function _version(uint24 major, uint24 minor, uint24 fix) private pure inline returns (uint24) 
    {
        return (major << 16) | (minor << 8) | (fix);
    }    

    /// @notice Entry point function for DeBot.
    function start() public override 
    {
        Terminal.print(0, "Hello!"); 
        Terminal.print(0, "Welcome to SORDebot, a LiquiSOR DEX customer DeBot."); 
        Terminal.print(0, "Please, specify a PUBLIC key of your wallet. It's needed to sign some LiquiSOR DEX operations.");        
        Terminal.print(0, "Your TIP-3 wallets will also be registered for this key."); 
        Terminal.print(0, "Your can switch between keys in the Main Menu.");          
        mainMenu();
    }

    function saveKey(string value) public {
        (uint256 pubkey, bool status) = stoi(value);
        if (status) 
        {
            userPubkey_ = pubkey;
        }
        mainMenu();
    }

    function saveRoot(address value) public {
        userRoot_ = value;
        ITIP3RootMetadata(userRoot_).getTokenInfo{
                                                    abiVer: 2,
                                                    extMsg: true,
                                                    sign: false,
                                                    time: uint64(now),
                                                    expire: 0,
                                                    pubkey: pk,
                                                    callbackId: tvm.functionId(saveRoot2),
                                                    onErrorId: 0
                                                    }();        
    }

    function saveRoot2(ITIP3RootMetadata.TokenDetails value) public {
        userTokenDetails_ = value;
        mainMenu();        
    }

    function mainMenu() public 
    {
        _eraseCtx();
        if (userPubkey_ == 0) 
        {
            Terminal.input(tvm.functionId(saveKey), "Enter your public key (0xffff... format): ", false);
        } 
        else if (userRoot_ == ZERO_ADDRESS) 
        {
            AddressInput.get(tvm.functionId(saveRoot), "Enter token root address (0:ffff... format): ");
        }
        else if (userWallet_ == ZERO_ADDRESS) { 
            resolveWallet();
        }
        else 
        {
            Terminal.print(0, "MAIN MENU");
            Terminal.print(0, format("KEY: 0x{:x}",userPubkey_)); 
            Terminal.print(0, format("WALLET: 0:{:x}", userWallet_.value));       
            Terminal.print(0, format("SYMBOL: {}", userTokenDetails_.symbol));  
            Terminal.print(0, format("DECIMALS: {} digits", userTokenDetails_.decimals));                                           
            Terminal.print(0, "Choose action...");
            Terminal.print(0, "1)    [Check Balance]"); 
            Terminal.print(0, "2)    [Make transfer]");   
            Terminal.print(0, "3)    [Approve spending]");    
            Terminal.print(0, "4)    [View pair price & volumes]");              
            Terminal.print(0, "5)    [Swap tokens]"); 
            Terminal.print(0, "6)    [Provide liquidity]");   
            Terminal.print(0, "7)    [Withdraw liquidity]");                                  
            Terminal.print(0, "8) <--[Change Account]");                                    
            NumberInput.get(tvm.functionId(onMainMenu), "Enter your choice: ", 1,8);
        }
    }

    function onMainMenu(int256 value) public
    {
        if(value == 1)
        {
            ctx_action = State.TIP3_VIEW_BALANCE;
            tip3BalanceStep1();
        }
        else if(value == 2)
        {
            ctx_action = State.TIP3_TRANSFER;
            AddressInput.get(tvm.functionId(tip3TransferStep1), "Enter destination wallet: ");
        }
        else if(value == 3)
        {
            ctx_action = State.TIP3_APPROVE;
            AddressInput.get(tvm.functionId(tip3ApproveStep1), "Enter spender wallet: ");
        }
        else if(value == 4)
        {
            ctx_action = State.DEX_VIEW;
            checkSwapToken();
        }
        else if(value == 5)
        {
            ctx_action = State.DEX_SWAP;
            checkSwapToken();
        }        
        else if(value == 6)
        {
            ctx_action = State.DEX_DEPOSIT;
            checkSwapToken();
        }
        else if(value == 7)
        {
            ctx_action = State.DEX_WITHDRAW;
            checkSwapToken();
        }     
        else if(value == 8)
        {
            _eraseAcc();
            mainMenu();
        } else 
        {        
            mainMenu();
        }
    }     

    function saveSwapToken(address value) public {
        ctx_swapToken = value;
        checkSwapToken();
    }   

    function checkSwapToken() public {
        if (ctx_swapToken == ZERO_ADDRESS) {
            AddressInput.get(tvm.functionId(saveSwapToken), "Enter 2nd token root address (0:ffff... format): ");
        }
        else if (ctx_pool == ZERO_ADDRESS)
        {
            resolvePool();
        } 
        else 
        {
            if (ctx_action == State.DEX_VIEW)
            {
                dexPoolDetailsStep1();
            }
            else if (ctx_action == State.DEX_SWAP)
            {          
                NumberInput.get(tvm.functionId(dexSwapStep1), "Input tokens to get price: ", 0,999_999_999_999_999_999_999);
            }        
            else if (ctx_action == State.DEX_DEPOSIT)
            {
                NumberInput.get(tvm.functionId(dexDepositStep1), "Input tokens to get amount of second token deposit: ", 0,999_999_999_999_999_999_999);
            }
            else if (ctx_action == State.DEX_WITHDRAW)
            {
                NumberInput.get(tvm.functionId(dexWithdrawStep1), "Input LIQ tokens amount to withdraw: ", 0,999_999_999_999_999_999_999);
            }
            else
            {
                _eraseCtx();
                mainMenu();       
            }
        }
    }   

    // ************************
    // RESOLVE Steps
    // ************************           

    function resolveWallet() public
    {
        ITIP3RootMetadata(userRoot_).getWalletAddress{
                                                    abiVer: 2,
                                                    extMsg: true,
                                                    sign: false,
                                                    time: uint64(now),
                                                    expire: 0,
                                                    pubkey: pk,
                                                    callbackId: tvm.functionId(saveWallet),
                                                    onErrorId: 0
                                                    }(0, userPubkey_, ZERO_ADDRESS);
    }

    function saveWallet(address value) public
    {
        userWallet_ = value;
        mainMenu();
    }    

    function resolvePool() public
    {
        IDEXRoot(dexAddress).getPoolAddress{
                                            abiVer: 2,
                                            extMsg: true,
                                            sign: false,
                                            time: uint64(now),
                                            expire: 0,
                                            pubkey: pk,
                                            callbackId: tvm.functionId(savePool),
                                            onErrorId: tvm.functionId(onDEXError)
                                            }(userRoot_, ctx_swapToken);
    }

    function savePool(address value) public
    {
        ctx_pool = value;
        Terminal.print(0, format("Connected to LiquiSOR Pool: 0:{:x}", ctx_pool.value));        
        checkSwapToken();
    }     

    // ************************
    // DEX_VIEW Steps
    // ************************   

    function dexPoolDetailsStep1() public {
            IDEXPool(ctx_pool).getPoolDetails{
                                            abiVer: 2,
                                            extMsg: true,
                                            sign: false,
                                            time: uint64(now),
                                            expire: 0,
                                            pubkey: pk,
                                            callbackId: tvm.functionId(dexPoolDetailsStep2),
                                            onErrorId: tvm.functionId(onDEXError)
                                            }();    
    }    

    function dexPoolDetailsStep2(IDEXPool.PoolDetails details) public { 
        Terminal.print(0, format("Token 1 Root: 0:{:x}", details.rootX.value));
        Terminal.print(0, format("Token 1 Wallet: 0:{:x}", details.walletX.value));
        Terminal.print(0, format("Token 1 Balance: {}", details.balanceX));
        Terminal.print(0, format("Token 2 Root: 0:{:x}", details.rootY.value));       
        Terminal.print(0, format("Token 2 Wallet: 0:{:x}", details.walletY.value)); 
        Terminal.print(0, format("Token 2 Balance: {}", details.balanceY));
        Terminal.print(0, format("Provider Fee: 0.0{}% of amount", details.providerFee));
        Terminal.print(0, format("Liquidity Token Balance: {}", details.balanceLiq));
        mainMenu();          
    }        

    // ************************
    // DEX_SWAP Steps
    // ************************   

    function dexSwapStep1(uint128 value) public 
    {
        ctx_tokens = value;
        IDEXPool(ctx_pool).getSwapDetails{
                                        abiVer: 2,
                                        extMsg: true,
                                        sign: false,
                                        time: uint64(now),
                                        expire: 0,
                                        pubkey: pk,
                                        callbackId: tvm.functionId(dexSwapStep2),
                                        onErrorId: tvm.functionId(onDEXError)
                                        }(userRoot_, ctx_tokens);    
    }    

    function dexSwapStep2(IDEXPool.OrderDetails details) public 
    { 
        ctx_limit = details.secondParam;
        Terminal.print(0, "Current prices are: ");        
        Terminal.print(0, format("Amount for Spot Price: {}", details.firstParam));
        Terminal.print(0, format("Effective amount (with slippage): {}", details.secondParam));
        if (details.secondParam == 0 || details.firstParam == 0) 
        {
            Terminal.print(0, "Seems that this Liquidity Pool is empty! But you can provide liquidity."); 
            Terminal.print(0, "2)    [Make a DEPOSIT]");             
        } else             
        {
        Terminal.print(0, "1)    [Make a SWAP]");  
        }  
        Terminal.print(0, "3) <--[Back to Main Menu]");                                                                   
        NumberInput.get(tvm.functionId(dexSwapStep3), "Enter your choice: ", 1,3);               
    }   
    function dexSwapStep3(int256 value) public 
    { 
        if (value == 1) 
        {
            dexSwapStep4();
        } else if (value == 2) 
        {
            ctx_action = State.DEX_DEPOSIT;
            checkSwapToken();
        } else 
        {
            mainMenu(); 
        }
    }             

    function dexSwapStep4() public 
    { 
        Terminal.print(0, format("Please, approve spending of {} tokens from wallet: ", ctx_tokens));           
        ITIP3WalletFungible(userWallet_).approve{
                                                abiVer: 2,
                                                extMsg: true,
                                                sign: true,
                                                time: uint64(now),
                                                expire: 0,
                                                pubkey: userPubkey_,
                                                callbackId: 0,
                                                onErrorId: 0
                                                }(ctx_pool, 0, ctx_tokens);  

        Terminal.print(0, "Proceeding SWAP...");                         
        IDEXPool(ctx_pool).swap{
                                abiVer: 2,
                                extMsg: true,
                                sign: true,
                                time: uint64(now),
                                expire: 0,
                                pubkey: userPubkey_,
                                callbackId: 0,
                                onErrorId: tvm.functionId(onDEXError)
                                }(userRoot_, userPubkey_, ZERO_ADDRESS, ctx_tokens, ctx_limit);  
        Terminal.print(0, "Done!");             
        mainMenu();                      
    }           

    // ************************
    // DEX_DEPOSIT Steps
    // ************************   

    function dexDepositStep1(uint128 value) public 
    {
        ctx_tokens = value;
        IDEXPool(ctx_pool).getDepositDetails{
                                            abiVer: 2,
                                            extMsg: true,
                                            sign: false,
                                            time: uint64(now),
                                            expire: 0,
                                            pubkey: pk,
                                            callbackId: tvm.functionId(dexDepositStep2),
                                            onErrorId: 0
                                            }(userRoot_, ctx_tokens);    
    }    

    function dexDepositStep2(IDEXPool.OrderDetails details) public 
    { 
        if (details.firstParam == 0) {
            Terminal.print(0, "Pool is empty! Please, specify second token amount to set initial price."); 
            NumberInput.get(tvm.functionId(dexDepositStep3a), "Enter amount: ", 0,999_000_000_000_000);                         
        } else {
            ctx_limit = details.firstParam;
            ctx_liqReturn = details.secondParam; 
            dexDepositStep3a(int256(details.firstParam));           
        }
    }     

    function dexDepositStep3a(int256 value) public 
    { 
        ctx_limit = uint128(value);        
        ctx_liqReturn = ctx_limit * ctx_tokens;

        Terminal.print(0, "Current conditions are: ");        
        Terminal.print(0, format("Amount of Second Token: {}", ctx_limit));
        Terminal.print(0, format("You will receive Liquidity Tokens: {}", ctx_liqReturn));
        Terminal.print(0, "1)    [Make a DEPOSIT]");                                  
        Terminal.print(0, "2) <--[Main menu]");                                    
        NumberInput.get(tvm.functionId(dexDepositStep3), "Enter your choice: ", 1,2);               
    } 
          

    function dexDepositStep3(int256 value) public 
    { 
        if (value == 1)
        {           
            Terminal.print(0, format("Please, approve spending of {} tokens from wallet of Token 1: ", ctx_tokens));             
            ITIP3WalletFungible(userWallet_).approve{
                                                    abiVer: 2,
                                                    extMsg: true,
                                                    sign: true,
                                                    time: uint64(now),
                                                    expire: 0,
                                                    pubkey: userPubkey_,
                                                    callbackId: 0,
                                                    onErrorId: 0
                                                    }(ctx_pool, 0, ctx_tokens); 
            ITIP3RootMetadata(ctx_swapToken).getWalletAddress{
                                                            abiVer: 2,
                                                            extMsg: true,
                                                            sign: false,
                                                            time: uint64(now),
                                                            expire: 0,
                                                            pubkey: pk,
                                                            callbackId: tvm.functionId(dexDepositStep4),
                                                            onErrorId: 0
                                                            }(0, userPubkey_, ZERO_ADDRESS);                             
        } else 
        {
            mainMenu(); 
        }     
         
    }           
    function dexDepositStep4(address value) public 
    { 
        ctx_2ndWallet = value;
        Terminal.print(0, format("Please, approve spending of {} tokens from wallet of Token 2: ", ctx_limit));         
        ITIP3WalletFungible(ctx_2ndWallet).approve{
                                                abiVer: 2,
                                                extMsg: true,
                                                sign: true,
                                                time: uint64(now),
                                                expire: 0,
                                                pubkey: userPubkey_,
                                                callbackId: 0,
                                                onErrorId: 0
                                                }(ctx_pool, 0, ctx_limit);  
        Terminal.print(0, "Proceeding DEPOSIT...");                       
        IDEXPool(ctx_pool).deposit{
                                    abiVer: 2,
                                    extMsg: true,
                                    sign: true,
                                    time: uint64(now),
                                    expire: 0,
                                    pubkey: userPubkey_,
                                    callbackId: 0,
                                    onErrorId: tvm.functionId(onDEXError)
                                    }(userRoot_, userPubkey_, ZERO_ADDRESS, ctx_tokens, ctx_limit); 
        Terminal.print(0, "Done!");           
        mainMenu();                
    }   

    // ************************
    // DEX_WITHDRAW Steps
    // ************************   

    function dexWithdrawStep1(uint128 value) public 
    {
        ctx_tokens = value;
        IDEXPool(ctx_pool).getWithdrawDetails{
                                            abiVer: 2,
                                            extMsg: true,
                                            sign: false,
                                            time: uint64(now),
                                            expire: 0,
                                            pubkey: pk,
                                            callbackId: tvm.functionId(dexWithdrawStep2),
                                            onErrorId: 0
                                            }(ctx_tokens);    
    }   


    function dexWithdrawStep2(IDEXPool.OrderDetails details) public 
    { 
        Terminal.print(0, "Current conditions are: ");        
        Terminal.print(0, format("You will receive (Token 1): {}", details.firstParam));
        Terminal.print(0, format("You will receive (Token 2): {}", details.secondParam));

            ITIP3RootMetadata(ctx_pool).getWalletAddress{
                                                            abiVer: 2,
                                                            extMsg: true,
                                                            sign: false,
                                                            time: uint64(now),
                                                            expire: 0,
                                                            pubkey: pk,
                                                            callbackId: tvm.functionId(dexWithdrawStep2a),
                                                            onErrorId: 0
                                                            }(0, userPubkey_, ZERO_ADDRESS);             
    } 


    function dexWithdrawStep2a(address value) public 
    {              
        userWallet_ = value;
        Terminal.print(0, "1)    [Do WITHDRAW]");                                  
        Terminal.print(0, "2) <--[Main menu]");                                    
        NumberInput.get(tvm.functionId(dexWithdrawStep3), "Enter your choice: ", 1,2);               
    } 


    function dexWithdrawStep3(int256 value) public 
    { 
        if (value == 1)
        {           
            Terminal.print(0, format("Please, approve spending of {} tokens from wallet of Token LIQ: ", ctx_tokens));             
            ITIP3WalletFungible(userWallet_).approve{
                                                    abiVer: 2,
                                                    extMsg: true,
                                                    sign: true,
                                                    time: uint64(now),
                                                    expire: 0,
                                                    pubkey: userPubkey_,
                                                    callbackId: 0,
                                                    onErrorId: 0
                                                    }(ctx_pool, 0, ctx_tokens); 
            Terminal.print(0, "Proceeding WITHDRAW...");                       
            IDEXPool(ctx_pool).withdraw{
                                        abiVer: 2,
                                        extMsg: true,
                                        sign: true,
                                        time: uint64(now),
                                        expire: 0,
                                        pubkey: userPubkey_,
                                        callbackId: 0,
                                        onErrorId: tvm.functionId(onDEXError)
                                        }(userPubkey_, ZERO_ADDRESS, ctx_tokens); 
            Terminal.print(0, "Done!");           
            mainMenu();                           
        } 
        else 
        {
            mainMenu(); 
        }     
         
    }               


    // ************************
    // BALANCE Steps
    // ************************       

    function tip3BalanceStep1() public
    {
            ITIP3WalletMetadata(userWallet_).getBalance{
                    abiVer: 2,
                    extMsg: true,
                    sign: false,
                    time: uint64(now),
                    expire: 0,
                    pubkey: pk,
                    callbackId: tvm.functionId(tip3BalanceStep2),
                    onErrorId: 0
            }();              
    }      
 

    function tip3BalanceStep2(uint128 balance) public
    {
        ctx_balance = balance;
        Terminal.print(0, format("Balance: {}", balance));  
        ITIP3WalletFungible(userWallet_).allowance{
                abiVer: 2,
                extMsg: true,
                sign: false,
                time: uint64(now),
                expire: 0,
                pubkey: pk,
                callbackId: tvm.functionId(tip3BalanceStep3),
                onErrorId: 0
        }();       
        //tip3BalanceStep3(address(0),0);    
    }         

    function tip3BalanceStep3(ITIP3WalletFungible.AllowanceInfo allowance) public
    {            
        ctx_remainingTokens = allowance.remainingTokens_;
        ctx_spender = allowance.spender_;   
        if (ctx_action == State.TIP3_APPROVE) {
            tip3ApproveStep3();
        } else {
            Terminal.print(0, format("Allowed tokens: {}", ctx_remainingTokens));  
            Terminal.print(0, format("Allowed spender: 0:{:x}", ctx_spender.value));            
            mainMenu();     
        }
         
    }          

    // ************************
    // TRANSFER Steps
    // ************************    

    function tip3TransferStep1(address value) public 
    {
        ctx_dest = value;       
        NumberInput.get(tvm.functionId(tip3TransferStep2), "How much TIP3 tokens: ", 0,999_999_999_999_999_999_999);
    }  

    function tip3TransferStep2(uint128 value) public {
        ctx_grams = 1000000000;          
        ITIP3WalletFungible(userWallet_).transfer{
                abiVer: 2,
                extMsg: true,
                sign: true,
                time: uint64(now),
                expire: 0,
                pubkey: userPubkey_,
                callbackId: 0,
                onErrorId: 0
        }(ctx_dest, ctx_tokens, 0.1 ton);
        _eraseCtx();
        tip3BalanceStep1();  
    }

    // ************************
    // APPROVE Steps
    // ************************      

    function tip3ApproveStep1(address value) public 
    {
        ctx_dest = value;       
        NumberInput.get(tvm.functionId(tip3ApproveStep2), "How much TIP3 tokens: ", 0,999_999_999_999_999_999_999);
    }  

    function tip3ApproveStep2(uint128 value) public {
        ctx_tokens = value;  
        // call balance and allowance checks (with our State it will return to step3)
        tip3BalanceStep1();
    }   

    function tip3ApproveStep3() public {
        if (ctx_balance >= ctx_tokens) 
        {
        ITIP3WalletFungible(userWallet_).approve{
                abiVer: 2,
                extMsg: true,
                sign: true,
                time: uint64(now),
                expire: 0,
                pubkey: userPubkey_,
                callbackId: 0,
                onErrorId: 0
        }(ctx_dest, ctx_remainingTokens, ctx_tokens);    
        } else {
            Terminal.print(0, "Not enough balance!"); 
            mainMenu();               
        }
        _eraseCtx(); // remove context, so we can exit to menu after balance
        tip3BalanceStep1();             
    }       

    // ************************
    // ERROR Steps
    // ************************          

    function _eraseAcc() internal {
        userPubkey_ = 0;
        userRoot_ = address(0);
        userWallet_ = address(0);         
    }

    function _eraseCtx() internal {
        ctx_action = State.NONE;
        ctx_dest = ZERO_ADDRESS;
        ctx_tokens = 0;              
        ctx_grams = 0;
        ctx_remainingTokens = 0;  
        ctx_spender = ZERO_ADDRESS;      
        ctx_balance = 0;
        ctx_limit = 0;
        ctx_swapToken = ZERO_ADDRESS; 
        ctx_pool = ZERO_ADDRESS; 
        ctx_2ndWallet = ZERO_ADDRESS; 
        ctx_liqWallet = ZERO_ADDRESS;   
        ctx_liqReturn = 0;      
    }

    function onDEXError(uint16 error) public {
        if (error == DEX.ERROR_NOT_AUTHORIZED         ) { Terminal.print(0, "Not authorized    "); }
        else if (error == DEX.ERROR_NOT_A_CONTRACT         ) { Terminal.print(0, "Not internal  "); }
        else if (error == DEX.ERROR_PAIR_NOT_SPECIFIED     ) { Terminal.print(0, "No pair specified        "); }
        else if (error == DEX.ERROR_ZERO_ADDRESS           ) { Terminal.print(0, "Empty address"); }
        else if (error == DEX.ERROR_IDENTICAL_TOKENS       ) { Terminal.print(0, "Both tokens in pair are identical   "); }
        else if (error == DEX.ERROR_UNKNOWN_TOKEN          ) { Terminal.print(0, "This token is not imported to DEX"); }
        else if (error == DEX.ERROR_PAIR_EXISTS            ) { Terminal.print(0, "This pair already deployed "); }
        else if (error == DEX.ERROR_WRONG_VALUE            ) { Terminal.print(0, "Wrong number    "); }
        else if (error == DEX.ERROR_NOT_ENOUGH_VALUE       ) { Terminal.print(0, "Not enough value attached   "); }
        else if (error == DEX.ERROR_ZERO_AMOUNT            ) { Terminal.print(0, "Amount of tokens can't be zero  "); }
        else if (error == DEX.ERROR_INCORRRECT_TIP3        ) { Terminal.print(0, "Incorrect TIP3 wallet address  "); }
        else if (error == DEX.ERROR_NOT_ENOUGH_TOKENS      ) { Terminal.print(0, "Not enough TIP3 tokens in wallet"); }
        else if (error == DEX.ERROR_TOKEN_ALREADY_IMPORTED ) { Terminal.print(0, "Token already exists in DEX    "); }
        else if (error == DEX.ERROR_WRONG_CODE_CRC         ) { Terminal.print(0, "TvmCell code hash is not equal to hash provided  "); }
        else if (error == DEX.ERROR_POOL_WALLETS_NOT_ADDED ) { Terminal.print(0, "Checks that pool wallets are in place  "); }
        else if (error == DEX.ERROR_MIN_RETURN_NOT_ACHIEVED) { Terminal.print(0, "Checks that return amount for swap will be better than limit           "); }
        else if (error == DEX.ERROR_MAX_GRAB_NOT_ACHIEVED  ) { Terminal.print(0, "Checks that amount of second token to grab is less than limit"); }
        else if (error == DEX.ERROR_UNKNOWN_TRANSACTION    ) { Terminal.print(0, "Unknown transaction   "); }
        else if (error == DEX.ERROR_ALREADY_IN_TRANSACTION ) { Terminal.print(0, "You already have a transaction active (it will expire in 1 minute)    "); }
        else if (error == DEX.ERROR_NOT_ENOUGH_LIQUIDITY   ) { Terminal.print(0, "There is not enough liquidity in the pool for this operation   "); }
        else { Terminal.print(0, format("Error: {}",error)); }
        mainMenu();      
    }

    function onTIP3Error(uint16 error) public {
        Terminal.print(0, format("Error: {}",error)); 
        mainMenu();      
    }    

}