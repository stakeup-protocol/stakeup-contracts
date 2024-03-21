import "./base/_StakeupStaking.spec";
import "./base/_StakeupToken.spec";
import "./base/_StTBY.spec";

///////////////// DEFINITIONS /////////////////////

definition WAD_CVL() returns mathint = 10^18;

////////////////// FUNCTIONS //////////////////////

function isStakeActionHappened(address user) returns bool {
    return ghostTotalStakeUpStaked > ghostTotalStakeUpStakedPrev 
        || ghostStakingDataAmountStaked[user] > ghostStakingDataAmountStakedPrev[user];
}

function mulWadCVL(mathint x, mathint y) returns mathint {
    return (x * y) / WAD_CVL();
}

///////////////// PROPERTIES //////////////////////

use builtin rule sanity; 

// StakeupStaking valid state
use invariant amountStakedLeqTotalStakeUpStaked;
use invariant vestingTimestampLeqBlockTimestamp;
use invariant lastRewardBlockGeqBlockNumber;
use invariant userStakingDataIndexLeqrewardDataIndex;
use invariant startingBalanceAlwaysGeqCurrentBalance;
use invariant tokenAllocationsZeroTimestampSolvency;

// StakeupToken valid state
use invariant totalSupplyLeqMaxSupply;

// SK-01 Any stake or unstake action changes token balances
invariant stakeUnstakeMoveTokens(address user) isStakeActionHappened(user)
    // stake increase current contract balance and decrease user balance
    ? ghostTotalStakeUpStaked - ghostTotalStakeUpStakedPrev == ghostErc20BalancesPrev_StakeupToken[user] - ghostErc20Balances_StakeupToken[user]
        && ghostTotalStakeUpStaked - ghostTotalStakeUpStakedPrev == ghostErc20Balances_StakeupToken[currentContract] - ghostErc20BalancesPrev_StakeupToken[currentContract]
    // unstake increase user's balance and decrease current contract balance
    : ghostTotalStakeUpStakedPrev - ghostTotalStakeUpStaked == ghostErc20Balances_StakeupToken[user] - ghostErc20BalancesPrev_StakeupToken[user]
        && ghostTotalStakeUpStakedPrev - ghostTotalStakeUpStaked == ghostErc20BalancesPrev_StakeupToken[currentContract] - ghostErc20Balances_StakeupToken[currentContract]
// claimAvailableTokens() changes balance of ghostErc20BalancesPrev_StakeupToken
filtered { f -> f.selector != sig:claimAvailableTokens().selector } { 
    preserved stake(uint256 stakeupAmount) with (env e) {
        // unsafe uint128 conversion
        require(stakeupAmount <= max_uint128);
        require(user == e.msg.sender);
        init_StakeupToken();
        require(e.msg.sender != currentContract);
        require(e.msg.sender != getRewardManager());
    }
    preserved delegateStake(address receiver, uint256 stakeupAmount) with (env e) {
        // unsafe uint128 conversion
        require(stakeupAmount <= max_uint128);
        require(user == e.msg.sender);
        init_StakeupToken();
        require(e.msg.sender != currentContract);
        require(e.msg.sender != getRewardManager());
    }
    preserved unstake(uint256 stakeupAmount, bool harvestRewards) with (env e) {
        // unsafe uint128 conversion
        require(stakeupAmount <= max_uint128);
        require(user == e.msg.sender);
        init_StakeupToken();
        require(e.msg.sender != currentContract);
    }
}

// SK-02 Total staked SUP cannot exceed the total SUP supply
rule totalStakeUpStakedLeqTotalSUPsupply(env e, method f, calldataarg args) {

    init_StakeupToken();
    init_StakeupStaking(e);

    require(ghostTotalStakeUpStaked <= ghostErc20TotalSupply_StakeupToken);
    
    // If the reward manager is the sender, then there is no need to transfer tokens
    // as the tokens will be minted directly to the staking contract
    require(e.msg.sender != getRewardManager());

    require(ghostErc20Balances_StakeupToken[e.msg.sender] 
        <= ghostErc20TotalSupply_StakeupToken - ghostTotalStakeUpStaked);

    f(e, args);

    assert(ghostTotalStakeUpStaked <= ghostErc20TotalSupply_StakeupToken);
}

// SK-03 Claimable rewards are calculated based on staked amounts and global reward index
rule claimableRewardsIntegrity(env e, address user) {

    init_StakeupStaking(e);

    require(ghostRewardDataIndex != 0);
    require(ghostRewardDataIndex != ghostStakingDataIndex[user]);
    require(ghostStakingDataIndex[user] >= INITIAL_REWARD_INDEX());

    mathint amountStaked = ghostStakingDataAmountStaked[user] + ghostTACurrentBalance[user];
    mathint delta = ghostRewardDataIndex - ghostStakingDataIndex[user];
    mathint expectedRewards = ghostStakingDataRewardsAccrued[user] + mulWadCVL(amountStaked, delta);

    mathint rewards = claimableRewards(user);

    assert(expectedRewards == rewards);
}

