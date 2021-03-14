# free-dex-core

LiquiSOR DEX for Free TON. This is repository for core contracts of DEX implementation.
 
## Contract compilation and deployment

Contracts are compiled with one single deploy+test shell script:
```
git clone git@github.com:laugan-ton/free-dex-core.git
cd  free-dex-core
./build.sh
```
Put your correct paths to compiler and linker at the head of shell-script.
It's using giver, so will work on TONOS SE.

## Debot

You can use debot with this command:
```
tonos-cli debot fetch 0:f1cedf19ba31021433955b2e34bd557da056f2d1edaced53c2f99c9e7c531f20
```

## Addresses of deployed contracts

With provided keys, adresses will be:

```
Wallet Keys:
0xb512e462d32e177203002027e37462c5f78cf9ab5e7b1f9fbeb68b621c49e987
0xadeaae3e5a47499d3209cad5c8bb532a8997748ecf8804c0830763d21deb5539

DEX
0:eeb907c2b7c45da4ec58916278f1d5dc62ddb49341794666e6acde670ed0bfee
Pool Root1/Root2
0:0bcdb337f5f0978c1c14a1a334a386cbf91140ed6eeb5298913c0994b5f672e6
Debot
0:f1cedf19ba31021433955b2e34bd557da056f2d1edaced53c2f99c9e7c531f20
Root1
0:218ff308f2590401930ba66660ef20831b4e1b6af39a98d15f5257d5f60fda2e
Root1Wallet1
0:b823489cc9d5bdeb071e87d1a5cc75d853140952bdbad19e631c4afd951289eb
Root1Wallet2
0:8f74bf634cc853d855c95c3b4dddf763ee811884d8453dfd2c1333e43f5c7fd4
Root2
0:679c62fd5191a52b5f47d9027d83b270c5ee38b793c169e065e055abb5a3d1fb
Root2Wallet1
0:2ca6cfd7a4e1bf93d09fff12cd814ed0cef630292ba0e0ab7ad89563f87082ee
Root2Wallet2
0:4b0b66e0c37e8d1634457d4e94a06acd4bda2deb82bbd0288c39b660f2a6f838
```

## Keys to use

Under build dir reside all keys that are used for deployment. You can use these when Debot asks to sign something:
```
./build/wallet1.keys.json
./build//wallet2.keys.json
```

## Contracts 

### TIP3FungibleRoot and TIP3FungibleWallet

It is our custom TIP-3 implementation. It follows original TIP-3 specification more closely than Broxus one and implements different notification strategies. Still, we think that TIP-3 standard should be further discussed and we will follow mainline changes in the future.


### TIP3LiquidityWallet

This is derivative of usual TIP3FungibleWallet imlementing additional interface function:

#### function internalBurnFromRoot(uint128 tokens, address subscriber) external;

Method for DEX root to burn your liquidity tokens. Important part that it is you who control burn. You give allowance first and only then a Root can spend your tokens!

### DEXPool

Main contract of Liquidity Pool (Pair of TIP-3 Tokens). It manages its own TIP-3 wallets without having direct access to funds or methods to transfer them by its own decision. Funds can be moved only as part of Swap, Deposit of Withdraw operation.

DEXPool implements these methods:

#### function getPoolDetails() external view returns (PoolDetails details);

Getter to receive info about pool (wallets, balances and so on)

#### function getSwapDetails(address _tokenAddress, uint128 _tokens) external view returns (OrderDetails details);

Getter to receive info about SWAP conditions with specified amount of tokens 
@param _tokenAddress - root address of token that you want to sell
@param _tokens - amount of tokens that you want to sell           
@return details - OrderDetails structure (firstParam - amount for spot price, secondParam - amount at effective price (including fee and slippage))

#### function getDepositDetails(address _tokenAddress, uint128 _tokens) external view returns (OrderDetails details);

Getter to receive info about DEPOSIT conditions with specified amount of tokens 
@param _tokenAddress - root address of token that you want to deposit
@param _tokens - amount of tokens that you want to deposit
@return details - OrderDetails structure (firstParam - amount of second token that you need to put, secondParam - amount of liquidity token you will receive)

#### function getWithdrawDetails(uint128 _tokens) external view returns (OrderDetails details);

Getter to receive info about WITHDRAW conditions with specified amount of tokens 
@param _tokens - amount of liquidity tokens that you want to return to DEX           
@return details - OrderDetails structure (firstParam - amount of X token of Pool that you will receive, secondParam - amount of Y token of Pool that you will receive)    

#### function swap(address _tokenAddress, uint256 _senderKey, address _senderOwner, uint128 _tokens, uint128 _minReturn) external;

SWAP operation 
@param _tokenAddress - root address of token that you want to sell 
@param _senderKey - your owner credential (if you're owning TIP-3 through public key, or 0 if not)
@param _senderOwner - your owner credential (if you're owning TIP-3 through internal contract, or 0 if not)      
@param _tokens - amount of tokens that you want to sell        
@param _minReturn - minimum amount of 2nd token in the pair that you should receive to you wallet (or SWAP will fail)

#### function deposit(address _tokenAddress, uint256 _senderKey, address _senderOwner, uint128 _tokens, uint128 _maxSpend) external;

DEPOSIT operation 
@param _tokenAddress - root address of token that you want to deposit 
@param _senderKey - your owner credential (if you're owning TIP-3 through public key, or 0 if not)
@param _senderOwner - your owner credential (if you're owning TIP-3 through internal contract, or 0 if not)           
@param _tokens - amount of tokens that you want to deposit
@param _maxSpend - maximum amount of 2nd token in the pair that will be taken from your wallet (or DEPOSIT will fail). If you're the first provider of liquidity, this param is the exact amount of 2nd that you will send and establish price.

#### function withdraw(uint256 _senderKey, address _senderOwner, uint128 _tokens) external;

WITHDRAW operation 
@param _senderKey - your owner credential (if you're owning TIP-3 through public key, or 0 if not)
@param _senderOwner - your owner credential (if you're owning TIP-3 through internal contract, or 0 if not)          
@param _tokens - amount of liquidity tokens that you want to return to DEX    

	
### DEXRoot

#### function getTokenExists(address rootAddress) external view returns(bool);

Getter to check if DEX have your favorite token.

#### function getPoolAddress(address _tokenA, address _tokenB) external view returns (address poolAddress);

Getter to resolve Pool address of certain pair. As LiquiSOR is a TIP-3 DEX, it doesn't store Pool addresses, you can resolve a needed Pool offline or through this getter.

#### function importToken(address _rootAddr, bytes symbol) external;

Operation to import new TIP-3 token to DEX.

#### function deployPool(address _tokenA, address _tokenB, address _walletA, address _walletB) external returns(address poolAddress);

Operation to deploy a new pair pool.
