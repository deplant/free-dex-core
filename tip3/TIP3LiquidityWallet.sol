pragma ton-solidity >= 0.36.0;

pragma AbiHeader expire;


import "TIP3FungibleWallet.sol";
import "ITIP3Wallet.sol";
import "ITIP3WalletHandler.sol";

contract TIP3LiquidityWallet is TIP3FungibleWallet, ITIP3WalletRootBurnable, ITIP3WalletFungibleHandler, ITIP3WalletRootBurnableHandler {


}