// SK-06 For all users, `totalStakeUpStaked` changes the same way as `_stakingData[msg.sender].amountStaked`
invariant totalStakeUpStakedSolvency(address user) isStakeActionHappened(user)
    // stake
    ? ghostTotalStakeUpStaked - ghostTotalStakeUpStakedPrev == ghostStakingDataAmountStaked[user] - ghostStakingDataAmountStakedPrev[user]
    // unstake
    : ghostTotalStakeUpStakedPrev - ghostTotalStakeUpStaked == ghostStakingDataAmountStakedPrev[user] - ghostStakingDataAmountStaked[user] 
{ 
    preserved stake(uint256 stakeupAmount) with (env e) {
        // unsafe uint128 conversion
        require(stakeupAmount <= max_uint128);
        require(user == e.msg.sender);
        // If the reward manager is the sender, then there is no need to transfer tokens
        // as the tokens will be minted directly to the staking contract
        require(e.msg.sender != getRewardManager());
    }
    preserved delegateStake(address receiver, uint256 stakeupAmount) with (env e) {
        // unsafe uint128 conversion
        require(stakeupAmount <= max_uint128);
        require(user == receiver);
    }
    preserved unstake(uint256 stakeupAmount, bool harvestRewards) with (env e) {
        // unsafe uint128 conversion
        require(stakeupAmount <= max_uint128);
        require(user == e.msg.sender);
        require(e.msg.sender != currentContract);
    }
}

// SK-07 Staking balance cannot decrease unless by explicit unstake or reward claim actions
rule stakingBalanceCannotDecreaseUnlessUnstake(env e, method f, calldataarg args) {

    require(ghostStakingDataAmountStaked[e.msg.sender] == ghostStakingDataAmountStakedPrev[e.msg.sender]);

    f(e, args);

    // Staked amount decreased
    assert(ghostStakingDataAmountStaked[e.msg.sender] < ghostStakingDataAmountStakedPrev[e.msg.sender]
        => f.selector == sig:unstake(uint256, bool).selector
    );
}

// SK-08 For all users, userStakingData.index is monotonically increasing
invariant userStakingDataIndexIncreasing() 
    // Ignore INITIAL_REWARD_INDEX set, the only case when index could move from 1 to 0
    forall address user. ghostStakingDataIndexPrev[user] != 1 => ghostStakingDataIndex[user] >= ghostStakingDataIndexPrev[user] {
    preserved with (env e) {
        init_StakeupStaking(e);
    }
}

// SK-09 _rewardData.index is updated with every state modify function
rule rewardDataIndexUpdatePossibility(env e, method f, calldataarg args) 
    // Every non-view function could update reward index
    filtered { f -> !f.isView } {

    require(ghostRewardDataIndex == ghostRewardDataIndexPrev);

    f(e, args);

    satisfy(ghostRewardDataIndex != ghostRewardDataIndexPrev);
}

// SK-10 The last reward distribution block is updated on every reward distribution action
invariant rewardDistributionBlockUpdatedOnEveryRewardDistribution(env eInv) 
    ghostRewardDataIndex != ghostRewardDataIndexPrev => ghostLastRewardBlock == to_mathint(eInv.block.number) {
    preserved with (env eFunc) {
        require(eInv.block.number == eFunc.block.number);
        require(ghostRewardDataIndex == ghostRewardDataIndexPrev);
    }
}

// SK-11 _rewardData.index is monotonically increasing
invariant rewardDataIndexIncreasing() ghostRewardDataIndex >= ghostRewardDataIndexPrev;

// VT-01 Total vested SUP cannot exceed the total SUP supply
invariant totalVestingLeqSUPsupply() ghostTotalStakeUpVesting <= ghostErc20TotalSupply_StakeupToken {
    preserved with (env e) {
        init_StakeupStaking(e);
        init_StakeupToken();
    }
    preserved vestTokens(address account, uint256 amount) with (env e) {
        init_StakeupStaking(e);
        init_StakeupToken();
        // Only StakeupToken can execute vestTokens() and mints amount of tokens preliminarily 
        require(ghostErc20TotalSupply_StakeupToken - to_mathint(amount) >= ghostTotalStakeUpVesting);
    }
}

