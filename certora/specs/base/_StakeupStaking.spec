import "./ReentrancyGuard/ReentrancyGuard_StakeUpStaking.spec";

//////////////////// USING ////////////////////////

using StakeUpStakingHarness as _StakeUpStaking;

/////////////////// METHODS ///////////////////////

methods {

    // StakeUpStaking
    function _StakeUpStaking.stake(uint256) external;
    function _StakeUpStaking.delegateStake(address receiver, uint256 stakeupAmount) external;
    function _StakeUpStaking.unstake(uint256 stakeupAmount, bool harvestRewards) external;
    function _StakeUpStaking.harvest() external;
    function _StakeUpStaking.processFees() external;
    function _StakeUpStaking.claimableRewards(address account) external returns (uint256) envfree;
    function _StakeUpStaking.getStakupToken() external returns (address) envfree;
    function _StakeUpStaking.getStTBY() external returns (address) envfree;
    function _StakeUpStaking.getRewardManager() external returns (address) envfree;
    function _StakeUpStaking.totalStakeUpStaked() external returns (uint256) envfree;
    function _StakeUpStaking.getRewardData() external returns (IStakeUpStaking.RewardData) envfree;
    function _StakeUpStaking.getUserStakingData(address user) external returns (IStakeUpStaking.StakingData) envfree;
    function _StakeUpStaking.getLastRewardBlock() external returns (uint256) envfree;

    // SUPVesting
    function _StakeUpStaking.vestTokens(address account, uint256 amount) external;
    function _StakeUpStaking.claimAvailableTokens() external returns (uint256);
    function _StakeUpStaking.getAvailableTokens(address account) external returns (uint256);
    function _StakeUpStaking.getCurrentBalance(address account) external returns (uint256) envfree;
}

///////////////// DEFINITIONS /////////////////////

definition INITIAL_REWARD_INDEX() returns mathint = 1;
definition CLIFF_DURATION() returns mathint = 52 * 7 * 24 * 60 * 60; // 52 weeks
definition VESTING_DURATION() returns mathint = 3 * CLIFF_DURATION();

////////////////// FUNCTIONS //////////////////////

function envBlockTimestampAssumptions(env e) {
    require(e.block.timestamp > 0 && e.block.timestamp < max_uint40);
}

function init_StakeUpStaking(env e) {
    requireInvariant lastRewardBlockGeqBlockNumber(e);
    requireInvariant vestingTimestampLeqBlockTimestamp(e);
    requireInvariant amountStakedLeqTotalStakeUpStaked;
    requireInvariant userStakingDataIndexLeqrewardDataIndex;
    requireInvariant startingBalanceAlwaysGeqCurrentBalance;
    requireInvariant tokenAllocationsZeroTimestampSolvency(e);
    envBlockTimestampAssumptions(e);
}

///////////////// GHOSTS & HOOKS //////////////////

//
// Ghost copy of `RewardData private _rewardData;`
//

// uint128 index;

ghost mathint ghostRewardDataIndex {
    init_state axiom ghostRewardDataIndex == 0;
    axiom ghostRewardDataIndex >= 0 && ghostRewardDataIndex <= max_uint128;
}

ghost mathint ghostRewardDataIndexPrev {
    init_state axiom ghostRewardDataIndexPrev == 0;
    axiom ghostRewardDataIndexPrev >= 0 && ghostRewardDataIndexPrev <= max_uint128;
}

hook Sload uint128 val _StakeUpStaking._rewardData.index STORAGE {
    require(require_uint128(ghostRewardDataIndex) == val);
} 

hook Sstore _StakeUpStaking._rewardData.index uint128 val (uint128 valPrev) STORAGE {
    ghostRewardDataIndexPrev = valPrev;
    ghostRewardDataIndex = val;
}

// uint128 lastBalance;

ghost mathint ghostRewardDataLastBalance {
    init_state axiom ghostRewardDataLastBalance == 0;
    axiom ghostRewardDataLastBalance >= 0 && ghostRewardDataLastBalance <= max_uint128;
}

ghost mathint ghostRewardDataLastBalancePrev {
    init_state axiom ghostRewardDataLastBalancePrev == 0;
    axiom ghostRewardDataLastBalancePrev >= 0 && ghostRewardDataLastBalancePrev <= max_uint128;
}

