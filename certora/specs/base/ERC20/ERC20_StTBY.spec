using StTBYHarness as _ERC20_StTBY;

/////////////////// METHODS ///////////////////////

methods {
    function _ERC20_StTBY.name() external returns (string) envfree;
    function _ERC20_StTBY.symbol() external returns (string) envfree;
    function _ERC20_StTBY.decimals() external returns (uint8) envfree;
    function _ERC20_StTBY.totalSupply() external returns (uint256) envfree;
    function _ERC20_StTBY.balanceOf(address account) external returns (uint256) envfree;
    function _ERC20_StTBY.transfer(address to, uint256 value) external returns (bool);
    function _ERC20_StTBY.allowance(address owner, address spender) external returns (uint256) envfree;
    function _ERC20_StTBY.approve(address spender, uint256 value) external returns (bool);
    function _ERC20_StTBY.transferFrom(address from, address to, uint256 value) external returns (bool);
    function _ERC20_StTBY.sharesOf(address account) external returns (uint256) envfree;
}

////////////////// FUNCTIONS //////////////////////

function init_ERC20_StTBY() {
    require(forall address a. ghostErc20Balances_StTBY[a] <= ghostErc20TotalSupply_StTBY);
}

///////////////// GHOSTS & HOOKS //////////////////

//
// Ghost copy of `_balances`
//

ghost mapping (address => mathint) ghostErc20Balances_StTBY {
    init_state axiom forall address i. ghostErc20Balances_StTBY[i] == 0;
    axiom forall address i. ghostErc20Balances_StTBY[i] >= 0;
}

ghost mapping (address => mathint) ghostErc20BalancesPrev_StTBY {
    init_state axiom forall address i. ghostErc20BalancesPrev_StTBY[i] == 0;
    axiom forall address i. ghostErc20BalancesPrev_StTBY[i] >= 0;
}

ghost mathint ghostErc20SumAllBalance_StTBY {
    init_state axiom ghostErc20SumAllBalance_StTBY == 0;
    axiom ghostErc20SumAllBalance_StTBY >= 0;
}

hook Sload uint256 val _ERC20_StTBY._balances[KEY address i] STORAGE {
    require(require_uint256(ghostErc20Balances_StTBY[i]) == val);
} 

hook Sstore _ERC20_StTBY._balances[KEY address i] uint256 val (uint256 valPrev) STORAGE {
    ghostErc20BalancesPrev_StTBY[i] = valPrev;
    ghostErc20Balances_StTBY[i] = val;
    ghostErc20SumAllBalance_StTBY = ghostErc20SumAllBalance_StTBY + val - ghostErc20BalancesPrev_StTBY[i];
}

//
// Ghost copy of `_totalSupply`
//

ghost mathint ghostErc20TotalSupply_StTBY {
    init_state axiom ghostErc20TotalSupply_StTBY == 0;
    axiom ghostErc20TotalSupply_StTBY >= 0;
}

ghost mathint ghostErc20TotalSupplyPrev_StTBY {
    init_state axiom ghostErc20TotalSupplyPrev_StTBY == 0;
    axiom ghostErc20TotalSupplyPrev_StTBY >= 0;
}

hook Sload uint256 val _ERC20_StTBY._totalSupply STORAGE {
    require(require_uint256(ghostErc20TotalSupply_StTBY) == val);
}

hook Sstore _ERC20_StTBY._totalSupply uint256 val (uint256 valPrev) STORAGE {
    ghostErc20TotalSupplyPrev_StTBY = valPrev;
    ghostErc20TotalSupply_StTBY = val;
}
