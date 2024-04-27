import "./base/_RewardManager.spec";
import "./base/_StakeUpToken.spec";
import "./base/_StakeUpStaking.spec";
import "./base/_StTBY.spec";

///////////////// DEFINITIONS /////////////////////

definition DISTRIBUTE_REWARDS_FUNCTIONS(method f) returns bool =
    f.selector == sig:distributePokeRewards(address).selector
    || f.selector == sig:distributeMintRewards(address, uint256).selector;

///////////////// PROPERTIES //////////////////////

use builtin rule sanity; 

// RewardManager valid state
use invariant startTimestampValue;
use invariant pokeRewardsRemainingLimitationInv;
use invariant timeStampsSolvency;

// StakeUpToken valid state
use invariant totalSupplyLeqMaxSupply;

// StakeUpStaking valid state
use invariant amountStakedLeqTotalStakeUpStaked;
use invariant vestingTimestampLeqBlockTimestamp;
use invariant lastRewardBlockGeqBlockNumber;
use invariant userStakingDataIndexLeqrewardDataIndex;
use invariant startingBalanceAlwaysGeqCurrentBalance;
use invariant tokenAllocationsZeroTimestampSolvency;

// RW-01 Rewards are minted and staked directly to the receiver's account
rule rewardsMintStakedToReceiver(env e, address rewardReceiver, uint256 stTBYAmount) {

    init_StakeUpToken();
    init_StakeUpStaking(e);

    mathint stakedBefore = ghostStakingDataAmountStaked[rewardReceiver];
    mathint stakeupStakingBalanceBefore = ghostErc20Balances_StakeUpToken[_StakeUpStaking];

    distributeMintRewards(e, rewardReceiver, stTBYAmount);

    mathint stakedAfter = ghostStakingDataAmountStaked[rewardReceiver];
    mathint stakeupStakingBalanceAfter = ghostErc20Balances_StakeUpToken[_StakeUpStaking];

    assert(stakeupStakingBalanceAfter - stakeupStakingBalanceBefore == stakedAfter - stakedBefore);
}

// RW-02 Mint rewards are proportional to `stTBY` amount
rule mintRewardsProportionalStTBYAmount(env e, address rewardReceiver, uint256 stTBYAmount) {

    init_StakeUpToken();
    init_StakeUpStaking(e);

    mathint rewardAmount = (LAUNCH_MINT_REWARDS_HARNESS() * stTBYAmount) / STTBY_MINT_THREASHOLD_HARNESS();
    require(rewardAmount > 0);

    mathint stakedBefore = ghostStakingDataAmountStaked[rewardReceiver];

    distributeMintRewards(e, rewardReceiver, stTBYAmount);

    mathint stakedAfter = ghostStakingDataAmountStaked[rewardReceiver];

    assert(stakedAfter - stakedBefore == rewardAmount);
}

// RW-03 After calling `distributePokeRewards` or `distributeMintRewards`, the only account that can see its stakeup balance increase is the stakeup staking contract
rule distributeRewardsIncreaseOnlyStakeUpStakingBalance(env e, method f, calldataarg args) 
    filtered { f -> DISTRIBUTE_REWARDS_FUNCTIONS(f) } {

    init_StakeUpToken();
    init_StakeUpStaking(e);

    require(forall address a. ghostErc20Balances_StakeUpToken[a] == ghostErc20BalancesPrev_StakeUpToken[a]);

    f(e, args);

    // If SUP balance of account was changed, that accout should be StakeUpStaking contract
    assert(forall address a. ghostErc20Balances_StakeUpToken[a] != ghostErc20BalancesPrev_StakeUpToken[a] => 
        a == _StakeUpStaking
    );
}

// RW-04 After calling `seedGauges`, the only accounts that can see their stakeup balance increase are the curve gauges
rule seedGaugesIncreaseOnlyCurveBalance(env e, address user) {

    init_StakeUpToken();
    init_StakeUpStaking(e);
    init_RewardManager(e);

    mathint before = ghostErc20Balances_StakeUpToken[user];

    seedGauges(e);

    mathint after = ghostErc20Balances_StakeUpToken[user];

    assert(before != after => user == ghostCurvePoolsCurveGauge[0]);
}

// RW-05 Rewards are only distributed after initialization
rule rewardsOnlyDistributedAfterInitialization(env e, method f, calldataarg args) {

    init_StakeUpToken();
    init_StakeUpStaking(e);

    require(forall address a. ghostStakingDataAmountStaked[a] == ghostStakingDataAmountStakedPrev[a]);
    require(ghostErc20Balances_StakeUpToken[_StakeUpStaking] == ghostErc20BalancesPrev_StakeUpToken[_StakeUpStaking]);

    f@withrevert(e, args);
    bool reverted = lastReverted;

    assert(forall address a. ghostStakingDataAmountStaked[a] != ghostStakingDataAmountStakedPrev[a]
        => !reverted => REWARD_MANAGER_INITIALIZED()
    );
    assert(!reverted && ghostErc20Balances_StakeUpToken[_StakeUpStaking] != ghostErc20BalancesPrev_StakeUpToken[_StakeUpStaking]
        => REWARD_MANAGER_INITIALIZED()
    );

    assert(forall address a. ghostStakingDataAmountStaked[a] != ghostStakingDataAmountStakedPrev[a] 
        => !REWARD_MANAGER_INITIALIZED() => reverted
    );
    assert(ghostErc20Balances_StakeUpToken[_StakeUpStaking] != ghostErc20BalancesPrev_StakeUpToken[_StakeUpStaking] && !REWARD_MANAGER_INITIALIZED() 
        => reverted
    );
}

