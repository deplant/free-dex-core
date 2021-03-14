#!/bin/bash
set -e

TON_HOME=/home/yankin/ton
REPO_HOME=$TON_HOME/contracts

SOLC_PATH=$TON_HOME/TON-Solidity-Compiler/build/solc
TVMLINKER_PATH=$TON_HOME/TVM-linker/tvm_linker/target/release
STDLIBSOL_PATH=$TON_HOME/TON-Solidity-Compiler/lib/
TONOSCLI_PATH=$TON_HOME/tonos-cli/target/release

BUILD_PATH=$REPO_HOME/build
STD_REPO_PATH=$REPO_HOME/src/std
TIP3_REPO_PATH=$REPO_HOME/src/tip3
DEX_REPO_PATH=$REPO_HOME/src/dex
TESTENV_PATH=$REPO_HOME/test
TEST_CONTR_PATH=$TESTENV_PATH/sol

LOCALNET=http://127.0.0.1
OCEANNET=http://46.101.136.55
DEVNET=https://net.ton.dev
MAINNET=https://main.ton.dev


NETWORK=$OCEANNET

AMOUNT_TONS=6000000000
GIVER_ADDRESS="0:841288ed3b55d9cdafa806807f02a0ae0c169aa5edfe88a789a6482429756a94"
ZERO_ADDRESS="0:0000000000000000000000000000000000000000000000000000000000000000"

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
$TONOSCLI_PATH/tonos-cli --url $NETWORK deploy $BUILD_PATH/$1.tvc '{}' --sign $BUILD_PATH/$2.keys.json --abi $BUILD_PATH/$1.abi.json
echo "Success!"
}
function setDebotAbi {
echo "Setting debot ABI $1 ..."
$TONOSCLI_PATH/tonos-cli --url $NETWORK call $2 setABI "{\"dabi\":\"$3\"}" --sign pool.keys.json --abi $1.abi.json
}

#$TVMLINKER_PATH/tvm_linker compile $DEBOT_NAME.code --lib $STDLIBSOL_PATH/stdlib_sol.tvm
#CODE=$(code)

echo "Working on network: $NETWORK"

echo "#1 TIP3 Deploy Scenario"

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
$TONOSCLI_PATH/tonos-cli genaddr $BUILD_PATH/$CONTRACT.tvc $BUILD_PATH/$CONTRACT.abi.json --data '{"dexAddress":"0:a55c2c68dd8b039d5a7c79a42a94ea88ee6af58517efc8a5c2c23e1d180f9d38"}' --setkey $BUILD_PATH/$KEYS.keys.json --save > $BUILD_PATH/genaddr_$CONTRACT.log
CONTRACT_ADDRESS=$(grepAddr $CONTRACT)

giver $CONTRACT $CONTRACT_ADDRESS
echo "$TONOSCLI_PATH/tonos-cli --url $NETWORK deploy $BUILD_PATH/$CONTRACT.tvc '{}' --sign $BUILD_PATH/$KEYS.keys.json --abi $BUILD_PATH/$CONTRACT.abi.json"
$TONOSCLI_PATH/tonos-cli --url $NETWORK deploy $BUILD_PATH/$CONTRACT.tvc '{}' --sign $BUILD_PATH/$KEYS.keys.json --abi $BUILD_PATH/$CONTRACT.abi.json


DEBOT_ABI=$(cat $BUILD_PATH/$CONTRACT.abi.json | xxd -ps -c 20000)
$TONOSCLI_PATH/tonos-cli --url $NETWORK call $CONTRACT_ADDRESS setABI "{\"dabi\":\"$DEBOT_ABI\"}" --sign $BUILD_PATH/$KEYS.keys.json --abi $BUILD_PATH/$CONTRACT.abi.json


#DEBOT_ABI=$(cat $CONTRACT.abi.json | xxd -ps -c 20000)
