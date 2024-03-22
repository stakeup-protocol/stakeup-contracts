using StakeupTokenHarness as _ERC20_StakeupToken;

/////////////////// METHODS ///////////////////////

methods {
    function _ERC20_StakeupToken.name() external returns (string) envfree;
    function _ERC20_StakeupToken.symbol() external returns (string) envfree;
    function _ERC20_StakeupToken.decimals() external returns (uint8) envfree;
    function _ERC20_StakeupToken.totalSupply() external returns (uint256) envfree;
    function _ERC20_StakeupToken.balanceOf(address account) external returns (uint256) envfree;
    function _ERC20_StakeupToken.transfer(address to, uint256 value) external returns (bool);
    function _ERC20_StakeupToken.allowance(address owner, address spender) external returns (uint256) envfree;
    function _ERC20_StakeupToken.approve(address spender, uint256 value) external returns (bool);
    function _ERC20_StakeupToken.transferFrom(address from, address to, uint256 value) external returns (bool);
}

////////////////// FUNCTIONS //////////////////////

function init_ERC20_StakeupToken() {
    require(forall address a. ghostErc20Balances_StakeupToken[a] <= ghostErc20TotalSupply_StakeupToken);
}

///////////////// GHOSTS & HOOKS //////////////////

//
// Ghost copy of `_balances`
//

ghost mapping (address => mathint) ghostErc20Balances_StakeupToken {
    init_state axiom forall address i. ghostErc20Balances_StakeupToken[i] == 0;
    axiom forall address i. ghostErc20Balances_StakeupToken[i] >= 0 && ghostErc20Balances_StakeupToken[i] <= max_uint256;
}

ghost mapping (address => mathint) ghostErc20BalancesPrev_StakeupToken {
    init_state axiom forall address i. ghostErc20BalancesPrev_StakeupToken[i] == 0;
    axiom forall address i. ghostErc20BalancesPrev_StakeupToken[i] >= 0 && ghostErc20BalancesPrev_StakeupToken[i] <= max_uint256;
}

ghost mathint ghostErc20SumAllBalance_StakeupToken {
    init_state axiom ghostErc20SumAllBalance_StakeupToken == 0;
    axiom ghostErc20SumAllBalance_StakeupToken >= 0 && ghostErc20SumAllBalance_StakeupToken <= max_uint256;
}

hook Sload uint256 val _ERC20_StakeupToken._balances[KEY address i] STORAGE {
    require(require_uint256(ghostErc20Balances_StakeupToken[i]) == val);
} 

hook Sstore _ERC20_StakeupToken._balances[KEY address i] uint256 val (uint256 valPrev) STORAGE {
    ghostErc20BalancesPrev_StakeupToken[i] = valPrev;
    ghostErc20Balances_StakeupToken[i] = val;
    ghostErc20SumAllBalance_StakeupToken = ghostErc20SumAllBalance_StakeupToken + val - ghostErc20BalancesPrev_StakeupToken[i];
}

//
// Ghost copy of `mapping(address account => mapping(address spender => uint256)) private _allowances;`
//

ghost mapping(address => mapping(address => mathint)) ghostErc20Allowances_StakeupToken {
    init_state axiom forall address key. forall address val. ghostErc20Allowances_StakeupToken[key][val] == 0;
    axiom forall address key. forall address val. ghostErc20Allowances_StakeupToken[key][val] >= 0 && ghostErc20Allowances_StakeupToken[key][val] <= max_uint256;
}

ghost mapping(address => mapping(address => mathint)) ghostErc20AllowancesPrev_StakeupToken {
    init_state axiom forall address key. forall address val. ghostErc20AllowancesPrev_StakeupToken[key][val] == 0;
    axiom forall address key. forall address val. ghostErc20AllowancesPrev_StakeupToken[key][val] >= 0 && ghostErc20AllowancesPrev_StakeupToken[key][val] <= max_uint256;
}

hook Sload uint256 amount _ERC20_StakeupToken._allowances[KEY address key][KEY address val] STORAGE {
    require(require_uint256(ghostErc20Allowances_StakeupToken[key][val]) == amount);
}

hook Sstore _ERC20_StakeupToken._allowances[KEY address key][KEY address val] uint256 amount (uint256 valPrev) STORAGE {
    ghostErc20AllowancesPrev_StakeupToken[key][val] = valPrev;
    ghostErc20Allowances_StakeupToken[key][val] = amount;
}

//
// Ghost copy of `_totalSupply`
//

ghost mathint ghostErc20TotalSupply_StakeupToken {
    init_state axiom ghostErc20TotalSupply_StakeupToken == 0;
    axiom ghostErc20TotalSupply_StakeupToken >= 0 && ghostErc20TotalSupply_StakeupToken <= max_uint256;
}

ghost mathint ghostErc20TotalSupplyPrev_StakeupToken {
    init_state axiom ghostErc20TotalSupplyPrev_StakeupToken == 0;
    axiom ghostErc20TotalSupplyPrev_StakeupToken >= 0 && ghostErc20TotalSupplyPrev_StakeupToken <= max_uint256;
}

hook Sload uint256 val _ERC20_StakeupToken._totalSupply STORAGE {
    require(require_uint256(ghostErc20TotalSupply_StakeupToken) == val);
}

hook Sstore _ERC20_StakeupToken._totalSupply uint256 val (uint256 valPrev) STORAGE {
    ghostErc20TotalSupplyPrev_StakeupToken = valPrev;
    ghostErc20TotalSupply_StakeupToken = val;
}