hook Sload uint128 val _StakeUpStaking._rewardData.lastBalance STORAGE {
    require(require_uint128(ghostRewardDataLastBalance) == val);
} 

hook Sstore _StakeUpStaking._rewardData.lastBalance uint128 val (uint128 valPrev) STORAGE {
    ghostRewardDataLastBalancePrev = valPrev;
    ghostRewardDataLastBalance = val;
}

//
// Ghost copy of `uint256 private _totalStakeUpStaked;`
//

ghost mathint ghostTotalStakeUpStaked {
    init_state axiom ghostTotalStakeUpStaked == 0;
    axiom ghostTotalStakeUpStaked >= 0 && ghostTotalStakeUpStaked <= max_uint256;
}

ghost mathint ghostTotalStakeUpStakedPrev {
    init_state axiom ghostTotalStakeUpStakedPrev == 0;
    axiom ghostTotalStakeUpStakedPrev >= 0 && ghostTotalStakeUpStakedPrev <= max_uint256;
}

hook Sload uint256 val _StakeUpStaking._totalStakeUpStaked STORAGE {
    require(require_uint256(ghostTotalStakeUpStaked) == val);
} 

hook Sstore _StakeUpStaking._totalStakeUpStaked uint256 val (uint256 valPrev) STORAGE {
    ghostTotalStakeUpStakedPrev = valPrev;
    ghostTotalStakeUpStaked = val;
}

//
// Ghost copy of `uint256 private _lastRewardBlock;`
//

ghost mathint ghostLastRewardBlock {
    init_state axiom ghostLastRewardBlock == 0;
    axiom ghostLastRewardBlock >= 0 && ghostLastRewardBlock <= max_uint256;
}

ghost mathint ghostLastRewardBlockPrev {
    init_state axiom ghostLastRewardBlockPrev == 0;
    axiom ghostLastRewardBlockPrev >= 0 && ghostLastRewardBlockPrev <= max_uint256;
}

hook Sload uint256 val _StakeUpStaking._lastRewardBlock STORAGE {
    require(require_uint256(ghostLastRewardBlock) == val);
} 

hook Sstore _StakeUpStaking._lastRewardBlock uint256 val (uint256 valPrev) STORAGE {
    ghostLastRewardBlockPrev = valPrev;
    ghostLastRewardBlock = val;
}

//
// Ghost copy of `mapping(address => StakingData) private _stakingData;`
//

// uint256 amountStaked;

ghost mapping (address => mathint) ghostStakingDataAmountStaked {
    init_state axiom forall address i. ghostStakingDataAmountStaked[i] == 0;
    axiom forall address i. ghostStakingDataAmountStaked[i] >= 0 && ghostStakingDataAmountStaked[i] <= max_uint128;
}

ghost mapping (address => mathint) ghostStakingDataAmountStakedPrev {
    init_state axiom forall address i. ghostStakingDataAmountStakedPrev[i] == 0;
    axiom forall address i. ghostStakingDataAmountStakedPrev[i] >= 0 && ghostStakingDataAmountStakedPrev[i] <= max_uint128;
}

hook Sload uint256 val _StakeUpStaking._stakingData[KEY address i].amountStaked STORAGE {
    require(require_uint256(ghostStakingDataAmountStaked[i]) == val);
} 

hook Sstore _StakeUpStaking._stakingData[KEY address i].amountStaked uint256 val (uint256 valPrev) STORAGE {
    ghostStakingDataAmountStakedPrev[i] = valPrev;
    ghostStakingDataAmountStaked[i] = val;
}

// uint128 index;

ghost mapping (address => mathint) ghostStakingDataIndex {
    init_state axiom forall address i. ghostStakingDataIndex[i] == 0;
    axiom forall address i. ghostStakingDataIndex[i] >= 0 && ghostStakingDataIndex[i] <= max_uint128;
}

ghost mapping (address => mathint) ghostStakingDataIndexPrev {
    init_state axiom forall address i. ghostStakingDataIndexPrev[i] == 0;
    axiom forall address i. ghostStakingDataIndexPrev[i] >= 0 && ghostStakingDataIndexPrev[i] <= max_uint128;
}

