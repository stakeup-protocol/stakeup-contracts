using StakeUpTokenHarness as _ERC20_StakeUpToken;

/////////////////// METHODS ///////////////////////

methods {
    function _ERC20_StakeUpToken.name() external returns (string) envfree;
    function _ERC20_StakeUpToken.symbol() external returns (string) envfree;
    function _ERC20_StakeUpToken.decimals() external returns (uint8) envfree;
    function _ERC20_StakeUpToken.totalSupply() external returns (uint256) envfree;
    function _ERC20_StakeUpToken.balanceOf(address account) external returns (uint256) envfree;
    function _ERC20_StakeUpToken.transfer(address to, uint256 value) external returns (bool);
    function _ERC20_StakeUpToken.allowance(address owner, address spender) external returns (uint256) envfree;
    function _ERC20_StakeUpToken.approve(address spender, uint256 value) external returns (bool);
    function _ERC20_StakeUpToken.transferFrom(address from, address to, uint256 value) external returns (bool);
}

////////////////// FUNCTIONS //////////////////////

function init_ERC20_StakeUpToken() {
    require(forall address a. ghostErc20Balances_StakeUpToken[a] <= ghostErc20TotalSupply_StakeUpToken);
}

///////////////// GHOSTS & HOOKS //////////////////

//
// Ghost copy of `_balances`
//

ghost mapping (address => mathint) ghostErc20Balances_StakeUpToken {
    init_state axiom forall address i. ghostErc20Balances_StakeUpToken[i] == 0;
    axiom forall address i. ghostErc20Balances_StakeUpToken[i] >= 0 && ghostErc20Balances_StakeUpToken[i] <= max_uint256;
}

ghost mapping (address => mathint) ghostErc20BalancesPrev_StakeUpToken {
    init_state axiom forall address i. ghostErc20BalancesPrev_StakeUpToken[i] == 0;
    axiom forall address i. ghostErc20BalancesPrev_StakeUpToken[i] >= 0 && ghostErc20BalancesPrev_StakeUpToken[i] <= max_uint256;
}

ghost mathint ghostErc20SumAllBalance_StakeUpToken {
    init_state axiom ghostErc20SumAllBalance_StakeUpToken == 0;
    axiom ghostErc20SumAllBalance_StakeUpToken >= 0 && ghostErc20SumAllBalance_StakeUpToken <= max_uint256;
}

hook Sload uint256 val _ERC20_StakeUpToken._balances[KEY address i] STORAGE {
    require(require_uint256(ghostErc20Balances_StakeUpToken[i]) == val);
} 

hook Sstore _ERC20_StakeUpToken._balances[KEY address i] uint256 val (uint256 valPrev) STORAGE {
    ghostErc20BalancesPrev_StakeUpToken[i] = valPrev;
    ghostErc20Balances_StakeUpToken[i] = val;
    ghostErc20SumAllBalance_StakeUpToken = ghostErc20SumAllBalance_StakeUpToken + val - ghostErc20BalancesPrev_StakeUpToken[i];
}

//
// Ghost copy of `mapping(address account => mapping(address spender => uint256)) private _allowances;`
//

ghost mapping(address => mapping(address => mathint)) ghostErc20Allowances_StakeUpToken {
    init_state axiom forall address key. forall address val. ghostErc20Allowances_StakeUpToken[key][val] == 0;
    axiom forall address key. forall address val. ghostErc20Allowances_StakeUpToken[key][val] >= 0 && ghostErc20Allowances_StakeUpToken[key][val] <= max_uint256;
}

ghost mapping(address => mapping(address => mathint)) ghostErc20AllowancesPrev_StakeUpToken {
    init_state axiom forall address key. forall address val. ghostErc20AllowancesPrev_StakeUpToken[key][val] == 0;
    axiom forall address key. forall address val. ghostErc20AllowancesPrev_StakeUpToken[key][val] >= 0 && ghostErc20AllowancesPrev_StakeUpToken[key][val] <= max_uint256;
}

hook Sload uint256 amount _ERC20_StakeUpToken._allowances[KEY address key][KEY address val] STORAGE {
    require(require_uint256(ghostErc20Allowances_StakeUpToken[key][val]) == amount);
}

hook Sstore _ERC20_StakeUpToken._allowances[KEY address key][KEY address val] uint256 amount (uint256 valPrev) STORAGE {
    ghostErc20AllowancesPrev_StakeUpToken[key][val] = valPrev;
    ghostErc20Allowances_StakeUpToken[key][val] = amount;
}

//
// Ghost copy of `_totalSupply`
//

ghost mathint ghostErc20TotalSupply_StakeUpToken {
    init_state axiom ghostErc20TotalSupply_StakeUpToken == 0;
    axiom ghostErc20TotalSupply_StakeUpToken >= 0 && ghostErc20TotalSupply_StakeUpToken <= max_uint256;
}

ghost mathint ghostErc20TotalSupplyPrev_StakeUpToken {
    init_state axiom ghostErc20TotalSupplyPrev_StakeUpToken == 0;
    axiom ghostErc20TotalSupplyPrev_StakeUpToken >= 0 && ghostErc20TotalSupplyPrev_StakeUpToken <= max_uint256;
}

hook Sload uint256 val _ERC20_StakeUpToken._totalSupply STORAGE {
    require(require_uint256(ghostErc20TotalSupply_StakeUpToken) == val);
}

hook Sstore _ERC20_StakeUpToken._totalSupply uint256 val (uint256 valPrev) STORAGE {
    ghostErc20TotalSupplyPrev_StakeUpToken = valPrev;
    ghostErc20TotalSupply_StakeUpToken = val;
}