#!/bin/bash
set -e

export TON_HOME=/home/yankin/ton
export REPO_HOME=$TON_HOME/contracts

export SOLC_PATH=$TON_HOME/TON-Solidity-Compiler/build/solc
export TVMLINKER_PATH=$TON_HOME/TVM-linker/tvm_linker/target/release
export STDLIBSOL_PATH=$TON_HOME/TON-Solidity-Compiler/lib/
export TONOSCLI_PATH=$TON_HOME/tonos-cli/target/release

export BUILD_PATH=$REPO_HOME/build
export STD_REPO_PATH=$REPO_HOME/src/std
export TIP3_REPO_PATH=$REPO_HOME/src/tip3
export DEX_REPO_PATH=$REPO_HOME/src/dex

export TESTENV_PATH=$REPO_HOME/test

LOCALNET=http://127.0.0.1
DEVNET=https://net.ton.dev
MAINNET=https://main.ton.dev

export NETWORK=$DEVNET

export AMOUNT_TONS=6000000000
export GIVER_ADDRESS="0:841288ed3b55d9cdafa806807f02a0ae0c169aa5edfe88a789a6482429756a94"
export ZERO_ADDRESS="0:0000000000000000000000000000000000000000000000000000000000000000"

./test/tip3_deploy.sh
#./test/dex_deploy.sh
#./test/debot_deploy.sh