// VT-02 Sum of _totalStakeUpStaked and _totalStakeUpVesting is always less than or equal to IERC20(address(_stakeupToken)).balanceOf(address(VESTING_CONTRACT))
invariant sumOftotalStakedAndVestingLeqSUPBalanceOfCurrent() 
    ghostTotalStakeUpStaked + ghostTotalStakeUpVesting <= ghostErc20Balances_StakeupToken[currentContract] {
    preserved with (env e) {
        init_StakeupStaking(e);
        init_StakeupToken();
        // RewardManage can execute stake() and mints amount of tokens preliminarily 
        require(e.msg.sender != getRewardManager() && e.msg.sender != currentContract);
    }
    preserved vestTokens(address account, uint256 amount) with (env e) {
        init_StakeupStaking(e);
        init_StakeupToken();
        // Only StakeupToken can execute vestTokens() and mints amount of tokens preliminarily 
        require(ghostErc20Balances_StakeupToken[currentContract] - to_mathint(amount) >= ghostTotalStakeUpStaked + ghostTotalStakeUpVesting);
    }
}

// VT-03 Vested tokens are locked until the cliff period has passed
rule vestedTokensLockedUntilCliffPeriodPassed(env e) {

    mathint claimed = claimAvailableTokens(e);

    assert(claimed != 0 => to_mathint(e.block.timestamp) - ghostTAVestingStartTime[e.msg.sender] >= CLIFF_DURATION());
}

// VT-05 Vested tokens are released linearly after the cliff period until the end of the vesting duration
rule vestedReleasedLinearlyAfterCliffPeriod(env e) {

    requireInvariant startingBalanceAlwaysGeqCurrentBalance;

    // The time that has elapsed that is valid for vesting purposes
    mathint timeElapsed = to_mathint(e.block.timestamp) - ghostTAVestingStartTime[e.msg.sender] > VESTING_DURATION()
        ? VESTING_DURATION()
        : to_mathint(e.block.timestamp) - ghostTAVestingStartTime[e.msg.sender];
    
    mathint claimedTokens = ghostTAStartingBalance[e.msg.sender] - ghostTACurrentBalance[e.msg.sender];
    mathint expectedAvailable = timeElapsed < CLIFF_DURATION()
        ? 0
        : (ghostTAStartingBalance[e.msg.sender] * timeElapsed) / VESTING_DURATION() - claimedTokens;

    mathint available = getAvailableTokens(e, e.msg.sender);

    assert(expectedAvailable == available);
}

// VT-06 A user's vested balance decreases as they claim vested tokens
rule userBalanceDecreasesWhenClaim(env e, method f, calldataarg args) {

    // A user's token allocations empty when `block.timestamp` not set
    requireInvariant tokenAllocationsZeroTimestampSolvency(e);

    // User has claimable tokens
    require(getAvailableTokens(e, e.msg.sender) != 0);

    mathint before = ghostTACurrentBalance[e.msg.sender];

    f(e, args);

    mathint after = ghostTACurrentBalance[e.msg.sender];

    // Balance decreases only with claimAvailableTokens() and claimAvailableTokens() should decrease balance
    assert(before > after <=> f.selector == sig:claimAvailableTokens().selector);
}

// VT-07 The vesting start time is set upon the first vesting action for a user 
rule vestingStartTimeSetUponAction(env e, method f, calldataarg args) {

    // A user's token allocations empty when `block.timestamp` not set
    requireInvariant tokenAllocationsZeroTimestampSolvency(e);
    envBlockTimestampAssumptions(e);

    mathint before = ghostTAVestingStartTime[e.msg.sender];

    f(e, args);

    mathint after = ghostTAVestingStartTime[e.msg.sender];

    assert(before != after => ghostTAStartingBalance[e.msg.sender] == ghostTACurrentBalance[e.msg.sender]);
}

// VT-08 For two timestamps after `VESTING_DURATION`, the value returned by getAvailableTokens should not change
rule getAvailableTokensNotChangesAfterVestingDuration(env e1, env e2, address user) {

    mathint timeElapsed1 = to_mathint(e1.block.timestamp) - ghostTAVestingStartTime[user];
    mathint amount1 = getAvailableTokens(e1, user);
    
    mathint timeElapsed2 = to_mathint(e2.block.timestamp) - ghostTAVestingStartTime[user];
    mathint amount2 = getAvailableTokens(e2, user);

    assert(timeElapsed1 > VESTING_DURATION() && timeElapsed2 > VESTING_DURATION() 
        => amount1 == amount2
        );
}

// VT-09 Only StakeupToken can execute vestTokens()
rule onlyStakeupTokenCanExecuteVestTokens(env e, calldataarg args) {

    vestTokens@withrevert(e, args);
    bool reverted = lastReverted;

    assert(!reverted => e.msg.sender == _StakeupToken);
}