// RW-06 Only the `StTBY` contract can distribute rewards
rule onlyStTBYDistributeRewards(env e, method f, calldataarg args) {

    init_StakeUpToken();
    init_StakeUpStaking(e);

    require(forall address a. ghostStakingDataAmountStaked[a] == ghostStakingDataAmountStakedPrev[a]);
    require(ghostErc20Balances_StakeUpToken[_StakeUpStaking] == ghostErc20BalancesPrev_StakeUpToken[_StakeUpStaking]);

    f(e, args);

    assert(forall address a. ghostStakingDataAmountStaked[a] != ghostStakingDataAmountStakedPrev[a]
        => e.msg.sender == _StTBY
    );
    assert(ghostErc20Balances_StakeUpToken[_StakeUpStaking] != ghostErc20BalancesPrev_StakeUpToken[_StakeUpStaking]
        => e.msg.sender == _StTBY
    );
}

// RW-07 Gauge seeding does not exceed max rewards and rewards remaining
rule gaugeSeedingNotExceedMaxRewards(env e) {

    init_RewardManager(e);

    mathint gaugeBalanceBefore = ghostErc20Balances_StakeUpToken[ghostCurvePoolsCurveGauge[0]];

    mathint maxRewards0 = ghostCurvePoolsMaxRewards[0];
    mathint rewardsRemaining0 = ghostCurvePoolsRewardsRemaining[0];

    seedGauges(e);

    mathint gaugeBalanceIncrease = ghostErc20Balances_StakeUpToken[ghostCurvePoolsCurveGauge[0]] - gaugeBalanceBefore;

    assert(gaugeBalanceIncrease <= rewardsRemaining0);
}

// RW-08 Poke rewards decrease monotonically until depletion
invariant pokeRewardsRemainingDecrease() ghostPokeRewardsRemainingPrev >= ghostPokeRewardsRemaining 
    filtered { f -> f.selector != sig:initialize().selector } {
    preserved {
        requireInvariant pokeRewardsRemainingLimitationInv;
    }
}

// RW-09 Gauge seeding occurs at correct intervals
rule gaugeSeedingOccursAtCorrectIntervals(env e1, env e2) {

    init_RewardManager(e1);

    require(e2.block.timestamp >= e1.block.timestamp);

    seedGauges(e1);

    // This second call is after first 
    mathint lastSeen = ghostLastSeedTimestamp;
    seedGauges@withrevert(e2);
    bool reverted = lastReverted;

    assert(!reverted && lastSeen != 0 
        => to_mathint(e2.block.timestamp) - lastSeen >= to_mathint(SEED_INTERVAL_HARNESS())
        );
    assert(lastSeen != 0 && to_mathint(e2.block.timestamp) - lastSeen < to_mathint(SEED_INTERVAL_HARNESS()) 
        => reverted
        );
}

// RW-10 The only way `_pokeRewardsRemaining` can increase is by calling initialize in the `RewardManager` 
rule pokeRewardsRemainingSetInInitialized(env e, method f, calldataarg args) {

    require(ghostPokeRewardsRemainingPrev == ghostPokeRewardsRemaining);

    f(e, args);

    assert(ghostPokeRewardsRemaining > ghostPokeRewardsRemainingPrev
        => (ghostPokeRewardsRemaining == POKE_REWARDS() 
            && f.selector == sig:initialize().selector 
            && e.msg.sender == _StakeUpToken
            )
    );
    assert(f.selector == sig:initialize().selector => (
        ghostPokeRewardsRemaining == POKE_REWARDS() && e.msg.sender == _StakeUpToken
    ));
}

// RW-11 After calling `seedGauges`, `distributePokeRewards` or `distributeMintRewards` no account can see their stakeup balance decrease
rule noStakeUpTokenDecrease(env e, method f, calldataarg args) {

    init_StakeUpToken();
    init_StakeUpStaking(e);
    init_RewardManager(e);

    require(forall address a. ghostErc20Balances_StakeUpToken[a] == ghostErc20BalancesPrev_StakeUpToken[a]);

    f(e, args);

    // Balance of any user can only increase or stay the same
    assert(forall address a. ghostErc20Balances_StakeUpToken[a] >= ghostErc20BalancesPrev_StakeUpToken[a]);
}

// RW-12 `_calculateDripAmount` must return a value <= rewards remaining
rule calculateDripAmountReturnLeqRewardsRemaining(env e, uint256 rewardSupply, uint256 startTimestamp, uint256 rewardsRemaining, bool isRewardGauge) {

    mathint amount = calculateDripAmountHarness(e, rewardSupply, startTimestamp, rewardsRemaining, isRewardGauge);

    assert(amount <= to_mathint(rewardsRemaining));
}

// RW-14 Total distributed rewards do not exceed `SUP_MAX_SUPPLY`
rule totalDistributedRewardsNotExceedSUPMaxSupply(env e, method f, calldataarg args)
    filtered { f -> DISTRIBUTE_REWARDS_FUNCTIONS(f) } {

    init_StakeUpToken();
    init_StakeUpStaking(e);

    f@withrevert(e, args);
    bool reverted = lastReverted;

    assert(!reverted => ghostErc20TotalSupply_StakeUpToken <= to_mathint(SUP_MAX_SUPPLY_HARNESS()));
    assert(ghostErc20TotalSupply_StakeUpToken > to_mathint(SUP_MAX_SUPPLY_HARNESS()) => reverted);
}