hook Sload uint128 val _StakeUpStaking._stakingData[KEY address i].index STORAGE {
    require(require_uint128(ghostStakingDataIndex[i]) == val);
} 

hook Sstore _StakeUpStaking._stakingData[KEY address i].index uint128 val (uint128 valPrev) STORAGE {
    ghostStakingDataIndexPrev[i] = valPrev;
    ghostStakingDataIndex[i] = val;
}

// uint128 rewardsAccrued;

ghost mapping (address => mathint) ghostStakingDataRewardsAccrued {
    init_state axiom forall address i. ghostStakingDataRewardsAccrued[i] == 0;
    axiom forall address i. ghostStakingDataRewardsAccrued[i] >= 0 && ghostStakingDataRewardsAccrued[i] <= max_uint128;
}

ghost mapping (address => mathint) ghostStakingDataRewardsAccruedPrev {
    init_state axiom forall address i. ghostStakingDataRewardsAccruedPrev[i] == 0;
    axiom forall address i. ghostStakingDataRewardsAccruedPrev[i] >= 0 && ghostStakingDataRewardsAccruedPrev[i] <= max_uint128;
}

hook Sload uint128 val _StakeUpStaking._stakingData[KEY address i].rewardsAccrued STORAGE {
    require(require_uint128(ghostStakingDataRewardsAccrued[i]) == val);
} 

hook Sstore _StakeUpStaking._stakingData[KEY address i].rewardsAccrued uint128 val (uint128 valPrev) STORAGE {
    ghostStakingDataRewardsAccruedPrev[i] = valPrev;
    ghostStakingDataRewardsAccrued[i] = val;
}

//
// Ghost copy of `uint256 internal _totalStakeUpVesting;`
//

ghost mathint ghostTotalStakeUpVesting {
    init_state axiom ghostTotalStakeUpVesting == 0;
    axiom ghostTotalStakeUpVesting >= 0 && ghostTotalStakeUpVesting <= max_uint256;
}

ghost mathint ghostTotalStakeUpVestingPrev {
    init_state axiom ghostTotalStakeUpVestingPrev == 0;
    axiom ghostTotalStakeUpVestingPrev >= 0 && ghostTotalStakeUpVestingPrev <= max_uint256;
}

hook Sload uint256 val _StakeUpStaking._totalStakeUpVesting STORAGE {
    require(require_uint256(ghostTotalStakeUpVesting) == val);
} 

hook Sstore _StakeUpStaking._totalStakeUpVesting uint256 val (uint256 valPrev) STORAGE {
    ghostTotalStakeUpVestingPrev = valPrev;
    ghostTotalStakeUpVesting = val;
}

//
// Ghost copy of `mapping(address => VestedAllocation) internal _tokenAllocations;`
//

// uint256 startingBalance;

ghost mapping (address => mathint) ghostTAStartingBalance {
    init_state axiom forall address i. ghostTAStartingBalance[i] == 0;
    axiom forall address i. ghostTAStartingBalance[i] >= 0 && ghostTAStartingBalance[i] <= max_uint256;
}

ghost mapping (address => mathint) ghostTAStartingBalancePrev {
    init_state axiom forall address i. ghostTAStartingBalancePrev[i] == 0;
    axiom forall address i. ghostTAStartingBalancePrev[i] >= 0 && ghostTAStartingBalancePrev[i] <= max_uint256;
}

hook Sload uint256 val _StakeUpStaking._tokenAllocations[KEY address i].startingBalance STORAGE {
    require(require_uint256(ghostTAStartingBalance[i]) == val);
} 

hook Sstore _StakeUpStaking._tokenAllocations[KEY address i].startingBalance uint256 val (uint256 valPrev) STORAGE {
    ghostTAStartingBalancePrev[i] = valPrev;
    ghostTAStartingBalance[i] = val;
}

// uint256 currentBalance;

ghost mapping (address => mathint) ghostTACurrentBalance {
    init_state axiom forall address i. ghostTACurrentBalance[i] == 0;
    axiom forall address i. ghostTACurrentBalance[i] >= 0 && ghostTACurrentBalance[i] <= max_uint256;
}

