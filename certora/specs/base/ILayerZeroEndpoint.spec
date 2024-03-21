/////////////////// METHODS ///////////////////////

methods {

    // ILayerZeroEndpoint
    function _.send(uint16 _dstChainId, bytes _destination, bytes _payload, address _refundAddress, address _zroPaymentAddress, bytes _adapterParams) external 
        => NONDET;
    function _.receivePayload(uint16 _srcChainId, bytes _srcAddress, address _dstAddress, uint64 _nonce, uint _gasLimit, bytes _payload) external
        => NONDET;
    function _.getInboundNonce(uint16 _srcChainId, bytes _srcAddress) external => NONDET;
    function _.getOutboundNonce(uint16 _dstChainId, address _srcAddress) external => NONDET;
    function _.estimateFees(uint16 _dstChainId, address _userApplication, bytes _payload, bool _payInZRO, bytes _adapterParam) external
        => NONDET;
    function _.getChainId() external => NONDET;
    function _.retryPayload(uint16 _srcChainId, bytes _srcAddress, bytes _payload) external => NONDET;
    function _.hasStoredPayload(uint16 _srcChainId, bytes _srcAddress) external => NONDET;
    function _.getSendLibraryAddress(address _userApplication) external => NONDET;
    function _.getReceiveLibraryAddress(address _userApplication) external => NONDET;
    function _.isSendingPayload() external => NONDET;
    function _.isReceivingPayload() external => NONDET;
    function _.getConfig(uint16 _version, uint16 _chainId, address _userApplication, uint _configType) external
        => NONDET;
    function _.getSendVersion(address _userApplication) external => NONDET;
    function _.getReceiveVersion(address _userApplication) external => NONDET;

    // ILayerZeroUserApplicationConfig
    function _.setConfig(uint16 _version, uint16 _chainId, uint _configType, bytes _config) external => NONDET;
    function _.setSendVersion(uint16 _version) external => NONDET;
    function _.setReceiveVersion(uint16 _version) external => NONDET;
    function _.forceResumeReceive(uint16 _srcChainId, bytes _srcAddress) external => NONDET;
}
