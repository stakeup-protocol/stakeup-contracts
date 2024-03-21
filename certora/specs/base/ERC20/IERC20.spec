/////////////////// METHODS ///////////////////////

methods {
    function _.name() external => DISPATCHER(true);
    function _.symbol() external => DISPATCHER(true);
    function _.decimals() external => DISPATCHER(true);
    function _.totalSupply() external => DISPATCHER(true);
    function _.balanceOf(address account) external => DISPATCHER(true);
    function _.transfer(address to, uint256 value) external => DISPATCHER(true);
    function _.allowance(address owner, address spender) external => DISPATCHER(true);
    function _.approve(address spender, uint256 value) external => DISPATCHER(true);
    function _.transferFrom(address from, address to, uint256 value) external => DISPATCHER(true);
}

