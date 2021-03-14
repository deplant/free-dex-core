#!/bin/bash
set -e

export TON_HOME=/home/yankin/ton
export REPO_HOME=$TON_HOME/contracts

export SOLC_PATH=$TON_HOME/TON-Solidity-Compiler/build/solc
export TVMLINKER_PATH=$TON_HOME/TVM-linker/tvm_linker/target/release
export STDLIBSOL_PATH=$TON_HOME/TON-Solidity-Compiler/lib/
export TONOSCLI_PATH=$TON_HOME/tonos-cli/target/release

export BUILD_PATH=$REPO_HOME/build
export SOL_SOURCE_PATH=$REPO_HOME/src
export STD_REPO_PATH=$REPO_HOME/src/std
export TIP3_REPO_PATH=$REPO_HOME/src/tip3
export DEX_REPO_PATH=$REPO_HOME/src/dex
export TESTENV_PATH=$REPO_HOME/test

LOCALNET=http://127.0.0.1
OCEANNET=http://46.101.136.55
DEVNET=https://net.ton.dev
MAINNET=https://main.ton.dev

export NETWORK=$OCEANNET

export AMOUNT_TONS=99000000000
export GIVER_ADDRESS="0:841288ed3b55d9cdafa806807f02a0ae0c169aa5edfe88a789a6482429756a94"
export ZERO_ADDRESS="0:0000000000000000000000000000000000000000000000000000000000000000"


