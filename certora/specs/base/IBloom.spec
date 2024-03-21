/////////////////// METHODS ///////////////////////

methods {
    // IBloomPool
    function _.depositLender(uint256 amount) external => DISPATCHER(true);
    function _.state() external => DISPATCHER(true);
    function _.withdrawLender(uint256 shares) external => DISPATCHER(true);
    function _.emergencyBurn(uint256 amount) external => DISPATCHER(true);
    function _.COMMIT_PHASE_END() external => DISPATCHER(true);
    function _.EMERGENCY_HANDLER() external => DISPATCHER(true);
    function _.UNDERLYING_TOKEN() external => DISPATCHER(true);

    // IEmergencyHandler
    function _.redeem(address _pool) external => DISPATCHER(true);
}
