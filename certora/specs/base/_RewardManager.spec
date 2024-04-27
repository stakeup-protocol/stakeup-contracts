import "./ReentrancyGuard/ReentrancyGuard_RewardManager.spec";

//////////////////// USING ////////////////////////

using RewardManagerHarness as _RewardManager;
using MockCurveGauge as _MockCurveGauge;

/////////////////// METHODS ///////////////////////

methods {

    // RewardManagerHarness
    function _RewardManager.calculateDripAmountHarness(uint256 rewardSupply, uint256 startTimestamp, uint256 rewardsRemaining, bool isRewardGauge) external returns (uint256);
    function _RewardManager.deployCurveGaugesHarness() external;
    function _RewardManager.DECIMAL_SCALING_HARNESS() external returns (uint256) envfree;
    function _RewardManager.SUP_MAX_SUPPLY_HARNESS() external returns (uint256) envfree;
    function _RewardManager.POOL_REWARDS_HARNESS() external returns (uint256) envfree;
    function _RewardManager.LAUNCH_MINT_REWARDS_HARNESS() external returns (uint256) envfree;
    function _RewardManager.STTBY_MINT_THREASHOLD_HARNESS() external returns (uint256) envfree;
    function _RewardManager.POKE_REWARDS_HARNESS() external returns (uint256) envfree;
    function _RewardManager.ONE_YEAR_HARNESS() external returns (uint256) envfree;
    function _RewardManager.SEED_INTERVAL_HARNESS() external returns (uint256) envfree;

    // RewardManager
    function _RewardManager.initialize() external;
    function _RewardManager.distributePokeRewards(address rewardReceiver) external;
    function _RewardManager.distributeMintRewards(address rewardReceiver, uint256 stTBYAmount) external;
    function _RewardManager.getStTBY() external returns (address) envfree;
    function _RewardManager.getStakeUpToken() external returns (address) envfree;
    function _RewardManager.getStakeUpStaking() external returns (address) envfree;

    // CurveGaugeDistributor
    function _RewardManager.seedGauges() external;
    function _RewardManager.getCurvePoolData() external returns (ICurveGaugeDistributor.CurvePoolData[]) envfree;   

    // ICurvePoolGauge (tests/mocks/Curve/MockCurveGauge.sol)
    function _.add_reward(address reward_token, address distributor) external => DISPATCHER(true);
    function _.deposit_reward_token(address reward_token, uint256 amount) external => DISPATCHER(true);
    
    // ICurvePoolFactory (tests/mocks/Curve/MockCurveFactory.sol)
    function _.deploy_gauge(address) external => NONDET;
}

///////////////// DEFINITIONS /////////////////////

definition DECIMAL_SCALING() returns mathint = 10^18;
definition SUP_MAX_SUPPLY() returns mathint = 1000000000 * DECIMAL_SCALING();
definition POKE_REWARDS() returns mathint =  (SUP_MAX_SUPPLY() * 10^16) / DECIMAL_SCALING();

definition REWARD_MANAGER_INITIALIZED() returns bool 
    = ghostStartTimestamp != 0;

////////////////// FUNCTIONS //////////////////////

function init_RewardManager(env e) {

    requireInvariant startTimestampValue(e);
    requireInvariant pokeRewardsRemainingLimitationInv;
    requireInvariant timeStampsSolvency(e);
    
    require(ghostCurvePoolsLength == 1);
    require(ghostCurvePoolsCurveGauge[0] != _MockCurveGauge);
    require(ghostCurvePoolsMaxRewards[0] <= to_mathint(_RewardManager.POOL_REWARDS_HARNESS()));
    require(ghostCurvePoolsRewardsRemaining[0] <= ghostCurvePoolsMaxRewards[0]);
}

///////////////// GHOSTS & HOOKS //////////////////

//
// Ghost copy of `uint256 private _pokeRewardsRemaining;`
//

ghost mathint ghostPokeRewardsRemaining {
    init_state axiom ghostPokeRewardsRemaining == POKE_REWARDS();
    axiom ghostPokeRewardsRemaining >= 0 && ghostPokeRewardsRemaining <= max_uint256;
}

ghost mathint ghostPokeRewardsRemainingPrev {
    init_state axiom ghostPokeRewardsRemainingPrev == POKE_REWARDS();
    axiom ghostPokeRewardsRemainingPrev >= 0 && ghostPokeRewardsRemainingPrev <= max_uint256;
}

