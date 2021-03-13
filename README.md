# free-dex-core

LiquiSOR DEX for Free TON. This is repository for core contracts of DEX implementation.
 
## Contract compilation and deployment

Contracts are compiled with one single deploy+test shell script:
```
git clone git@github.com:laugan-ton/free-dex-core.git
cd  free-dex-core
./build.sh
```

## Debot

You can use debot with this command:
```
tonos-cli debot fetch 0:9b07877d09d052d3aaf2c8a0f66006bf21fea5cee607c133a4ded6bba254748c
```

## Addresses of deployed contracts

With provided keys, adresses will be:

```
Wallet Keys:
0xb512e462d32e177203002027e37462c5f78cf9ab5e7b1f9fbeb68b621c49e987
0xadeaae3e5a47499d3209cad5c8bb532a8997748ecf8804c0830763d21deb5539

DEX
0:65bff3054f9b09ace3b2501a0b99cac31634bdacf752a1e23bdc6c00fbc2be4d
Pool Root1/Root2
0:50982ffbfe6f24ce8b9aea6a40d09b3eaaac6c39e57e24de004b7b228a486bae
Debot
0:9b07877d09d052d3aaf2c8a0f66006bf21fea5cee607c133a4ded6bba254748c
Root1
0:b2c1b9efded0e1d5feaec85c8859f7cb3ff301190fdfdcfe1b507e75c9828b62
Root1Wallet1
0:3bc4f29d605284786b5a5a3db3b86f625973679d052c897464b5de424aa2d59a
Root1Wallet2
0:7f2f2914b612b0f1cf82df2669fbd3cebdb2c075ed1c0f706b3bfaac2f8289c7
Root2
0:a1eea408c0573dcf5389fb00bbfc09d52b28427bc8c643f17f24539810a4836a
Root2Wallet1
0:478a6396994217a201f5766fa9fa4ea5862cf5e0fe1edf926ed58b2f62773707
Root2Wallet2
0:b139b3597e4386217bb024771b938d24f95407d2274806d1dbe22b4648b90bbd
Root1DEXWallet
0:65cbb7ff31846b998028b5a3dac76f09a4537da6ca6ce28e77a29f0921149a37
Root2DEXWallet
0:f065178824dce5973f203e9489097b38b8f9a05b72c66b8a4ccce48d6533f3f3
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
