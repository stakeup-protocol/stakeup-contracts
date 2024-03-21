using WstTBYHarness as _ERC20_WstTBY;

/////////////////// METHODS ///////////////////////

methods {
    function _ERC20_WstTBY.name() external returns (string) envfree;
    function _ERC20_WstTBY.symbol() external returns (string) envfree;
    function _ERC20_WstTBY.decimals() external returns (uint8) envfree;
    function _ERC20_WstTBY.totalSupply() external returns (uint256) envfree;
    function _ERC20_WstTBY.balanceOf(address account) external returns (uint256) envfree;
    function _ERC20_WstTBY.transfer(address to, uint256 value) external returns (bool);
    function _ERC20_WstTBY.allowance(address owner, address spender) external returns (uint256) envfree;
    function _ERC20_WstTBY.approve(address spender, uint256 value) external returns (bool);
    function _ERC20_WstTBY.transferFrom(address from, address to, uint256 value) external returns (bool);
}

////////////////// FUNCTIONS //////////////////////

function init_ERC20_WstTBY() {
    require(forall address a. ghostErc20Balances_WstTBY[a] <= ghostErc20TotalSupply_WstTBY);
}

///////////////// GHOSTS & HOOKS //////////////////

//
// Ghost copy of `_balances`
//

ghost mapping (address => mathint) ghostErc20Balances_WstTBY {
    init_state axiom forall address i. ghostErc20Balances_WstTBY[i] == 0;
    axiom forall address i. ghostErc20Balances_WstTBY[i] >= 0;
}

ghost mapping (address => mathint) ghostErc20BalancesPrev_WstTBY {
    init_state axiom forall address i. ghostErc20BalancesPrev_WstTBY[i] == 0;
    axiom forall address i. ghostErc20BalancesPrev_WstTBY[i] >= 0;
}

ghost mathint ghostErc20SumAllBalance_WstTBY {
    init_state axiom ghostErc20SumAllBalance_WstTBY == 0;
    axiom ghostErc20SumAllBalance_WstTBY >= 0;
}

hook Sload uint256 val _ERC20_WstTBY._balances[KEY address i] STORAGE {
    require(require_uint256(ghostErc20Balances_WstTBY[i]) == val);
} 

hook Sstore _ERC20_WstTBY._balances[KEY address i] uint256 val (uint256 valPrev) STORAGE {
    ghostErc20BalancesPrev_WstTBY[i] = valPrev;
    ghostErc20Balances_WstTBY[i] = val;
    ghostErc20SumAllBalance_WstTBY = require_uint256(ghostErc20SumAllBalance_WstTBY + val - ghostErc20BalancesPrev_WstTBY[i]);
}

//
// Ghost copy of `mapping(address account => mapping(address spender => uint256)) private _allowances;`
//

ghost mapping(address => mapping(address => mathint)) ghostErc20Allowances_WstTBY {
    init_state axiom forall address key. forall address val. ghostErc20Allowances_WstTBY[key][val] == 0;
    axiom forall address key. forall address val. ghostErc20Allowances_WstTBY[key][val] >= 0;
}

ghost mapping(address => mapping(address => mathint)) ghostErc20AllowancesPrev_WstTBY {
    init_state axiom forall address key. forall address val. ghostErc20AllowancesPrev_WstTBY[key][val] == 0;
    axiom forall address key. forall address val. ghostErc20AllowancesPrev_WstTBY[key][val] >= 0;
}

hook Sload uint256 amount _ERC20_WstTBY._allowances[KEY address key][KEY address val] STORAGE {
    require(require_uint256(ghostErc20Allowances_WstTBY[key][val]) == amount);
}

hook Sstore _ERC20_WstTBY._allowances[KEY address key][KEY address val] uint256 amount (uint256 valPrev) STORAGE {
    ghostErc20AllowancesPrev_WstTBY[key][val] = valPrev;
    ghostErc20Allowances_WstTBY[key][val] = amount;
}

//
// Ghost copy of `_totalSupply`
//

ghost mathint ghostErc20TotalSupply_WstTBY {
    init_state axiom ghostErc20TotalSupply_WstTBY == 0;
    axiom ghostErc20TotalSupply_WstTBY >= 0;
    axiom forall address i. ghostErc20Balances_WstTBY[i] <= ghostErc20TotalSupply_WstTBY;
}

ghost mathint ghostErc20TotalSupplyPrev_WstTBY {
    init_state axiom ghostErc20TotalSupplyPrev_WstTBY == 0;
    axiom ghostErc20TotalSupplyPrev_WstTBY >= 0;
}

hook Sload uint256 val _ERC20_WstTBY._totalSupply STORAGE {
    require(require_uint256(ghostErc20TotalSupply_WstTBY) == val);
}

hook Sstore _ERC20_WstTBY._totalSupply uint256 val (uint256 valPrev) STORAGE {
    ghostErc20TotalSupplyPrev_WstTBY = valPrev;
    ghostErc20TotalSupply_WstTBY = val;
}