hook Sload uint256 val _RewardManager._pokeRewardsRemaining STORAGE {
    require(require_uint256(ghostPokeRewardsRemaining) == val);
}

hook Sstore _RewardManager._pokeRewardsRemaining uint256 val (uint256 valPrev) STORAGE {
    ghostPokeRewardsRemainingPrev = valPrev;
    ghostPokeRewardsRemaining = val;
}

//
// Ghost copy of `uint256 private _startTimestamp;`
//

ghost mathint ghostStartTimestamp {
    axiom ghostStartTimestamp >= 0 && ghostStartTimestamp <= max_uint40;
}

ghost mathint ghostStartTimestampPrev {
    axiom ghostStartTimestampPrev >= 0 && ghostStartTimestampPrev <= max_uint40;
}

hook Sload uint256 val _RewardManager._startTimestamp STORAGE {
    require(require_uint256(ghostStartTimestamp) == val);
}

hook Sstore _RewardManager._startTimestamp uint256 val (uint256 valPrev) STORAGE {
    ghostStartTimestampPrev = valPrev;
    ghostStartTimestamp = val;
}

//
// Ghost copy of `CurvePoolData[] internal _curvePools;`
//

// length

ghost mathint ghostCurvePoolsLength {
    axiom ghostCurvePoolsLength > 0;
}

hook Sload uint256 val _RewardManager._curvePools.(offset 0) STORAGE {
    require(require_uint256(ghostCurvePoolsLength) == val);
} 

hook Sstore _RewardManager._curvePools.(offset 0) uint256 val STORAGE {
    ghostCurvePoolsLength = val;
}


// address curvePool;

ghost mapping (mathint => address) ghostCurvePoolsCurvePool {
    axiom forall mathint i. ghostCurvePoolsCurvePool[i] != 0;
}

ghost mapping (mathint => address) ghostCurvePoolsCurvePoolPrev {
    axiom forall mathint i. ghostCurvePoolsCurvePoolPrev[i] != 0;
}

hook Sload address val _RewardManager._curvePools[INDEX uint256 i].curvePool STORAGE {
    require(ghostCurvePoolsCurvePool[i] == val);
} 

hook Sstore _RewardManager._curvePools[INDEX uint256 i].curvePool address val (address valPrev) STORAGE {
    ghostCurvePoolsCurvePoolPrev[i] = valPrev;
    ghostCurvePoolsCurvePool[i] = val;
}

// address curveGauge;

ghost mapping (mathint => address) ghostCurvePoolsCurveGauge;
ghost mapping (mathint => address) ghostCurvePoolsCurveGaugePrev;

hook Sload address val _RewardManager._curvePools[INDEX uint256 i].curveGauge STORAGE {
    require(ghostCurvePoolsCurveGauge[i] == val);
} 

hook Sstore _RewardManager._curvePools[INDEX uint256 i].curveGauge address val (address valPrev) STORAGE {
    ghostCurvePoolsCurveGaugePrev[i] = valPrev;
    ghostCurvePoolsCurveGauge[i] = val;
}

// address curveFactory;

ghost mapping (mathint => address) ghostCurvePoolsCurveFactory {
    axiom forall mathint i. ghostCurvePoolsCurveFactory[i] != 0;
}

ghost mapping (mathint => address) ghostCurvePoolsCurveFactoryPrev {
    axiom forall mathint i. ghostCurvePoolsCurveFactoryPrev[i] != 0;
}

hook Sload address val _RewardManager._curvePools[INDEX uint256 i].curveFactory STORAGE {
    require(ghostCurvePoolsCurveFactory[i] == val);
} 

hook Sstore _RewardManager._curvePools[INDEX uint256 i].curveFactory address val (address valPrev) STORAGE {
    ghostCurvePoolsCurveFactoryPrev[i] = valPrev;
    ghostCurvePoolsCurveFactory[i] = val;
}

// uint256 rewardsRemaining;

ghost mapping (mathint => mathint) ghostCurvePoolsRewardsRemaining {
    axiom forall mathint i. ghostCurvePoolsRewardsRemaining[i] >= 0 && ghostCurvePoolsRewardsRemaining[i] <= max_uint256;
}

ghost mapping (mathint => mathint) ghostCurvePoolsRewardsRemainingPrev {
    axiom forall mathint i. ghostCurvePoolsRewardsRemainingPrev[i] >= 0 && ghostCurvePoolsRewardsRemainingPrev[i] <= max_uint256;
}

