#!/bin/bash
set -e

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
echo "$SOLC_PATH/solc $2/$1.sol --output-dir $BUILD_PATH > $BUILD_PATH/compile_$1.log"
$SOLC_PATH/solc $2/$1.sol --output-dir $BUILD_PATH > $BUILD_PATH/compile_$1.log
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
$TONOSCLI_PATH/tonos-cli --url $NETWORK deploy $BUILD_PATH/$1.tvc '{}' --sign $BUILD_PATH/$2.keys.json --abi $BUILD_PATH/$1.abi.json  > $BUILD_PATH/deploy_$1.log
echo "Success!"
}
function setDebotAbi {
echo "Setting debot ABI $1 ..."
#$TONOSCLI_PATH/tonos-cli --url $NETWORK call $DEBOT_ADDRESS setABI "{\"dabi\":\"$DEBOT_ABI\"}" --sign $CONTRACT.keys.json --abi $CONTRACT.abi.json
}

#$TVMLINKER_PATH/tvm_linker compile $DEBOT_NAME.code --lib $STDLIBSOL_PATH/stdlib_sol.tvm
#CODE=$(code)

function getter {
echo "$TONOSCLI_PATH/tonos-cli -u $NETWORK run $2 $3 '{}' --abi $BUILD_PATH/$1.abi.json  | awk '/Result: {/,/}/'"
$TONOSCLI_PATH/tonos-cli -u $NETWORK run $2 $3 '{}' --abi $BUILD_PATH/$1.abi.json  | awk '/Result: {/,/}/'
}

echo "Working on network: $NETWORK"

ITERATION=21
SYMBOLX=$(echo -n "GLD$ITERATION" | xxd -p )
SYMBOLY=$(echo -n "PLT$ITERATION" | xxd -p )
TOKENX=0:db2fd8ea71ba53c564b45a605284a0eeca847186aa0a575c3ad2885ce051843c
TOKENY=0:0c9515c852ae8d0da939dd242f659988df706705ed92eed4e68adb56444270b8

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
KEYS=pool
PUBKEY=$(grepPubkey $KEYS)
compile $CONTRACT $DEX_REPO_PATH
link $CONTRACT
$TONOSCLI_PATH/tonos-cli genaddr $BUILD_PATH/$CONTRACT.tvc $BUILD_PATH/$CONTRACT.abi.json --data '{}' --setkey $BUILD_PATH/$KEYS.keys.json --save > $BUILD_PATH/genaddr_$CONTRACT.log
CONTRACT_ADDRESS=$(grepAddr $CONTRACT)
giver $CONTRACT $CONTRACT_ADDRESS
#deploy $CONTRACT $KEYS

echo "Import pool code"
$TONOSCLI_PATH/tonos-cli -u $NETWORK call --abi $BUILD_PATH/$CONTRACT.abi.json $CONTRACT_ADDRESS updatePoolCode '{"_cell":"'$POOL_CODE'"}' --sign $BUILD_PATH/$KEYS.keys.json

echo "Import wallet code"
#$TONOSCLI_PATH/tonos-cli -u $NETWORK call --abi $BUILD_PATH/$CONTRACT.abi.json $CONTRACT_ADDRESS  updateLiqWalletCode '{"_cell":"'$WALLET_CODE'"}' --sign $BUILD_PATH/$KEYS.keys.json

echo "Import token1"
#$TONOSCLI_PATH/tonos-cli -u $NETWORK call --abi $BUILD_PATH/$CONTRACT.abi.json $CONTRACT_ADDRESS importToken '{"_rootAddr":"'$TOKENX'","symbol":"'$SYMBOLX'"}' --sign $BUILD_PATH/$KEYS.keys.json

echo "Check token1"
#$TONOSCLI_PATH/tonos-cli -u $NETWORK run $CONTRACT_ADDRESS getTokenExists '{"rootAddress":"'$TOKENX'"}' --abi $BUILD_PATH/$CONTRACT.abi.json  | awk '/Result: {/,/}/'

echo "Import token2"
#$TONOSCLI_PATH/tonos-cli -u $NETWORK call --abi $BUILD_PATH/$CONTRACT.abi.json $CONTRACT_ADDRESS importToken '{"_rootAddr":"'$TOKENY'","symbol":"'$SYMBOLY'"}' --sign $BUILD_PATH/$KEYS.keys.json

echo "Check token2"
#$TONOSCLI_PATH/tonos-cli -u $NETWORK run $CONTRACT_ADDRESS getTokenExists '{"rootAddress":"'$TOKENY'"}' --abi $BUILD_PATH/$CONTRACT.abi.json  | awk '/Result: {/,/}/'

echo "Deploy pool"
$TONOSCLI_PATH/tonos-cli -u $NETWORK call --abi $BUILD_PATH/$CONTRACT.abi.json $CONTRACT_ADDRESS deployPool '{"_tokenA":"'$TOKENX'", "_tokenB":"'$TOKENY'"}' --sign $BUILD_PATH/$KEYS.keys.json

echo "Check address"
POOL_ADDRESS=$($TONOSCLI_PATH/tonos-cli -u $NETWORK run $CONTRACT_ADDRESS getPoolAddress '{"_tokenA":"'$TOKENX'", "_tokenB":"'$TOKENY'"}' --abi $BUILD_PATH/$CONTRACT.abi.json | grep "poolAddress" | cut -c 19-84)

echo $POOL_ADDRESS
#CONTRACT=DEXPool
#POOL_ADDRESS=0:44d65e617f8b59287b4461f85948344844eb57404fcdf0b65e49cab2bd8a30ec

CONTRACT=DEXPool

giver $CONTRACT $POOL_ADDRESS
echo "$TONOSCLI_PATH/tonos-cli -u $NETWORK call --abi $BUILD_PATH/$CONTRACT.abi.json $POOL_ADDRESS _deployWallets '{}'"
$TONOSCLI_PATH/tonos-cli -u $NETWORK call --abi $BUILD_PATH/$CONTRACT.abi.json $POOL_ADDRESS _deployWallets '{}'
getter DEXPool $POOL_ADDRESS getPoolDetails
#$TONOSCLI_PATH/tonos-cli -u $NETWORK call --abi $BUILD_PATH/DEXPool.abi.json $ADDR _deployWallets '{}'

#deposit(address _tokenAddress, uint256 _senderKey, address _senderOwner, uint128 _tokens, uint128 _maxSpend)
#swap(address _tokenAddress, uint256 _senderKey, address _senderOwner, uint128 _tokens, uint128 _minReturn)
#withdraw(uint256 _senderKey, address _senderOwner, uint128 _tokens)