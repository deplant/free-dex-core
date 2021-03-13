pragma ton-solidity >=0.38.2;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

//================================================================================
//
//import "DexFactory.sol";
//import "SymbolPair.sol";
import "/home/yankin/ton/contracts/src/std/debot/Debot.sol";
import "/home/yankin/ton/contracts/src/std/debot/Terminal/Terminal.sol";
import "/home/yankin/ton/contracts/src/std/debot/AddressInput/AddressInput.sol";
import "/home/yankin/ton/contracts/src/std/debot/NumberInput/NumberInput.sol";
//import {IDEXPool} from "/home/yankin/ton/contracts/src/dex/DEXPool.sol";
//import {IDEXRoot} from "/home/yankin/ton/contracts/src/dex/DEXRoot.sol";
import "/home/yankin/ton/contracts/src/tip3/int/ITIP3Root.sol";
import "/home/yankin/ton/contracts/src/tip3/int/ITIP3Wallet.sol";

//================================================================================
//
interface IDEXRoot 
{
    
    function getTokenExists(address rootAddress) external view returns(bool);
    function getVersion(address rootAddress) external view returns(uint8 dexVersion);
    function getPoolAddress(address _tokenA, address _tokenB) external view returns (address poolAddress);
    function importToken(address _rootAddr) external;
    function deployPool(address _tokenA, address _tokenB) external returns(address poolAddress);
}

interface IDEXPool 
{
    
    function getPoolDetails() external view returns (PoolDetails details);

    struct PoolDetails {
        address rootX;
        address walletX;
        uint128 balanceX;
        address rootY;         
        address walletY; 
        uint128 balanceY;
        uint128 providerFee;
        uint128 balanceLiq;         
    }     
        
}


contract DexDebot is Debot 
{
    address static dexAddress;
    address constant ZERO_ADDRESS   = address.makeAddrStd(0, 0);    

    enum State { NONE, TIP3_VIEW_BALANCE , TIP3_TRANSFER , TIP3_APPROVE , DEX_VIEW, DEX_DEPOSIT, DEX_SWAP, DEX_WITHDRAW }

    optional(uint256) pk;

    // Account Context
    uint256 userPubkey_;
    address userRoot_;
    address userWallet_;    

    // User Context
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
        mainMenu();
    }

    function mainMenu() public 
    {
        ctx_action = State.NONE;
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
            userPubkey_ = 0;
            userRoot_ == address(0);
            userWallet_ == address(0);
            ctx_action == State.NONE;                  
            mainMenu();
        } else 
        {
            ctx_action == State.NONE;                  
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
                //getSwapDetails();
            }        
            else if (ctx_action == State.DEX_DEPOSIT)
            {
                //getDepositDetails();
            }
            else if (ctx_action == State.DEX_WITHDRAW)
            {
                //getWithdrawDetails();
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
                onErrorId: 0
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
                    onErrorId: tvm.functionId(onWalletError)
            }();    
    }    

    function dexPoolDetailsStep2(IDEXPool.PoolDetails details) public { 
        Terminal.print(0, format("Balance: 0:{:x}", details.rootX.value));
        Terminal.print(0, format("Balance: 0:{:x}", details.walletX.value));
        Terminal.print(0, format("Balance: {}", details.balanceX));
        Terminal.print(0, format("Balance: 0:{:x}", details.rootY.value));       
        Terminal.print(0, format("Balance: 0:{:x}", details.walletY.value)); 
        Terminal.print(0, format("Balance: {}", details.balanceY));
        Terminal.print(0, format("Balance: {}", details.providerFee));
        Terminal.print(0, format("Balance: {}", details.balanceLiq));
        mainMenu();          
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
                    onErrorId: tvm.functionId(onWalletError)
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

    function onWalletError(uint16 errorId) public
    {
        if (errorId == 64) 
        {
            Terminal.print(0, "No wallet for this TIP-3 token! Do you want to create it?");  
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
        ctx_tokens = value;     
        NumberInput.get(tvm.functionId(tip3TransferStep3), "How much TONs as value: ", 0,999_999_999_999_999_999_999);
    }

    function tip3TransferStep3(uint128 value) public {
        ctx_grams = value;          
        ITIP3WalletFungible(userWallet_).transfer{
                abiVer: 2,
                extMsg: true,
                sign: true,
                time: uint64(now),
                expire: 0,
                pubkey: userPubkey_,
                callbackId: 0,
                onErrorId: 0
        }(ctx_dest, ctx_tokens, ctx_grams);
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
                onErrorId: tvm.functionId(onError)
        }(ctx_dest, ctx_remainingTokens, ctx_tokens);    
        } else {
            Terminal.print(0, "Not enough balance!");  
        }
        _eraseCtx(); // remove context, so we can exit to menu after balance
        tip3BalanceStep1();             
    }       

    // ************************
    // ERROR Steps
    // ************************          

    function onError(uint16 errorId) public {
        _eraseCtx();
        Terminal.print(0, format("Error: {}",errorId));  
        mainMenu();   
    }   

    function _eraseCtx() internal {
        ctx_action = State.NONE;
        ctx_dest = address(0);
        ctx_tokens = 0;              
        ctx_grams = 0;
        ctx_remainingTokens = 0;  
        ctx_spender = address(0);      
        ctx_balance = 0;
        ctx_limit = 0;
        ctx_swapToken = address(0); 
        ctx_pool = address(0); 
    }

 





    /*function onDexAddress(address value) public 
    {
        dexAddress = value;
        _onDexAddress();
    }

    function onProviderFee(uint128 fee) public
    {
        Terminal.print(0, format("Current fee: \"{}\"", fee));
        _onDexAddress();
    }*/

}