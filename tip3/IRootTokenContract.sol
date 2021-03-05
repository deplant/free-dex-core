pragma ton-solidity >= 0.36.0;

pragma AbiHeader expire;

/// @title Melnorme\IRootTokenContract
/// @author https://github.com/broxus
/// @notice Interface for implementing TIP-3 root contract methods

interface IRootTokenContract {

    struct IRootTokenContractDetails {
        bytes name;
        bytes symbol;
        uint8 decimals;
        TvmCell wallet_code;
        uint256 root_public_key;
        address root_owner_address;
        uint128 total_supply;
        uint128 start_gas_balance;
        bool paused;
    }

    function getDetails() external view returns (IRootTokenContractDetails);

    function getWalletAddress(uint256 wallet_public_key, address owner_address) external returns (address);

    //function withdrawExtraGas() external;

    //function notifyWalletDeployed(address root) external;

    function tokensReceivedCallback(
        address token_wallet,
        address token_root,
        uint128 amount,
        uint256 sender_public_key,
        address sender_address,
        address sender_wallet,
        address original_gas_to,
        uint128 updated_balance,
        TvmCell payload
    ) external;

    function tokensBurned(
        uint128 tokens,
        uint256 sender_public_key,
        address sender_address,
        address callback_address,
        TvmCell callback_payload) external;        

}