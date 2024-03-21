import "./base/_StTBY.spec";
import "./base/_WstTBY.spec";

using MockBloomPoolA as asset;
using MockBloomPoolB as assetB;
using MockRegistry as _registry;
using StakeupStakingHarness as _StakeupStaking;
using StakeupTokenHarness as _StakeupToken;
using RewardManagerHarness as _RewardManager;
using RedemptionNFTHarness as _RedemptionNFT;

/////////////////// METHODS ///////////////////////

////////////////// FUNCTIONS //////////////////////

///////////////// PROPERTIES //////////////////////

// ST-01 Total StTBY supply equals the value of underlying assets (TBYs, USDC) adjusted for scaling
rule stTBYTotalSupplyEqualsValueOfUnderlyingAssets() {

    env e;
    address tby;
    uint256 amount;

    requireScalingFactor(e);
    // We assume there are no fees, otherwise rounding issues would make the assertion fail
    require(getMintBps() == 0);

    uint256 amountScaled = require_uint256(amount * _scalingFactor());
    uint256 sharesAmount = getSharesByUsd(amountScaled);

    uint256 totalSharesPre = getTotalShares();

    depositTby(e, tby, amount);

    uint256 totalSharesPost = getTotalShares();

    assert(totalSharesPost - totalSharesPre == to_mathint(sharesAmount));
}

// ST-02 Only calls deposits, pokes and redemptions of underlying can make amountStaked increase
rule onlyDepositsPokeAndRedeemUnderlyingCanMakeAmountStakedIncrease(method f)
    filtered { 
        f -> 
            f.selector != sig:failedMessages(uint16,bytes,uint64).selector &&
            f.selector != sig:isTrustedRemote(uint16,bytes).selector &&
            f.selector != sig:retryMessage(uint16,bytes,uint64,bytes).selector &&
            f.selector != sig:lzReceive(uint16,bytes,uint64,bytes).selector &&
            f.selector != sig:_depositExternal(address,uint256,bool).selector
    } {

    env e;
    calldataarg args;

    require(getStakeupStaking() == _StakeupStaking);

    uint256 amountStakedPre = _StakeupStaking.getUserStakingData(e, e.msg.sender).amountStaked;

    f(e, args);

    uint256 amountStakedPost = _StakeupStaking.getUserStakingData(e, e.msg.sender).amountStaked;

    assert(amountStakedPost > amountStakedPre => 
        (
            f.selector == sig:depositTby(address, uint256).selector ||
            f.selector == sig:depositUnderlying(uint256).selector ||
            f.selector == sig:poke().selector ||
            f.selector == sig:redeemUnderlying(address).selector
        )
    );
}

// ST-03 SUP rewards to StTBY depositors don't exceed the mint rewards cutoff
rule supRewardsToDepositorsDontExceedRewardsCutoff(method f) 
    filtered { 
        f -> 
            f.selector == sig:depositTby(address, uint256).selector ||
            f.selector == sig:depositUnderlying(uint256).selector
    } {

    env e;

    address tby;
    uint256 amount;

    uint256 mintRewardsRemainingPre = getMintRewardsRemaining();
    uint256 stakeUpBalancePre = _StakeupToken.balanceOf(e, getStakeupStaking());
    
    if(f.selector == sig:depositTby(address, uint256).selector){
        depositTby@withrevert(e, tby, amount);
    }
    else if(f.selector == sig:depositUnderlying(uint256).selector){
        depositUnderlying@withrevert(e, amount);
    }

    bool lastRev = lastReverted;
    
    uint256 stakeUpBalancePost = _StakeupToken.balanceOf(e, getStakeupStaking());

    uint256 rewardAmount = require_uint256((_RewardManager.LAUNCH_MINT_REWARDS_HARNESS(e) * mintRewardsRemainingPre) /
            _RewardManager.STTBY_MINT_THREASHOLD_HARNESS(e));

    assert(!lastRev => require_uint256(stakeUpBalancePost - stakeUpBalancePre) <= rewardAmount);
}

