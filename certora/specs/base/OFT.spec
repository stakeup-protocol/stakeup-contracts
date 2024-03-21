import "./LzApp.spec";

/////////////////// METHODS ///////////////////////

methods {

    // Enabled
    function currentContract.sendFrom(address _from, uint16 _dstChainId, bytes _toAddress, uint _amount, address _refundAddress, address _zroPaymentAddress, bytes _adapterParams) external;
    function currentContract.circulatingSupply() external returns (uint256) envfree;
    function currentContract.token() external returns (address) envfree;

    // Disabled
    function currentContract.estimateSendFee(uint16 _dstChainId, bytes _toAddress, uint _amount, bool _useZro, bytes _adapterParams) external returns (uint256, uint256) => NONDET DELETE;
    function currentContract.setUseCustomAdapterParams(bool _useCustomAdapterParams) external => NONDET DELETE;
}
