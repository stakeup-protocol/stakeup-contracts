using StableTokenMockERC20 as _ERC20_StableToken;

/////////////////// METHODS ///////////////////////

methods {
    function _ERC20_StableToken.name() external returns (string) envfree;
    function _ERC20_StableToken.symbol() external returns (string) envfree;
    function _ERC20_StableToken.decimals() external returns (uint8) envfree;
    function _ERC20_StableToken.totalSupply() external returns (uint256) envfree;
    function _ERC20_StableToken.balanceOf(address account) external returns (uint256) envfree;
    function _ERC20_StableToken.transfer(address to, uint256 value) external returns (bool);
    function _ERC20_StableToken.allowance(address owner, address spender) external returns (uint256) envfree;
    function _ERC20_StableToken.approve(address spender, uint256 value) external returns (bool);
    function _ERC20_StableToken.transferFrom(address from, address to, uint256 value) external returns (bool);
}

////////////////// FUNCTIONS //////////////////////

function init_ERC20_StableToken() {
    require(forall address a. ghostErc20Balances_StableToken[a] <= ghostErc20TotalSupply_StableToken);
}

///////////////// GHOSTS & HOOKS //////////////////

//
// Ghost copy of `_balances`
//

ghost mapping (address => mathint) ghostErc20Balances_StableToken {
    init_state axiom forall address i. ghostErc20Balances_StableToken[i] == 0;
    axiom forall address i. ghostErc20Balances_StableToken[i] >= 0;
}

ghost mapping (address => mathint) ghostErc20BalancesPrev_StableToken {
    init_state axiom forall address i. ghostErc20BalancesPrev_StableToken[i] == 0;
    axiom forall address i. ghostErc20BalancesPrev_StableToken[i] >= 0;
}

ghost mathint ghostErc20SumAllBalance_StableToken {
    init_state axiom ghostErc20SumAllBalance_StableToken == 0;
    axiom ghostErc20SumAllBalance_StableToken >= 0;
}

hook Sload uint256 val _ERC20_StableToken._balances[KEY address i] STORAGE {
    require(require_uint256(ghostErc20Balances_StableToken[i]) == val);
} 

hook Sstore _ERC20_StableToken._balances[KEY address i] uint256 val (uint256 valPrev) STORAGE {
    ghostErc20BalancesPrev_StableToken[i] = valPrev;
    ghostErc20Balances_StableToken[i] = val;
    ghostErc20SumAllBalance_StableToken = require_uint256(ghostErc20SumAllBalance_StableToken + val - ghostErc20BalancesPrev_StableToken[i]);
}

//
// Ghost copy of `mapping(address account => mapping(address spender => uint256)) private _allowances;`
//

ghost mapping(address => mapping(address => mathint)) ghostErc20Allowances_StableToken {
    init_state axiom forall address key. forall address val. ghostErc20Allowances_StableToken[key][val] == 0;
    axiom forall address key. forall address val. ghostErc20Allowances_StableToken[key][val] >= 0;
}

ghost mapping(address => mapping(address => mathint)) ghostErc20AllowancesPrev_StableToken {
    init_state axiom forall address key. forall address val. ghostErc20AllowancesPrev_StableToken[key][val] == 0;
    axiom forall address key. forall address val. ghostErc20AllowancesPrev_StableToken[key][val] >= 0;
}

hook Sload uint256 amount _ERC20_StableToken._allowances[KEY address key][KEY address val] STORAGE {
    require(require_uint256(ghostErc20Allowances_StableToken[key][val]) == amount);
}

hook Sstore _ERC20_StableToken._allowances[KEY address key][KEY address val] uint256 amount (uint256 valPrev) STORAGE {
    ghostErc20AllowancesPrev_StableToken[key][val] = valPrev;
    ghostErc20Allowances_StableToken[key][val] = amount;
}

//
// Ghost copy of `_totalSupply`
//

ghost mathint ghostErc20TotalSupply_StableToken {
    init_state axiom ghostErc20TotalSupply_StableToken == 0;
    axiom ghostErc20TotalSupply_StableToken >= 0;
    axiom forall address i. ghostErc20Balances_StableToken[i] <= ghostErc20TotalSupply_StableToken;
}

ghost mathint ghostErc20TotalSupplyPrev_StableToken {
    init_state axiom ghostErc20TotalSupplyPrev_StableToken == 0;
    axiom ghostErc20TotalSupplyPrev_StableToken >= 0;
}

hook Sload uint256 val _ERC20_StableToken._totalSupply STORAGE {
    require(require_uint256(ghostErc20TotalSupply_StableToken) == val);
}

hook Sstore _ERC20_StableToken._totalSupply uint256 val (uint256 valPrev) STORAGE {
    ghostErc20TotalSupplyPrev_StableToken = valPrev;
    ghostErc20TotalSupply_StableToken = val;
}
