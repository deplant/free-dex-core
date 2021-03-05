pragma ton-solidity >= 0.36.0;

/// @title Melnorme\SorDebot
/// @author Augual.Team
/// @notice Contract for managing new tokens and pool deployment

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;



import "MathUint.sol";
import "DexTypes.sol";
//import "Pool.sol";
//import "Debot.sol";
//import "RootTokenContract.sol";

/// NOTE: ALWAYS CHECK:
/// 1. Who is sending the message (msg.sender)
/// 2. Who is owner of the message (msg.pubkey)
/// 3. What contract on the other end of the line? (All TIP-3 wallet interactions should check that it resolves against TIP-3 root)
/// 4. Sufficient gas
/// 5. Sufficient token or gram balance (if applicable)
/// 6. Replay attacks (if applicable)

abstract contract Debot {

	i32 constant DEBOT_WC = -31;

	function getRequiredInterfaces() virtual returns (uint256[] interfaces); 

}

contract SorDebot is Debot, DexTypes {


// зачисляем бабки на дебота

// Hello! Welcome to DEX!

// 0 Please, enter DEX root address

// input(vault_address)
// Получаем публичный ключ, сохраняем его в кэш
// uint256 = IVault(vault_address).getPubkey();

// Choose action:

// 1 Import new token

// 1.1 Enter token root address

// Проверяем наличие токена IRootTokenContract(rtw_address).getWalletAddress(0,0,dex_address_in_uint256);

// 1.2a Confirm? (Shows current choices)
// 1.2b (Shows token already exists)

// Вызываем метод деплоя TTW биржи (овнер - биржа), любой может это сделать
// IVault(vault_address).addToken(tokenRootAddress) - (добавляет кошелек биржи с RPK)

// 1.3a (Shows it was successful)
// 1.3c (Shows error)

// 2 Check token details

// 2.1 Enter token root addres
// input(tokenA_root_address)

// генерим адрес валлета биржи по данному токену, запрашиваем инфу
// ttw_address = IRootTokenContract(rtw_address).getWalletAddress(0,0,dex_address_in_uint256);
// put it to cache mapping
// ITONTokenWallet(ttw_address).getSymbol();
// ITONTokenWallet(ttw_address).getName();
// ITONTokenWallet(ttw_address).getDecimals();
// ITONTokenWallet(ttw_address).getBalance();
// put everything to cache

// 2.2 (Shows token info)

// 3 Check pair info (prices, fees and volumes)

// 3.1 Enter first token of pair
// input(tokenA_root_address)

// 3.2 Enter second token of pair
// input(tokenB_root_address)

// reorder pair

// if pools[tokenA, tokenB].exists() { IPool(cachedAddress).getPairDetails() } // если есть в кэше адрес пула, используем его
// else { TvmCell poolAddr = IVault(vault_address).getPoolAddress(tokenA, tokenB)  } // если нет, то запрашиваем код пула у рута poolCode
// IPool(poolAddr).getPairDetails() генерим адрес пула, запрашиваем всю информацию по паре из него

// 3.3 (Shows pair info)

// 4 Deploy pool

// 4.1 Enter first token of pair
// input(tokenA_root_address)

// 4.2 Enter second token of pair
// input(tokenB_root_address)

// reorder pair
// IVault(vault_address).getPoolAddress(tokenA, tokenB)

// 4.3 Confirm? (Shows current choices)
// 4.3 (Shows pool already exists)

// Вызываем метод деплоя пула

// address poolAddress = IVault(vault_address).deployPool(tokenA_root_address, tokenB_root_address) , внутри он там еще добавит RPK
// проверки на наличие пула и валлетов? Или они внутри контракта Волта?

// 4.3 (Shows new pool address)

// 5 Provide liquidity

// 5.1 Enter tokenA address

// 5.2 Enter tokenB address

// 5.3 Checks pool, checks tokens, checks if amounts already exists and we should enter in recommended amount

// 5.4 (Shows tokenA symbol): Enter amount

// 5.5 (Shows tokenB symbol): Enter amount

// 5.6 Confirm? (Shows current choices)

// call IPool(poolAddr).deposit();

//

// ShowSimpleOrderConditions - мы указываем эмаунты, получаем расчёты slippage для обычного ордера

// ShowSmartOrderConditions - мы указываем эмаунты, получаем расчёты slippage для умного ордера

	function getRequiredInterfaces() override returns (uint256[] interfaces) {
    return [ID_TERMINAL, ID_MENU];
	}

}