// ST-04 StTBY holder's amountStaked increase with mint reward distribution, proportional to their deposits
rule amountStakedIncreaseWithMintRewardDistribution(method f)
    filtered { 
        f -> 
            f.selector == sig:depositTby(address, uint256).selector ||
            f.selector == sig:depositUnderlying(uint256).selector
    } {

    env e;
    address tby;
    uint256 amount;

    require(getStakeupStaking() == _StakeupStaking);
    require(_StakeupStaking != currentContract);
    require(_StakeupStaking != e.msg.sender);
    require(amount >= 2);
    require(getMintBps() == 0);
    require(getMintRewardsRemaining() > 2);
    require(_scalingFactor() > 0);

    require(tby == asset);

    uint256 balancePre = sharesOf(e.msg.sender);
    uint256 amountStakedPre = _StakeupStaking.getUserStakingData(e, e.msg.sender).amountStaked;

    if(f.selector == sig:depositTby(address, uint256).selector){
        depositTby(e, tby, amount);
    }
    else if(f.selector == sig:depositUnderlying(uint256).selector){
        depositUnderlying(e, amount);
    }

    uint256 balancePost = sharesOf(e.msg.sender);
    uint256 amountStakedPost = _StakeupStaking.getUserStakingData(e, e.msg.sender).amountStaked;

    assert(getMintRewardsRemaining() > 0 && balancePost > balancePre => amountStakedPost > amountStakedPre);
}

// ST-05 Only calls to deposits, poke, withdraw and redemptions of underlying can make _totalUsd vary
rule onlyDepositsPokeWithdrawAndRedeemUnderlyingCanMakeTotalUsdVary(method f)
    filtered { 
        f -> 
            f.selector != sig:failedMessages(uint16,bytes,uint64).selector &&
            f.selector != sig:isTrustedRemote(uint16,bytes).selector &&
            f.selector != sig:retryMessage(uint16,bytes,uint64,bytes).selector &&
            f.selector != sig:lzReceive(uint16,bytes,uint64,bytes).selector &&
            f.selector != sig:_processProceedsExternal(uint256,uint256).selector &&
            f.selector != sig:_depositExternal(address,uint256,bool).selector
    } {

    env e;
    calldataarg args;

    uint256 totalUsdPre = getTotalUsd();

    f(e, args);

    uint256 totalUsdPost = getTotalUsd();

    assert(totalUsdPost != totalUsdPre => 
        (
            f.selector == sig:depositTby(address, uint256).selector ||
            f.selector == sig:depositUnderlying(uint256).selector ||
            f.selector == sig:poke().selector ||
            f.selector == sig:redeemUnderlying(address).selector ||
            f.selector == sig:withdraw(address, uint256).selector
        )
    );
}

// ST-06 Deposits of TBY/USDC increase StTBY supply, adjusted for fees and scaling	
rule depositsIncreaseStTBYSupply(method f) 
    filtered { 
        f -> 
            f.selector == sig:depositTby(address, uint256).selector ||
            f.selector == sig:depositUnderlying(uint256).selector
    } {

    env e;
    address tby;
    uint256 amount;

    requireScalingFactor(e);

    //@note Issue 01 - We force the check amount > 0, otherwise rule fails
    //require(amount > 0);

    //@note Issue 02 - We ensure the corresponding shares for amount are > 0
    //uint256 sharesAmount = getSharesByUsd(amount);
    //require(sharesAmount > 0);
    //@note Issue 03 - If there is a mint fee, it could happen that minting the fee and the rest separately
    // would mint 0 shares, so we force no mint fee
    require(getMintBps() == 0);

    
    uint256 supplyPre = totalSupply();
    
    if(f.selector == sig:depositTby(address, uint256).selector){
        depositTby@withrevert(e, tby, amount);
    }
    else if(f.selector == sig:depositUnderlying(uint256).selector){
        depositUnderlying@withrevert(e, amount);
    }

    bool lastRev = lastReverted;
    
    uint256 supplyPost = totalSupply();

    assert(!lastRev => supplyPost > supplyPre);
}

// ST-07 StTBY withrawals decrease total supply and total shares, and can only be made by redemption NFT contract
rule withdrawalsOnlyByNFTAndDecreaseStTBYSupplyAndShares() {

    env e;
    address account;
    uint256 shares;

    //@note Issue 01 - We force the check shares > 0, otherwise rule fails
    //require(shares > 0);

    //@note Issue 02 - We ensure the corresponding usd amount for shares is > 0
    //uint256 usdAmount = getUsdByShares(shares);
    //require(usdAmount > 0);


    uint256 supplyPre = totalSupply();
    uint256 sharesPre = getTotalShares();

    withdraw(e, account, shares);
    
    uint256 supplyPost = totalSupply();
    uint256 sharesPost = getTotalShares();

    assert(supplyPost < supplyPre);
    assert(sharesPost < sharesPre);
    assert(e.msg.sender == getRedemptionNFT());
}

