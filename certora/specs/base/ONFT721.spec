import "./LzApp.spec";

/////////////////// METHODS ///////////////////////

methods {
    // Enabled
    function currentContract.sendFrom(address _from, uint16 _dstChainId, bytes _toAddress, uint _tokenId, address _refundAddress, address _zroPaymentAddress, bytes _adapterParams) external;
    function currentContract.clearCredits(bytes _payload) external;
    function currentContract.minGasToTransferAndStore() external returns (uint256) envfree;

    // Disabled
    function currentContract.estimateSendFee(uint16 _dstChainId, bytes _toAddress, uint _tokenId, bool _useZro, bytes _adapterParams) external returns (uint256, uint256)
        => NONDET DELETE; 
    function currentContract.estimateSendBatchFee(uint16 _dstChainId, bytes _toAddress, uint[] _tokenIds, bool _useZro, bytes _adapterParams) external returns (uint256, uint256)
        => NONDET DELETE; 
    function currentContract.sendBatchFrom(address _from, uint16 _dstChainId, bytes _toAddress, uint[] _tokenIds, address _refundAddress, address _zroPaymentAddress, bytes _adapterParams) external
        => NONDET DELETE; // Test with sendFrom() only
    function currentContract.setMinGasToTransferAndStore(uint _minGasToTransferAndStore) external
        => NONDET DELETE; 
    function currentContract.setDstChainIdToTransferGas(uint16 _dstChainId, uint _dstChainIdToTransferGas) external
        => NONDET DELETE; 
    function currentContract.setDstChainIdToBatchLimit(uint16 _dstChainId, uint _dstChainIdToBatchLimit) external
        => NONDET DELETE; 
}

///////////////// GHOSTS & HOOKS //////////////////

//
// Ghost copy of `mapping(bytes32 => StoredCredit) public storedCredits;`
//

// uint index;

ghost mapping (bytes32 => mathint) ghostStoredCreditsIndex {
    init_state axiom forall bytes32 i. ghostStoredCreditsIndex[i] == 0;
    axiom forall bytes32 i. ghostStoredCreditsIndex[i] >= 0 && ghostStoredCreditsIndex[i] <= max_uint256;
}

hook Sload uint256 val currentContract.storedCredits[KEY bytes32 i].index STORAGE {
    require(require_uint256(ghostStoredCreditsIndex[i]) == val);
} 

hook Sstore currentContract.storedCredits[KEY bytes32 i].index uint256 val STORAGE {
    ghostStoredCreditsIndex[i] = val;
}