function grepCode {
echo $($TVMLINKER_PATH/tvm_linker decode --tvc $BUILD_PATH/$1.tvc  | grep code: | cut -c 8-)
}
function grepAddr {
echo $(cat $BUILD_PATH/genaddr_$1.log | grep "Raw address:" | cut -d ' ' -f 3)
}
function grepPubkey {
echo $(cat $BUILD_PATH/$1.keys.json | grep public | cut -c 14-77)
}
function grepAbi {
echo $(cat $1.abi.json | xxd -ps -c 20000)
}
function genPair {
echo "Generating address of $1 ..."
echo "$TONOSCLI_PATH/tonos-cli genaddr --data $2 $BUILD_PATH/$1.tvc $BUILD_PATH/$1.abi.json --genkey $BUILD_PATH/$3.keys.json > $BUILD_PATH/genaddr_$1.log"
$TONOSCLI_PATH/tonos-cli genaddr $BUILD_PATH/$1.tvc $BUILD_PATH/$1.abi.json --data $2 --genkey $BUILD_PATH/$3.keys.json > $BUILD_PATH/genaddr_$1.log
echo "Success!"
}
function genaddrSetKeys {
echo "Generating address of $1 ..."
echo "cp genaddr $BUILD_PATH/$1.tvc $BUILD_PATH/$1.abi.json --data $DATA --setkey $BUILD_PATH/$2.keys.json --save > $BUILD_PATH/genaddr_$1.log"
echo "$TONOSCLI_PATH/tonos-cli genaddr $BUILD_PATH/$1.tvc $BUILD_PATH/$1.abi.json --data $DATA --setkey $BUILD_PATH/$2.keys.json --save > $BUILD_PATH/genaddr_$1.log"
#
echo "Success!"
}
function compile {
echo "Compiling $1 ..."
echo "$SOLC_PATH/solc SOURCE_REPO/=/home/yankin/ton/contracts/src/ $2/$1.sol --output-dir $BUILD_PATH  > $BUILD_PATH/compile_$1.log"
cd $2
$SOLC_PATH/solc $2/$1.sol --output-dir $BUILD_PATH > $BUILD_PATH/compile_$1.log
cd $REPO_HOME
echo "Success!"
}
function link {
echo "Linking $1 ..."
echo "$TVMLINKER_PATH/tvm_linker compile $BUILD_PATH/$1.code -o $BUILD_PATH/$1.tvc --lib $STDLIBSOL_PATH/stdlib_sol.tvm > $BUILD_PATH/link_$1.log"
$TVMLINKER_PATH/tvm_linker compile $BUILD_PATH/$1.code -o $BUILD_PATH/$1.tvc --lib $STDLIBSOL_PATH/stdlib_sol.tvm > $BUILD_PATH/link_$1.log
echo "Success!"
}
function giver {
echo "Asking giver for $AMOUNT_TONS to $2 ..."
echo "$TONOSCLI_PATH/tonos-cli --url $NETWORK call --abi $TESTENV_PATH/local_giver.abi.json $GIVER_ADDRESS sendGrams "{\"dest\":\"$2\",\"amount\":\"$AMOUNT_TONS\"}" > /dev/null"
$TONOSCLI_PATH/tonos-cli --url $NETWORK call --abi $TESTENV_PATH/local_giver.abi.json $GIVER_ADDRESS sendGrams "{\"dest\":\"$2\",\"amount\":\"$AMOUNT_TONS\"}" > $BUILD_PATH/give_$1.log
echo "Success!"
}
function deploy {
echo "Deploying $1 ..."
echo "$TONOSCLI_PATH/tonos-cli --url $NETWORK deploy $BUILD_PATH/$1.tvc {} --sign $BUILD_PATH/$2.keys.json --abi $BUILD_PATH/$1.abi.json > $BUILD_PATH/deploy_$1.log"
$TONOSCLI_PATH/tonos-cli --url $NETWORK deploy $BUILD_PATH/$1.tvc '{}' --sign $BUILD_PATH/$2.keys.json --abi $BUILD_PATH/$1.abi.json > $BUILD_PATH/deploy_$1.log
echo "Success!"
}
function setDebotAbi {
echo "Setting debot ABI $1 ..."
#$TONOSCLI_PATH/tonos-cli --url $NETWORK call $DEBOT_ADDRESS setABI "{\"dabi\":\"$DEBOT_ABI\"}" --sign $CONTRACT.keys.json --abi $CONTRACT.abi.json
}

#$TVMLINKER_PATH/tvm_linker compile $DEBOT_NAME.code --lib $STDLIBSOL_PATH/stdlib_sol.tvm
#CODE=$(code)

echo "Working on network: $NETWORK"

echo "-----------------------------------------------------------------------------------"
echo "#1 TIP3 Deploy Scenario"
echo "-----------------------------------------------------------------------------------"

ITERATION=86

echo "Gold$ITERATION Token"
SYMBOL=$(echo -n "GLD$ITERATION" | xxd -p )
NAME=$(echo -n "Gold$ITERATION" | xxd -p )
DECIMALS="6"

echo "GLD Root Contract"

CONTRACT=TIP3FungibleRoot
KEYS=root1
PUBKEY=$(grepPubkey $KEYS)

compile $CONTRACT $TIP3_REPO_PATH
compile TIP3FungibleWallet $TIP3_REPO_PATH
link $CONTRACT
link TIP3FungibleWallet
CODE=$(grepCode TIP3FungibleWallet)
$TONOSCLI_PATH/tonos-cli genaddr $BUILD_PATH/$CONTRACT.tvc $BUILD_PATH/$CONTRACT.abi.json --data '{"root_public_key_":"0x'$PUBKEY'","root_owner_address_":"'$ZERO_ADDRESS'", "name_":"'$NAME'", "symbol_":"'$SYMBOL'", "decimals_":'$DECIMALS', "code_":"'$CODE'"}' --setkey $BUILD_PATH/$KEYS.keys.json --save > $BUILD_PATH/genaddr_$CONTRACT.log
CONTRACT_ADDRESS=$(grepAddr $CONTRACT)
ROOT1_ADDRESS=$CONTRACT_ADDRESS
giver $CONTRACT $CONTRACT_ADDRESS
$TONOSCLI_PATH/tonos-cli --url $NETWORK deploy $BUILD_PATH/$CONTRACT.tvc '{}' --sign $BUILD_PATH/$KEYS.keys.json --abi $BUILD_PATH/$CONTRACT.abi.json > $BUILD_PATH/deploy_$CONTRACT.log

echo "GLD Wallet of Alice"
WALLET1_KEYS=wallet1
WALLET1_PUBKEY=$(grepPubkey $WALLET1_KEYS)

$TONOSCLI_PATH/tonos-cli -u $NETWORK call --abi $BUILD_PATH/$CONTRACT.abi.json $CONTRACT_ADDRESS deployWallet '{"workchainId":"0","walletPubkey":"0x'$WALLET1_PUBKEY'","walletOwner":"'$ZERO_ADDRESS'","tokens":"0","grams":"2000000000"}' --sign $BUILD_PATH/$KEYS.keys.json

echo "GLD Wallet of Bob"
WALLET2_KEYS=wallet2
WALLET2_PUBKEY=$(grepPubkey $WALLET2_KEYS)

$TONOSCLI_PATH/tonos-cli -u $NETWORK call --abi $BUILD_PATH/$CONTRACT.abi.json $CONTRACT_ADDRESS deployWallet '{"workchainId":"0","walletPubkey":"0x'$WALLET2_PUBKEY'","walletOwner":"'$ZERO_ADDRESS'","tokens":"0","grams":"2000000000"}' --sign $BUILD_PATH/$KEYS.keys.json

echo "Platinum$ITERATION Token"
SYMBOL=$(echo -n "PLT$ITERATION" | xxd -p )
NAME=$(echo -n "Platinum$ITERATION" | xxd -p )
DECIMALS="9"

echo "PLT Root Contract"

CONTRACT=TIP3FungibleRoot
KEYS=root2
PUBKEY=$(grepPubkey $KEYS)

compile TIP3FungibleWallet $TIP3_REPO_PATH
link $CONTRACT
link TIP3FungibleWallet
CODE=$(grepCode TIP3FungibleWallet)
$TONOSCLI_PATH/tonos-cli genaddr $BUILD_PATH/$CONTRACT.tvc $BUILD_PATH/$CONTRACT.abi.json --data '{"root_public_key_":"0x'$PUBKEY'", "root_owner_address_":"'$ZERO_ADDRESS'", "name_":"'$NAME'", "symbol_":"'$SYMBOL'", "decimals_":'$DECIMALS', "code_":"'$CODE'"}' --setkey $BUILD_PATH/$KEYS.keys.json --save > $BUILD_PATH/genaddr_$CONTRACT.log
CONTRACT_ADDRESS=$(grepAddr $CONTRACT)
ROOT2_ADDRESS=$CONTRACT_ADDRESS
giver $CONTRACT $CONTRACT_ADDRESS
$TONOSCLI_PATH/tonos-cli --url $NETWORK deploy $BUILD_PATH/$CONTRACT.tvc  '{}' --sign $BUILD_PATH/$KEYS.keys.json --abi $BUILD_PATH/$CONTRACT.abi.json > $BUILD_PATH/deploy_$CONTRACT.log

echo "PLT Wallet of Alice"
WALLET1_KEYS=wallet1
WALLET1_PUBKEY=$(grepPubkey $WALLET1_KEYS)

$TONOSCLI_PATH/tonos-cli -u $NETWORK call --abi $BUILD_PATH/$CONTRACT.abi.json $CONTRACT_ADDRESS deployWallet '{"workchainId":"0","walletPubkey":"0x'$WALLET1_PUBKEY'","walletOwner":"'$ZERO_ADDRESS'","tokens":"0","grams":"3000000000"}' --sign $BUILD_PATH/$KEYS.keys.json

echo "PLT Wallet of Bob"
WALLET2_KEYS=wallet2
WALLET2_PUBKEY=$(grepPubkey $WALLET2_KEYS)

$TONOSCLI_PATH/tonos-cli -u $NETWORK call --abi $BUILD_PATH/$CONTRACT.abi.json $CONTRACT_ADDRESS deployWallet '{"workchainId":"0","walletPubkey":"0x'$WALLET2_PUBKEY'","walletOwner":"'$ZERO_ADDRESS'","tokens":"0","grams":"3000000000"}' --sign $BUILD_PATH/$KEYS.keys.json

echo "-----------------------------------------------------------------------------------"
echo "#1 TIP3 Operations"
echo "-----------------------------------------------------------------------------------"

function getter {
echo "Getter: $1.$3() at $2"
$TONOSCLI_PATH/tonos-cli -u $NETWORK run $2 $3 '{}' --abi $BUILD_PATH/$1.abi.json  | awk '/Result: {/,/}/'
}

#ROOT1_ADDRESS
#ROOT2_ADDRESS


echo $($TONOSCLI_PATH/tonos-cli -u $NETWORK run $ROOT1_ADDRESS getWalletAddress '{"workchainId":"0", "walletPubkey":"0x'$WALLET1_PUBKEY'", "walletOwner":"'$ZERO_ADDRESS'"}' --abi $BUILD_PATH/$CONTRACT.abi.json)
R1_W1_ADDRESS=$($TONOSCLI_PATH/tonos-cli -u $NETWORK run $ROOT1_ADDRESS getWalletAddress '{"workchainId":"0", "walletPubkey":"0x'$WALLET1_PUBKEY'", "walletOwner":"'$ZERO_ADDRESS'"}' --abi $BUILD_PATH/$CONTRACT.abi.json | grep "value" | cut -c 14-79)
R1_W2_ADDRESS=$($TONOSCLI_PATH/tonos-cli -u $NETWORK run $ROOT1_ADDRESS getWalletAddress '{"workchainId":"0", "walletPubkey":"0x'$WALLET2_PUBKEY'", "walletOwner":"'$ZERO_ADDRESS'"}' --abi $BUILD_PATH/$CONTRACT.abi.json | grep "value" | cut -c 14-79)

R2_W1_ADDRESS=$($TONOSCLI_PATH/tonos-cli -u $NETWORK run $ROOT2_ADDRESS getWalletAddress '{"workchainId":"0", "walletPubkey":"0x'$WALLET1_PUBKEY'", "walletOwner":"'$ZERO_ADDRESS'"}' --abi $BUILD_PATH/$CONTRACT.abi.json | grep "value" | cut -c 14-79)
R2_W2_ADDRESS=$($TONOSCLI_PATH/tonos-cli -u $NETWORK run $ROOT2_ADDRESS getWalletAddress '{"workchainId":"0", "walletPubkey":"0x'$WALLET2_PUBKEY'", "walletOwner":"'$ZERO_ADDRESS'"}' --abi $BUILD_PATH/$CONTRACT.abi.json | grep "value" | cut -c 14-79)

echo $ROOT1_ADDRESS
echo $ROOT2_ADDRESS
echo $R1_W1_ADDRESS
echo $R1_W2_ADDRESS
echo $R2_W1_ADDRESS
echo $R2_W2_ADDRESS

echo "Root 1: Granted - 0.0"
#getter TIP3FungibleRoot $ROOT1_ADDRESS getTokenInfo
echo "Root 1: Supply - 0.0"
#getter TIP3FungibleRoot $ROOT1_ADDRESS getTotalSupply

echo "Root 1: Mint tokens"
$TONOSCLI_PATH/tonos-cli -u $NETWORK call $ROOT1_ADDRESS mint '{"tokens":"999888000000"}' --sign $BUILD_PATH/root1.keys.json --abi $BUILD_PATH/TIP3FungibleRoot.abi.json  | awk '/Result: {/,/}/'

echo "Root 1: Supply - 999888.0"
#getter TIP3FungibleRoot $ROOT1_ADDRESS getTokenInfo

echo "Root 1: Grant to wallet 1 - 55.0"
$TONOSCLI_PATH/tonos-cli -u $NETWORK call $ROOT1_ADDRESS grant '{"dest":"'$R1_W1_ADDRESS'","tokens":"55000000","grams":"3000000000"}' --sign $BUILD_PATH/root1.keys.json --abi $BUILD_PATH/TIP3FungibleRoot.abi.json  >> $BUILD_PATH/tip3_tests.log #| awk '/Result: {/,/}/'
echo "Root 1: Grant to wallet 2 - 66.0"
$TONOSCLI_PATH/tonos-cli -u $NETWORK call $ROOT1_ADDRESS grant '{"dest":"'$R1_W2_ADDRESS'","tokens":"66000000","grams":"3000000000"}' --sign $BUILD_PATH/root1.keys.json --abi $BUILD_PATH/TIP3FungibleRoot.abi.json  >> $BUILD_PATH/tip3_tests.log #| awk '/Result: {/,/}/'


echo "Root 1: Granted - 121.0"
#getter TIP3FungibleRoot $ROOT1_ADDRESS getTokenInfo

echo "Wallet 1: Balance - 55.0"
getter TIP3FungibleWallet $R1_W1_ADDRESS getBalance

echo "Wallet 2: Balance - 66.0"
getter TIP3FungibleWallet $R1_W2_ADDRESS getBalance

echo "Wallet 1: Tranfer to Wallet 2 - 4.0"
$TONOSCLI_PATH/tonos-cli -u $NETWORK call $R1_W1_ADDRESS transfer '{"dest":"'$R1_W2_ADDRESS'","tokens":"4000000","grams":"1000000000"}' --sign $BUILD_PATH/$WALLET1_KEYS.keys.json --abi $BUILD_PATH/TIP3FungibleWallet.abi.json | awk '/Result: {/,/}/' #>> $BUILD_PATH/tip3_tests.log

echo "Wallet 1: Balance - 51.0"
getter TIP3FungibleWallet $R1_W1_ADDRESS getBalance

echo "Wallet 2: Balance - 70.0"
getter TIP3FungibleWallet $R1_W2_ADDRESS getBalance

echo "Wallet 1: Approve Wallet 2 as spender of 10.0"
$TONOSCLI_PATH/tonos-cli -u $NETWORK call $R1_W1_ADDRESS approve '{"spender":"'$R1_W2_ADDRESS'","remainingTokens":"0","tokens":"10000000"}' --sign $BUILD_PATH/$WALLET1_KEYS.keys.json --abi $BUILD_PATH/TIP3FungibleWallet.abi.json | awk '/Result: {/,/}/' #>> $BUILD_PATH/tip3_tests.log
echo "Wallet 2: Remote tranfer from Wallet1 to Wallet 2 - 10.0"
$TONOSCLI_PATH/tonos-cli -u $NETWORK call $R1_W2_ADDRESS transferFrom '{"dest":"'$R1_W1_ADDRESS'","to":"'$R1_W2_ADDRESS'","tokens":"10000000","grams":"500000000"}' --sign $BUILD_PATH/$WALLET2_KEYS.keys.json --abi $BUILD_PATH/TIP3FungibleWallet.abi.json | awk '/Result: {/,/}/' #>> $BUILD_PATH/tip3_tests.log

echo "Wallet 1: Balance - 41.0"
getter TIP3FungibleWallet $R1_W1_ADDRESS getBalance

echo "Wallet 2: Balance - 80.0"
getter TIP3FungibleWallet $R1_W2_ADDRESS getBalance

echo "Root 2: Mint tokens"
$TONOSCLI_PATH/tonos-cli -u $NETWORK call $ROOT2_ADDRESS mint '{"tokens":"999000000000"}' --sign $BUILD_PATH/root2.keys.json --abi $BUILD_PATH/TIP3FungibleRoot.abi.json  | awk '/Result: {/,/}/'

echo "Root 2: Grant to wallet 1 - 99.0"
$TONOSCLI_PATH/tonos-cli -u $NETWORK call $ROOT2_ADDRESS grant '{"dest":"'$R2_W1_ADDRESS'","tokens":"99000000000","grams":"3000000000"}' --sign $BUILD_PATH/root2.keys.json --abi $BUILD_PATH/TIP3FungibleRoot.abi.json  >> $BUILD_PATH/tip3_tests.log #| awk '/Result: {/,/}/'
echo "Root 2: Grant to wallet 2 - 88.0"
$TONOSCLI_PATH/tonos-cli -u $NETWORK call $ROOT2_ADDRESS grant '{"dest":"'$R2_W2_ADDRESS'","tokens":"88000000000","grams":"3000000000"}' --sign $BUILD_PATH/root2.keys.json --abi $BUILD_PATH/TIP3FungibleRoot.abi.json  >> $BUILD_PATH/tip3_tests.log #| awk '/Result: {/,/}/'



echo "-----------------------------------------------------------------------------------"
echo "#1 DEXPool Deploy Scenario"
echo "-----------------------------------------------------------------------------------"


echo "Working on network: $NETWORK"

SYMBOLX=$(echo -n "GLD$ITERATION" | xxd -p )
SYMBOLY=$(echo -n "PLT$ITERATION" | xxd -p )
TOKENX=$ROOT1_ADDRESS
TOKENY=$ROOT2_ADDRESS

echo "#1 Prepare DEX Pool Code"

CONTRACT=DEXPool
compile $CONTRACT $DEX_REPO_PATH
compile TIP3LiquidityWallet $DEX_REPO_PATH
link $CONTRACT
link TIP3LiquidityWallet
POOL_CODE=$(grepCode $CONTRACT) #code of pool
WALLET_CODE=$(grepCode TIP3LiquidityWallet) #code of wallet

echo "#1 Deploy DEX Root"

CONTRACT=DEXRoot
KEYS=wallet1
PUBKEY=$(grepPubkey $KEYS)
compile $CONTRACT $DEX_REPO_PATH
link $CONTRACT
$TONOSCLI_PATH/tonos-cli genaddr $BUILD_PATH/$CONTRACT.tvc $BUILD_PATH/$CONTRACT.abi.json --data '{"iteration":"'$ITERATION'"}' --setkey $BUILD_PATH/$KEYS.keys.json --save > $BUILD_PATH/genaddr_$CONTRACT.log
CONTRACT_ADDRESS=$(grepAddr $CONTRACT)
DEXROOT_ADDRESS=$CONTRACT_ADDRESS
giver $CONTRACT $CONTRACT_ADDRESS
$TONOSCLI_PATH/tonos-cli --url $NETWORK deploy $BUILD_PATH/$CONTRACT.tvc '{}' --sign $BUILD_PATH/$KEYS.keys.json --abi $BUILD_PATH/$CONTRACT.abi.json > $BUILD_PATH/deploy_$CONTRACT.log | awk '{print $$(NF)}' | tr -d '\"\n'

echo "Import pool code"
$TONOSCLI_PATH/tonos-cli -u $NETWORK call --abi $BUILD_PATH/$CONTRACT.abi.json $CONTRACT_ADDRESS updatePoolCode '{"_cell":"'$POOL_CODE'"}' --sign $BUILD_PATH/$KEYS.keys.json

echo "Import wallet code"
$TONOSCLI_PATH/tonos-cli -u $NETWORK call --abi $BUILD_PATH/$CONTRACT.abi.json $CONTRACT_ADDRESS  updateLiqWalletCode '{"_cell":"'$WALLET_CODE'"}' --sign $BUILD_PATH/$KEYS.keys.json

echo "Import token1"
$TONOSCLI_PATH/tonos-cli -u $NETWORK call --abi $BUILD_PATH/$CONTRACT.abi.json $CONTRACT_ADDRESS importToken '{"_rootAddr":"'$TOKENX'"}' --sign $BUILD_PATH/$KEYS.keys.json

echo "Check token1"
$TONOSCLI_PATH/tonos-cli -u $NETWORK run $CONTRACT_ADDRESS getTokenExists '{"rootAddress":"'$TOKENX'"}' --abi $BUILD_PATH/$CONTRACT.abi.json  | awk '/Result: {/,/}/'

echo "Import token2"
$TONOSCLI_PATH/tonos-cli -u $NETWORK call --abi $BUILD_PATH/$CONTRACT.abi.json $CONTRACT_ADDRESS importToken '{"_rootAddr":"'$TOKENY'"}' --sign $BUILD_PATH/$KEYS.keys.json

echo "Check token2"
$TONOSCLI_PATH/tonos-cli -u $NETWORK run $CONTRACT_ADDRESS getTokenExists '{"rootAddress":"'$TOKENY'"}' --abi $BUILD_PATH/$CONTRACT.abi.json  | awk '/Result: {/,/}/'

echo "Check address"
POOL_ADDRESS=$($TONOSCLI_PATH/tonos-cli -u $NETWORK run $CONTRACT_ADDRESS getPoolAddress '{"_tokenA":"'$TOKENX'", "_tokenB":"'$TOKENY'"}' --abi $BUILD_PATH/$CONTRACT.abi.json | grep "poolAddress" | cut -c 19-84)

echo $POOL_ADDRESS

#$TONOSCLI_PATH/tonos-cli -u $NETWORK call --abi $BUILD_PATH/TIP3FungibleRoot.abi.json $ROOT1_ADDRESS deployWallet '{"workchainId":"0","walletPubkey":"0x00","walletOwner":"'$POOL_ADDRESS'","tokens":"0","grams":"3000000000"}' --sign $BUILD_PATH/root1.keys.json
#$TONOSCLI_PATH/tonos-cli -u $NETWORK call --abi $BUILD_PATH/TIP3FungibleRoot.abi.json $ROOT2_ADDRESS deployWallet '{"workchainId":"0","walletPubkey":"0x00","walletOwner":"'$POOL_ADDRESS'","tokens":"0","grams":"3000000000"}' --sign $BUILD_PATH/root2.keys.json

#R1_POOL_ADDRESS=$($TONOSCLI_PATH/tonos-cli -u $NETWORK run $ROOT1_ADDRESS getWalletAddress '{"workchainId":"0", "walletPubkey":"0x00","walletOwner":"'$POOL_ADDRESS'"}' --abi $BUILD_PATH/TIP3FungibleRoot.abi.json | grep "walletAddress" | cut -c 21-86)
#R2_POOL_ADDRESS=$($TONOSCLI_PATH/tonos-cli -u $NETWORK run $ROOT2_ADDRESS getWalletAddress '{"workchainId":"0", "walletPubkey":"0x00","walletOwner":"'$POOL_ADDRESS'"}' --abi $BUILD_PATH/TIP3FungibleRoot.abi.json | grep "walletAddress" | cut -c 21-86)

#echo $R1_POOL_ADDRESS
#echo $R2_POOL_ADDRESS

echo "Deploy pool"
#$TONOSCLI_PATH/tonos-cli -u $NETWORK call --abi $BUILD_PATH/$CONTRACT.abi.json $CONTRACT_ADDRESS deployPool '{"_tokenA":"'$TOKENX'", "_tokenB":"'$TOKENY'", "_walletA":"'$R1_POOL_ADDRESS'", "_walletB":"'$R2_POOL_ADDRESS'"}' --sign $BUILD_PATH/$KEYS.keys.json
$TONOSCLI_PATH/tonos-cli -u $NETWORK call --abi $BUILD_PATH/$CONTRACT.abi.json $CONTRACT_ADDRESS deployPool '{"_tokenA":"'$TOKENX'", "_tokenB":"'$TOKENY'"}' --sign $BUILD_PATH/$KEYS.keys.json

CONTRACT=DEXPool

echo "Wallet 1: Approve Deposit"
#$TONOSCLI_PATH/tonos-cli -u $NETWORK call $R1_W1_ADDRESS approve '{"spender":"'$POOL_ADDRESS'","remainingTokens":"0","tokens":"10000000"}' --sign $BUILD_PATH/$WALLET1_KEYS.keys.json --abi $BUILD_PATH/TIP3FungibleWallet.abi.json | awk '/Result: {/,/}/' #>> $BUILD_PATH/tip3_tests.log

giver $CONTRACT $POOL_ADDRESS
#$TONOSCLI_PATH/tonos-cli -u $NETWORK call --abi $BUILD_PATH/$CONTRACT.abi.json $ADDR _deployWallets '{}'

echo "Deploy Liquidity Token Wallets for both pubkeys"
$TONOSCLI_PATH/tonos-cli -u $NETWORK call --abi $BUILD_PATH/$CONTRACT.abi.json $POOL_ADDRESS deployEmptyWallet '{"workchainId":"0", "walletPubkey":"0x'$WALLET1_PUBKEY'", "walletOwner":"'$ZERO_ADDRESS'", "grams":"3000000000"}' --sign $BUILD_PATH/$WALLET1_KEYS.keys.json | awk '/Result: {/,/}/' #>> $BUILD_PATH/tip3_tests.log
$TONOSCLI_PATH/tonos-cli -u $NETWORK call --abi $BUILD_PATH/$CONTRACT.abi.json $POOL_ADDRESS deployEmptyWallet '{"workchainId":"0", "walletPubkey":"0x'$WALLET2_PUBKEY'", "walletOwner":"'$ZERO_ADDRESS'", "grams":"3000000000"}' --sign $BUILD_PATH/$WALLET2_KEYS.keys.json | awk '/Result: {/,/}/' #>> $BUILD_PATH/tip3_tests.log

getter DEXPool $POOL_ADDRESS getPoolDetails

echo "----------------------------------------------------------------------"
echo "Debot Deploy Scenario"
echo "----------------------------------------------------------------------"

CONTRACT=SORDebot

#$TONOSCLI_PATH/tonos-cli genphrase > $BUILD_PATH/seed_$CONTRACT.log
#tonos-cli getkeypair <keyfile.json> "<seed_phrase>"

compile $CONTRACT $DEX_REPO_PATH/debot/
link $CONTRACT

KEYS=pool
PUBKEY=$(grepPubkey $KEYS)
CODE=$(grepCode $CONTRACT)
#DATA=\''{"root_public_key_":"0x'$PUBKEY'", "root_owner_address_":"'$ZERO_ADDRESS'", "name_":"53686974", "symbol_":"534854", "decimals_":8, "wid_":0, "code_":"'$CODE'"}'\'

#genaddrSetKeys $CONTRACT $KEYS $DATA
#'{"random":"0x01"}'
$TONOSCLI_PATH/tonos-cli genaddr $BUILD_PATH/$CONTRACT.tvc $BUILD_PATH/$CONTRACT.abi.json --data '{"dexAddress":"'$DEXROOT_ADDRESS'"}' --setkey $BUILD_PATH/$KEYS.keys.json --save > $BUILD_PATH/genaddr_$CONTRACT.log
CONTRACT_ADDRESS=$(grepAddr $CONTRACT)

giver $CONTRACT $CONTRACT_ADDRESS
echo "$TONOSCLI_PATH/tonos-cli --url $NETWORK deploy $BUILD_PATH/$CONTRACT.tvc '{}' --sign $BUILD_PATH/$KEYS.keys.json --abi $BUILD_PATH/$CONTRACT.abi.json"
$TONOSCLI_PATH/tonos-cli --url $NETWORK deploy $BUILD_PATH/$CONTRACT.tvc '{}' --sign $BUILD_PATH/$KEYS.keys.json --abi $BUILD_PATH/$CONTRACT.abi.json


DEBOT_ABI=$(cat $BUILD_PATH/$CONTRACT.abi.json | xxd -ps -c 20000)
$TONOSCLI_PATH/tonos-cli --url $NETWORK call $CONTRACT_ADDRESS setABI "{\"dabi\":\"$DEBOT_ABI\"}" --sign $BUILD_PATH/$KEYS.keys.json --abi $BUILD_PATH/$CONTRACT.abi.json

giver SORDebot $CONTRACT_ADDRESS
giver DEXRoot $DEXROOT_ADDRESS
giver DEXPool $POOL_ADDRESS
giver TIP3FungibleRoot $ROOT1_ADDRESS
giver TIP3FungibleRoot $ROOT2_ADDRESS
giver TIP3FungibleWallet $R1_W1_ADDRESS
giver TIP3FungibleWallet $R1_W2_ADDRESS
giver TIP3FungibleWallet $R2_W1_ADDRESS
giver TIP3FungibleWallet $R2_W2_ADDRESS
#giver TIP3FungibleWallet $R1_POOL_ADDRESS
#giver TIP3FungibleWallet $R2_POOL_ADDRESS

echo "Wallet 1: Approve DEX a deposit of 10.0"
$TONOSCLI_PATH/tonos-cli -u $NETWORK call $R1_W1_ADDRESS approve '{"spender":"'$R1_W2_ADDRESS'","remainingTokens":"0","tokens":"10000000"}' --sign $BUILD_PATH/$WALLET1_KEYS.keys.json --abi $BUILD_PATH/TIP3FungibleWallet.abi.json | awk '/Result: {/,/}/' #>> $BUILD_PATH/tip3_tests.log


echo "DEX"
echo $DEXROOT_ADDRESS
echo "Pool Root1/Root2"
echo $POOL_ADDRESS
echo "Debot"
echo $CONTRACT_ADDRESS
echo "Root1"
echo $ROOT1_ADDRESS
echo "Root1Wallet1"
echo $R1_W1_ADDRESS
echo "Root1Wallet2"
echo $R1_W2_ADDRESS
echo "Root2"
echo $ROOT2_ADDRESS
echo "Root2Wallet1"
echo $R2_W1_ADDRESS
echo "Root2Wallet2"
echo $R2_W2_ADDRESS
#echo "Root1DEXWallet"
#echo $R1_POOL_ADDRESS
#echo "Root2DEXWallet"
#echo $R2_POOL_ADDRESS

echo "----------------------------------- FULL SUCCESS -----------------------------------"

