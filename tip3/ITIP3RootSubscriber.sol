pragma ton-solidity >= 0.36.0;

pragma AbiHeader expire;

/// @title Melnorme\IRootTokenContract
/// @author https://github.com/broxus
/// @notice Interface for implementing TIP-3 root contract methods

interface ITIP3RootSubscriber {

    function deployNotification(address root) external;    

    function burnNotification(
        uint128 tokens,
        TvmCell payload,
        uint256 sender_public_key,
        address sender_address,
        address wallet_address
    ) external;    

}