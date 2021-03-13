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

LOCALNET=http://127.0.0.1
OCEANNET=http://46.101.136.55
DEVNET=https://net.ton.dev
MAINNET=https://main.ton.dev

NETWORK=$OCEANNET

AMOUNT_TONS=6000000000
GIVER_ADDRESS="0:841288ed3b55d9cdafa806807f02a0ae0c169aa5edfe88a789a6482429756a94"
ZERO_ADDRESS="0:0000000000000000000000000000000000000000000000000000000000000000"

function compile {
echo "Compiling $1 ..."
echo "$SOLC_PATH/solc $1.sol --output-dir $BUILD_PATH > $BUILD_PATH/compile_$1.log" 
$SOLC_PATH/solc $2/$1.sol --output-dir $BUILD_PATH --devdoc > $BUILD_PATH/compile_$1.log 
echo "Success!"
}

compile $1 $2