// ST-08 When calling poke, lastRateUpdate does not change if less than 12 hours between two calls
rule lastRateUpdateDoesNotChangeIfLessThan12HoursBetweenPokeCalls() {

    env e1;
    env e2;

    require(e1.block.timestamp < e2.block.timestamp);

    poke(e1);

    require(getLastRateUpdate() == e1.block.timestamp);

    uint256 totalUsdPre = getTotalUsd();

    poke(e2);

    uint256 totalUsdPost = getTotalUsd();

    assert(e2.block.timestamp - e1.block.timestamp < 12*60*60 <=> getLastRateUpdate() == e1.block.timestamp);

}

// ST-09 When redeeming underlying if there is yield, totalUsd increases
rule whenRedeemUnderlyingIfYieldPositiveTotalUsdIncreases() {

    env e;
    address tby;

    require(tby == asset);

    uint256 totalUsdPre = getTotalUsd();

    redeemUnderlying(e, tby);

    uint256 totalUsdPost = getTotalUsd();

    satisfy totalUsdPost > totalUsdPre;
}

// ST-10 Fees are transferred to StakeupStaking
rule feesAreTransferredToStakeupStaking(method f) 
    filtered { 
        f -> 
            f.selector == sig:depositTby(address, uint256).selector ||
            f.selector == sig:depositUnderlying(uint256).selector ||
            f.selector == sig:redeemStTBY(uint256).selector ||
            f.selector == sig:redeemWstTBY(uint256).selector ||
            f.selector == sig:redeemUnderlying(address).selector
    } {

    env e;
    address tby;
    uint256 amount;
    uint16 BPS = 10000;

    require(getStakeupStaking() != currentContract);
    require(e.msg.sender != currentContract);
    require(e.msg.sender != getStakeupStaking());
    require(tby == asset);

    requireScalingFactor(e);

    uint256 myScalingFactor = _scalingFactor();

    uint256 sharesStakingPre = sharesOf(e, getStakeupStaking());
    bool positiveFee = false;

    require(getMintBps() <= assert_uint256(BPS));
    require(getRedeemBps() <= assert_uint256(BPS));
    require(getPerformanceBps() <= assert_uint256(BPS));

    if(f.selector == sig:depositTby(address, uint256).selector ||
        f.selector == sig:depositUnderlying(uint256).selector){

        uint256 amountScaled = require_uint256(amount * myScalingFactor);
        uint256 mintFee = assert_uint256((amountScaled * getMintBps()) / BPS);
        uint256 sharesFeeAmount = mintFee>0?getSharesByUsd(mintFee):0;
        if(sharesFeeAmount > 0) positiveFee = true;

        if(f.selector == sig:depositTby(address, uint256).selector){
            depositTby@withrevert(e, tby, amount);
        }
        else if(f.selector == sig:depositUnderlying(uint256).selector){
            depositUnderlying@withrevert(e, amount);
        }
    }
    else if(f.selector == sig:redeemStTBY(uint256).selector){
        uint256 shares = getSharesByUsd(amount);
        uint256 redeemFee = assert_uint256((shares * getRedeemBps()) / BPS);
        if(redeemFee > 0) positiveFee = true;
        redeemStTBY@withrevert(e, amount);
    }
    else if(f.selector == sig:redeemWstTBY(uint256).selector){
        uint256 stTBYAmount = _ERC20_WstTBY.unwrap(e, amount);
        uint256 shares = getSharesByUsd(stTBYAmount);
        uint256 redeemFee = assert_uint256((shares * getRedeemBps()) / BPS);
        if(redeemFee > 0) positiveFee = true;
        redeemWstTBY@withrevert(e, amount);
    }
    else{
        // We assume the contract balance is empty, so the yield will be positive
        require(asset.balanceOf(e, currentContract) == 0);

        // We make sure the performance fee is positive
        require((myScalingFactor * getPerformanceBps()) >= to_mathint(BPS));
        
        // We estimate a value for the fee amount. It is not real but can tell us if fees are positive or not
        uint256 estimateSharesFeeAmount = getSharesByUsd(require_uint256(myScalingFactor * getPerformanceBps()));
        if(estimateSharesFeeAmount > 0) positiveFee = true;
            
        redeemUnderlying@withrevert(e, tby);
    }
    bool lastRev = lastReverted;
    
    uint256 sharesStakingPost = sharesOf(e, getStakeupStaking());

    assert(!lastRev && positiveFee => sharesStakingPost > sharesStakingPre);
}