ghost mapping (address => mathint) ghostTACurrentBalancePrev {
    init_state axiom forall address i. ghostTACurrentBalancePrev[i] == 0;
    axiom forall address i. ghostTACurrentBalancePrev[i] >= 0 && ghostTACurrentBalancePrev[i] <= max_uint256;
}

hook Sload uint256 val _StakeUpStaking._tokenAllocations[KEY address i].currentBalance STORAGE {
    require(require_uint256(ghostTACurrentBalance[i]) == val);
} 

hook Sstore _StakeUpStaking._tokenAllocations[KEY address i].currentBalance uint256 val (uint256 valPrev) STORAGE {
    ghostTACurrentBalancePrev[i] = valPrev;
    ghostTACurrentBalance[i] = val;
}

// uint256 vestingStartTime;

ghost mapping (address => mathint) ghostTAVestingStartTime {
    init_state axiom forall address i. ghostTAVestingStartTime[i] == 0;
    axiom forall address i. ghostTAVestingStartTime[i] >= 0 && ghostTAVestingStartTime[i] <= max_uint256;
}

ghost mapping (address => mathint) ghostTAVestingStartTimePrev {
    init_state axiom forall address i. ghostTAVestingStartTimePrev[i] == 0;
    axiom forall address i. ghostTAVestingStartTimePrev[i] >= 0 && ghostTAVestingStartTimePrev[i] <= max_uint256;
}

hook Sload uint256 val _StakeUpStaking._tokenAllocations[KEY address i].vestingStartTime STORAGE {
    require(require_uint256(ghostTAVestingStartTime[i]) == val);
} 

hook Sstore _StakeUpStaking._tokenAllocations[KEY address i].vestingStartTime uint256 val (uint256 valPrev) STORAGE {
    ghostTAVestingStartTimePrev[i] = valPrev;
    ghostTAVestingStartTime[i] = val;
}

///////////////// PROPERTIES //////////////////////

// SK-04 For all users, userStakingData.index is always less than or equal to _rewardData.index
invariant userStakingDataIndexLeqrewardDataIndex() forall address a. ghostStakingDataIndex[a] <= ghostRewardDataIndex;

// SK-05 _lastRewardBlock always greater or equal to block number
invariant lastRewardBlockGeqBlockNumber(env eInv) ghostLastRewardBlock >= to_mathint(eInv.block.number) {
    preserved with (env eFunc) {
        require(eInv.block.number == eFunc.block.number);
    }
}

// SK-12 No uses's amount staked could be greater than total staked
invariant amountStakedLeqTotalStakeUpStaked() forall address a. ghostStakingDataAmountStaked[a] <= ghostTotalStakeUpStaked {
    preserved _StakeUpStaking.unstake(uint256 stakeupAmount, bool harvestRewards) with (env e) {
        // Test unstake with only one sender's address
        require(forall address a. a != e.msg.sender => ghostStakingDataAmountStaked[a] == 0);
    }
}

// VT-04 For all allocations, `startingBalance` is always greater than or equal to currentBalance
invariant startingBalanceAlwaysGeqCurrentBalance() forall address a. ghostTAStartingBalance[a] >= ghostTACurrentBalance[a];

// VT-10 | Vesting timestamp always equal or greater `block.timestamp`
invariant vestingTimestampLeqBlockTimestamp(env eInv) 
    forall address a. ghostTAVestingStartTime[a] == 0 || ghostTAVestingStartTime[a] == to_mathint(eInv.block.timestamp) {
    preserved with (env eFunc) {
        require(eInv.block.timestamp == eFunc.block.timestamp);
    }
}

// VT-11 A user's token allocations empty when `block.timestamp` not set
invariant tokenAllocationsZeroTimestampSolvency(env eInv) forall address a. ghostTAVestingStartTime[a] == 0 
    => ghostTAStartingBalance[a] == 0 && ghostTACurrentBalance[a] == 0 {
    preserved with (env eFunc) {
        require(eInv.block.timestamp == eFunc.block.timestamp);
        envBlockTimestampAssumptions(eFunc);
    }
}