hook Sload uint256 val _RewardManager._curvePools[INDEX uint256 i].rewardsRemaining STORAGE {
    require(require_uint256(ghostCurvePoolsRewardsRemaining[i]) == val);
} 

hook Sstore _RewardManager._curvePools[INDEX uint256 i].rewardsRemaining uint256 val (uint256 valPrev) STORAGE {
    ghostCurvePoolsRewardsRemainingPrev[i] = valPrev;
    ghostCurvePoolsRewardsRemaining[i] = val;
}

// uint256 maxRewards;

ghost mapping (mathint => mathint) ghostCurvePoolsMaxRewards {
    axiom forall mathint i. ghostCurvePoolsMaxRewards[i] >= 0 && ghostCurvePoolsMaxRewards[i] <= max_uint256;
}

ghost mapping (mathint => mathint) ghostCurvePoolsMaxRewardsPrev {
    axiom forall mathint i. ghostCurvePoolsMaxRewardsPrev[i] >= 0 && ghostCurvePoolsMaxRewardsPrev[i] <= max_uint256;
}

hook Sload uint256 val _RewardManager._curvePools[INDEX uint256 i].maxRewards STORAGE {
    require(require_uint256(ghostCurvePoolsMaxRewards[i]) == val);
} 

hook Sstore _RewardManager._curvePools[INDEX uint256 i].maxRewards uint256 val (uint256 valPrev) STORAGE {
    ghostCurvePoolsMaxRewardsPrev[i] = valPrev;
    ghostCurvePoolsMaxRewards[i] = val;
}

//
// Ghost copy of `uint256 private _poolDeploymentTimestamp;`
//

ghost mathint ghostPoolDeploymentTimestamp {
    axiom ghostPoolDeploymentTimestamp >= 0 && ghostPoolDeploymentTimestamp <= max_uint40;
}

ghost mathint ghostPoolDeploymentTimestampPrev {
    axiom ghostPoolDeploymentTimestampPrev >= 0 && ghostPoolDeploymentTimestampPrev <= max_uint40;
}

hook Sload uint256 val _RewardManager._poolDeploymentTimestamp STORAGE {
    require(require_uint256(ghostPoolDeploymentTimestamp) == val);
}

hook Sstore _RewardManager._poolDeploymentTimestamp uint256 val (uint256 valPrev) STORAGE {
    ghostPoolDeploymentTimestampPrev = valPrev;
    ghostPoolDeploymentTimestamp = val;
}

//
// Ghost copy of `uint256 private _lastSeedTimestamp;`
//

ghost mathint ghostLastSeedTimestamp {
    axiom ghostLastSeedTimestamp >= 0 && ghostLastSeedTimestamp <= max_uint40;
}

ghost mathint ghostLastSeedTimestampPrev {
    axiom ghostLastSeedTimestampPrev >= 0 && ghostLastSeedTimestampPrev <= max_uint40;
}

hook Sload uint256 val _RewardManager._lastSeedTimestamp STORAGE {
    require(require_uint256(ghostLastSeedTimestamp) == val);
}

hook Sstore _RewardManager._lastSeedTimestamp uint256 val (uint256 valPrev) STORAGE {
    ghostLastSeedTimestampPrev = valPrev;
    ghostLastSeedTimestamp = val;
}

///////////////// PROPERTIES //////////////////////

// RW-13 `_lastSeedTimestamp` and `_poolDeploymentTimestamp` are always <= `block.timestamp`
invariant timeStampsSolvency(env eInv) ghostLastSeedTimestamp <= to_mathint(eInv.block.timestamp) &&
    ghostPoolDeploymentTimestamp <= to_mathint(eInv.block.timestamp) {
    preserved with (env eFunc) {
        require(eInv.block.timestamp == eFunc.block.timestamp);
    }
}

// RW-15 `_pokeRewardsRemaining` always less or equal `POKE_REWARDS`
invariant pokeRewardsRemainingLimitationInv() ghostPokeRewardsRemaining <= POKE_REWARDS();

// RW-16 `_startTimestamp` set in constructor once
invariant startTimestampValue(env eInv) ghostStartTimestamp <= to_mathint(eInv.block.timestamp) {
    preserved with (env eFunc) {
        require(eInv.block.timestamp == eFunc.block.timestamp);
    }
}