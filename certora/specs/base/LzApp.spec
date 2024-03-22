/////////////////// METHODS ///////////////////////

methods {

    function currentContract.lzEndpoint() external returns (address) envfree;
    function currentContract.nonblockingLzReceive(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes _payload) external;

    // Do not test rest of NonblockingLzApp/LzApp (set `NONDET DELETE` for external methods and `NONDET` for internal)
    function currentContract.lzReceive(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes _payload) external => NONDET DELETE;
    function currentContract.retryMessage(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes _payload) external => NONDET DELETE;
    function currentContract.getConfig(uint16 _version, uint16 _chainId, address, uint _configType) external returns (bytes) => NONDET DELETE;
    function currentContract.setConfig(uint16 _version, uint16 _chainId, uint _configType, bytes _config) external => NONDET DELETE;
    function currentContract.setSendVersion(uint16 _version) external => NONDET DELETE;
    function currentContract.setReceiveVersion(uint16 _version) external => NONDET DELETE;
    function currentContract.forceResumeReceive(uint16 _srcChainId, bytes _srcAddress) external => NONDET DELETE;
    function currentContract.setTrustedRemote(uint16 _remoteChainId, bytes _path) external => NONDET DELETE; 
    function currentContract.setTrustedRemoteAddress(uint16 _remoteChainId, bytes _remoteAddress) external => NONDET DELETE;
    function currentContract.getTrustedRemoteAddress(uint16 _remoteChainId) external returns (bytes) => NONDET DELETE;
    function currentContract.setPrecrime(address _precrime) external => NONDET DELETE;
    function currentContract.setMinDstGas(uint16 _dstChainId, uint16 _packetType, uint _minGas) external => NONDET DELETE;
    function currentContract.setPayloadSizeLimit(uint16 _dstChainId, uint _size) external => NONDET DELETE;
    function currentContract.isTrustedRemote(uint16 _srcChainId, bytes _srcAddress) external returns (bool) => NONDET DELETE;

    function LzApp._lzSend(uint16 _dstChainId, bytes memory _payload, address _refundAddress, address _zroPaymentAddress, bytes memory _adapterParams, uint _nativeFee) internal => NONDET; 
    function LzApp._checkGasLimit(uint16 _dstChainId, uint16 _type, bytes memory _adapterParams, uint _extraGas) internal => NONDET;
    function LzApp._getGasLimit(bytes memory _adapterParams) internal returns (uint256) => NONDET;
    function LzApp._checkPayloadSize(uint16 _dstChainId, uint _payloadSize) internal => NONDET;
}
