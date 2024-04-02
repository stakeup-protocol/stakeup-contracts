import "./base/_WstTBY.spec";
import "./base/ERC20/ERC20_WstTBY.spec";
import "./base/ERC20/ERC20_StTBY.spec";

///////////////// PROPERTIES //////////////////////

use builtin rule sanity; 

// WST-01 After wrapping in WstTBY, balance of sender must increase
rule wstTBYBalanceOfSenderIncreasesAfterWrapping() {

    env e;
    uint256 amount;

    uint256 wstTBYAmount = _ERC20_StTBY.getSharesByUsd(e, amount);

    uint256 balancePre = balanceOf(e.msg.sender);
    require(balancePre + wstTBYAmount <= max_uint256);
    wrap(e, amount);
    uint256 balancePost = balanceOf(e.msg.sender);

    assert(balancePost > balancePre);
}

// WST-02 After unwrapping in WstTBY, shares of stTBY of sender must increase
rule stTBYBalanceOfSenderIncreasesAfterUnwrapping() {

    env e;
    uint256 amount;

    require(e.msg.sender != currentContract);

    uint256 stTBYAmount = _ERC20_StTBY.getUsdByShares(e, amount);

    uint256 stTBYSharesAmount = _ERC20_StTBY.getSharesByUsd(e, stTBYAmount);

    uint256 sharesPre = _ERC20_StTBY.sharesOf(e.msg.sender);
    unwrap(e, amount);
    uint256 sharesPost = _ERC20_StTBY.sharesOf(e.msg.sender);

    assert(sharesPost > sharesPre);
}

// WST-03 The total supply of WstTBY is always equal to the total StTBY shares held by the contract
invariant wstTBYTotalSupplyEqualsStTBYShares()
    totalSupply() == _ERC20_StTBY.sharesOf(currentContract)
{
    preserved with (env e) {
        // We must require this, otherwise a call to wrap would mint WstTBY for shares we already own
        require(e.msg.sender != currentContract);
    }
}

// WST-04 Consistency check for wrap
rule wrapConsistencyCheck() {

    env e;
    uint256 amount;

    require(e.msg.sender != currentContract);

    uint256 sharesAmount = _ERC20_StTBY.getSharesByUsd(e, amount);
    uint256 balanceSharesSenderPre = _ERC20_StTBY.sharesOf(e, e.msg.sender);
    uint256 balanceSharesContractPre = _ERC20_StTBY.sharesOf(e, currentContract);
    uint256 allowance = _ERC20_StTBY.allowance(e, e.msg.sender, currentContract);
    uint256 balancePreWstTBY = balanceOf(e.msg.sender);
    uint256 totalSupply = totalSupply();
    wrap@withrevert(e, amount);
    bool lastRev = lastReverted;
    uint256 balanceSharesSenderPost = _ERC20_StTBY.sharesOf(e, e.msg.sender);
    uint256 balancePostWstTBY = balanceOf(e.msg.sender);

    require(balancePreWstTBY + sharesAmount <= max_uint256);

    assert(
        (
            e.msg.value > 0 ||
            allowance < amount ||
            balanceSharesSenderPre < sharesAmount ||
            sharesAmount == 0 ||
            totalSupply + sharesAmount > max_uint256 ||
            balanceSharesContractPre + sharesAmount > max_uint256 ||
            e.msg.sender == 0
        ) <=> lastRev
    );

    assert(!lastRev => balancePostWstTBY - balancePreWstTBY == to_mathint(sharesAmount));
    assert(!lastRev => balanceSharesSenderPre - balanceSharesSenderPost == to_mathint(sharesAmount));
}

// WST-05 Consistency check for unwrap
rule unwrapConsistencyCheck() {

    env e;
    uint256 amount;

    require(e.msg.sender != currentContract);

    uint256 stTBYAmount = _ERC20_StTBY.getUsdByShares(e, amount);
    uint256 balanceSharesContractPre = _ERC20_StTBY.sharesOf(e, currentContract);
    uint256 balanceSharesSenderPre = _ERC20_StTBY.sharesOf(e, e.msg.sender);
    uint256 balancePreWstTBY = balanceOf(e.msg.sender);
    unwrap@withrevert(e, amount);
    bool lastRev = lastReverted;
    uint256 balanceSharesSenderPOST = _ERC20_StTBY.sharesOf(e, e.msg.sender);
    uint256 balancePostWstTBY = balanceOf(e.msg.sender);

    assert(
        (
            e.msg.value > 0 ||
            balancePreWstTBY < amount ||
            amount == 0 ||
            stTBYAmount == 0 ||
            e.msg.sender == 0 ||
            balanceSharesSenderPre + amount > max_uint256 ||
            balanceSharesContractPre < amount
        ) <=> lastRev
    );

    assert(!lastRev => balancePreWstTBY - balancePostWstTBY  == to_mathint(amount));
    assert(!lastRev => balanceSharesSenderPOST - balanceSharesSenderPre  == to_mathint(amount));
}

// WST-06 Consistency check for getWstTBYByStTBY
rule getWstTBYByStTBYConsistencyCheck() {

    env e;
    uint256 amount;

    uint256 wstTBYAmount = _ERC20_StTBY.getSharesByUsd(e, amount);

    uint256 val = getWstTBYByStTBY@withrevert(e, amount);
    bool lastRev = lastReverted;

    assert(val == wstTBYAmount);
    assert(!lastRev);
}

// WST-07 Consistency check for getStTBYByWstTBY
rule getStTBYByWstTBYConsistencyCheck() {

    env e;
    uint256 amount;

    uint256 stTBYAmount = _ERC20_StTBY.getUsdByShares(e, amount);

    uint256 val = getStTBYByWstTBY@withrevert(e, amount);
    bool lastRev = lastReverted;

    assert(val == stTBYAmount);
    assert(!lastRev);
}

// WST-08 Consistency check for stTBYPerToken
rule stTBYPerTokenConsistencyCheck() {

    env e;

    uint256 stTBYAmount = _ERC20_StTBY.getUsdByShares(e, 10^18);

    uint256 val = stTBYPerToken@withrevert(e);
    bool lastRev = lastReverted;

    assert(val == stTBYAmount);
    assert(!lastRev);
}

// WST-09 Consistency check for tokensPerStTBY
rule tokensPerStTBYConsistencyCheck() {

    env e;

    uint256 wstTBYAmount = _ERC20_StTBY.getSharesByUsd(e, 10^18);

    uint256 val = tokensPerStTBY@withrevert(e);
    bool lastRev = lastReverted;

    assert(val == wstTBYAmount);
    assert(!lastRev);
}

// WST-10 Consistency check for getStTBY
rule getStTBYConsistencyCheck() {

    address val = getStTBY@withrevert();
    bool lastRev = lastReverted;

    assert(!lastRev);
}
