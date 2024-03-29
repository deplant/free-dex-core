pragma ton-solidity >= 0.38.2;

/// @title LiquiSOR\TIP3LiquidityWallet
/// @author laugan
/// @notice Liquity wallet contract for rewarding liquidity providers

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;


import "../tip3/TIP3FungibleWallet.sol";
import "../tip3/int/ITIP3Wallet.sol";

contract TIP3LiquidityWallet is TIP3FungibleWallet, ITIP3WalletRootBurnable {

    function internalBurnFromRoot(uint128 tokens, address subscriber) override external internalMessagePay {
        require(_isRoot(),TIP3.ERROR_MESSAGE_SENDER_IS_NOT_MY_ROOT);
        _spend(tokens);
        if (_hasSubscriber(subscriber)) { 
            ITIP3WalletBurnHandler(subscriber).onWalletBurn{ flag: TVM.FLAG_VALUE_ADD_INBOUND, bounce: true }(root_address_, wallet_public_key_, wallet_owner_address_, tokens);
        }
    }          

}