// ST-11 Remaining balance of underlying assets is accurate post poke	
rule remainingBalanceAccuratePostPoke() {

    env e;

    address latestPool = getLatestPool();
    require(asset == latestPool);
    require(underlying == getUnderlyingToken());
    require(asset.UNDERLYING_TOKEN(e) == underlying);

    bool isWithin24Hours = within24HoursOfCommitPhaseEnd(e, latestPool, asset.state(e));
    bool isEligible = isEligibleForAdjustment(asset.state(e));
    uint256 underlyingBalance = underlying.balanceOf(e, currentContract);
    uint256 latestTbyBalance = asset.balanceOf(e, currentContract);
    uint256 lastDepositAmount = isWithin24Hours ? require_uint256(getLastDepositAmount() + underlyingBalance) : getLastDepositAmount();
    uint256 depositDifference = lastDepositAmount <= latestTbyBalance ? 0 : assert_uint256(lastDepositAmount - latestTbyBalance);
    uint256 remainingBalanceAfterAutomint = isWithin24Hours
        ? (underlyingBalance > 0 ? 0 : getRemainingBalance())
        : getRemainingBalance();

    uint256 calcRemainingBalance = isWithin24Hours 
        ? (isEligible ? require_uint256(remainingBalanceAfterAutomint + depositDifference) : remainingBalanceAfterAutomint)
        : (isEligible ? require_uint256(getRemainingBalance() + depositDifference) : getRemainingBalance());

    poke(e);

    assert(calcRemainingBalance == getRemainingBalance());
}

// ST-12 Only RedemptionNFT can withdraw	
rule onlyRedemptionNFTCanWithdraw() {

    env e;
    address account;
    uint256 shares;

    withdraw@withrevert(e, account, shares);
    bool lastRev = lastReverted;

    assert(e.msg.sender != _RedemptionNFT => lastRev);
    assert(!lastRev => e.msg.sender == _RedemptionNFT);
}

// ST-13 Only assets with underlying equal to _underlyingToken can be deposited to the contract	
rule onlyAssetsWithCorrectUnderlyingCanBeDeposited() {

    env e;
    address tby;
    uint256 amount;

    require(tby == assetB);

    depositTby@withrevert(e, tby, amount);
    bool lastRev = lastReverted;

    assert(assetB.UNDERLYING_TOKEN(e) != getUnderlyingToken() => lastRev);
    assert(!lastRev => assetB.UNDERLYING_TOKEN(e) == getUnderlyingToken());
}

// ST-14 Deposit and redeemUnderlying only support assets that are active in the Bloom registry
rule depositAndRedeemUnderlyingOnlySupportActiveAssets(method f) 
    filtered { 
        f -> 
            f.selector == sig:redeemUnderlying(address).selector ||
            f.selector == sig:depositTby(address, uint256).selector 
    } {

    env e;
    address tby;
    uint256 amount;

    bool active = _registry.tokenInfos(e, tby).active;

    if(f.selector == sig:redeemUnderlying(address).selector){
        depositTby@withrevert(e, tby, amount);
    }
    else{
        redeemUnderlying@withrevert(e, tby);
    }
    
    bool lastRev = lastReverted;

    assert(!active => lastRev);
}

