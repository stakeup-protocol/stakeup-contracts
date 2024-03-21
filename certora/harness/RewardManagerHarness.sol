// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {RewardManager} from "../../src/rewards/RewardManager.sol";

contract RewardManagerHarness is RewardManager { 
    
    constructor(
        address stTBY,
        address stakeupToken,
        address stakeupStaking,
        CurvePoolData[] memory curvePools
    ) RewardManager(stTBY, stakeupToken, stakeupStaking, curvePools) { }

    function calculateDripAmountHarness(uint256 rewardSupply, uint256 startTimestamp, uint256 rewardsRemaining, bool isRewardGauge) external view returns (uint256) {
        return _calculateDripAmount(rewardSupply, startTimestamp, rewardsRemaining, isRewardGauge);
    }

    function deployCurveGaugesHarness() external {
        _deployCurveGauges();
    }

    function DECIMAL_SCALING_HARNESS() external returns (uint256) {
        return DECIMAL_SCALING;
    }

    function SUP_MAX_SUPPLY_HARNESS() external returns (uint256) {
        return SUP_MAX_SUPPLY;
    }

    function POOL_REWARDS_HARNESS() external returns (uint256) {
        return POOL_REWARDS;
    }

    function LAUNCH_MINT_REWARDS_HARNESS() external returns (uint256) {
        return LAUNCH_MINT_REWARDS;
    }

    function STTBY_MINT_THREASHOLD_HARNESS() external returns (uint256) {
        return STTBY_MINT_THREASHOLD;
    }

    function POKE_REWARDS_HARNESS() external returns (uint256) {
        return POKE_REWARDS;
    }

    function ONE_YEAR_HARNESS() external returns (uint256) {
        return ONE_YEAR;
    }

    function SEED_INTERVAL_HARNESS() external returns (uint256) {
        return SEED_INTERVAL;
    }
}