// ST-15 Getters only revert if passed positive msg.value
rule gettersOnlyRevertIfPositiveValueSent(method f)
    filtered { 
        f -> 
            f.selector == sig:getWstTBY().selector ||
            f.selector == sig:getUnderlyingToken().selector ||
            f.selector == sig:getBloomFactory().selector ||
            f.selector == sig:getExchangeRateRegistry().selector ||
            f.selector == sig:getStakeupStaking().selector ||
            f.selector == sig:getRewardManager().selector ||
            f.selector == sig:getRedemptionNFT().selector ||
            f.selector == sig:getMintBps().selector ||
            f.selector == sig:getRedeemBps().selector ||
            f.selector == sig:getPerformanceBps().selector ||
            f.selector == sig:circulatingSupply().selector ||
            f.selector == sig:totalSupply().selector ||
            f.selector == sig:getTotalUsd().selector ||
            f.selector == sig:getTotalShares().selector ||
            f.selector == sig:isTbyRedeemed(address).selector ||
            f.selector == sig:allowance(address, address).selector ||
            f.selector == sig:sharesOf(address).selector
    } {

    env e;
    calldataarg args;
    address addr1;
    address addr2;

    if(f.selector == sig:isTbyRedeemed(address).selector){
        isTbyRedeemed@withrevert(e, addr1);
    }
    else if(f.selector == sig:allowance(address, address).selector){
        allowance@withrevert(e, addr1, addr2);
    }
    else if(f.selector == sig:sharesOf(address).selector){
        sharesOf@withrevert(e, addr1);
    }
    else{
        f@withrevert(e, args);
    }

    bool lastRev = lastReverted;

    assert(lastRev <=> e.msg.value > 0);
}

// ST-16 Consistency check for approve
rule approveConsistencyCheck() {

    address spender;
    uint256 amount;

    env e;

    bool val = approve@withrevert(e, spender, amount);
    bool lastRev = lastReverted;

    assert(lastRev <=> (
            e.msg.value > 0 ||
            e.msg.sender == 0 ||
            spender == 0
        )
    );
    assert(!lastRev => val && allowance(e.msg.sender, spender) == amount);
}

// ST-17 Consistency check for increaseAllowance
rule increaseAllowanceConsistencyCheck() {

    address spender;
    uint256 addedValue;

    env e;

    uint256 allowancePre =  allowance(e.msg.sender, spender);

    bool val = increaseAllowance@withrevert(e, spender, addedValue);
    bool lastRev = lastReverted;

    assert(lastRev <=> (
            e.msg.value > 0 ||
            e.msg.sender == 0 ||
            spender == 0 ||
            allowancePre + addedValue > max_uint256
        )
    );
    assert(!lastRev => val && allowance(e.msg.sender, spender) == assert_uint256(allowancePre + addedValue));
}

// ST-18 Consistency check for decreaseAllowance
rule decreaseAllowanceConsistencyCheck() {

    address spender;
    uint256 subtractedValue;

    env e;

    uint256 allowancePre =  allowance(e.msg.sender, spender);

    bool val = decreaseAllowance@withrevert(e, spender, subtractedValue);
    bool lastRev = lastReverted;

    assert(lastRev <=> (
            e.msg.value > 0 ||
            e.msg.sender == 0 ||
            spender == 0 ||
            allowancePre < subtractedValue
        )
    );
    assert(!lastRev => val && allowance(e.msg.sender, spender) == assert_uint256(allowancePre - subtractedValue));
}

// ST-19 Consistency check for _deposit
rule depositConsistencyCheck() {

    address token;
    uint256 amount;
    bool isTby;

    env e;

    requireScalingFactor(e);

    uint256 mintRewardsRemainingPre = getMintRewardsRemaining();
    uint256 amountScaled = require_uint256(amount * _scalingFactor());
    uint256 eligibleAmount = min(amountScaled, mintRewardsRemainingPre);
    uint256 rewardAmount = require_uint256((_RewardManager.LAUNCH_MINT_REWARDS_HARNESS(e) * eligibleAmount) /
            _RewardManager.STTBY_MINT_THREASHOLD_HARNESS(e));

    uint256 stakeUpTokenPre =  _StakeupToken.balanceOf(e, getStakeupStaking());

    _depositExternal(e, token, amount, isTby);

    uint256 stakeUpTokenPost =  _StakeupToken.balanceOf(e, getStakeupStaking());

    assert(mintRewardsRemainingPre > 0 => require_uint256(stakeUpTokenPost - stakeUpTokenPre) == rewardAmount);
}

// ST-20 Consistency check for _processProceeds
rule processProceedsConsistencyCheck() {

    uint256 proceeds;
    uint256 yield;

    env e;

    requireScalingFactor(e);
    require(getPerformanceBps() == 0);

    uint256 tbyValuePre =  _getCurrentTbyValueExternal(e);

    _processProceedsExternal(e, proceeds, yield);

    assert(getTotalUsd() == assert_uint256(tbyValuePre + getRemainingBalance() * _scalingFactor()));
}