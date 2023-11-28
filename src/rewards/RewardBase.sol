// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

abstract contract RewardBase {
    address internal immutable _stUsd;
    address internal immutable _stakeupToken;
    address internal immutable _stakeupStaking;

    uint256 internal constant DECIMAL_SCALING = 1e18;
    uint256 internal constant SUP_MAX_SUPPLY = 1_000_000_000 * DECIMAL_SCALING;
    uint256 internal constant FIVE_YEARS = 5 * 365 days;

    // Additional reward allocations; Follow a 5-year annual halving schedule
    uint256 internal constant POOL_REWARDS =
        (SUP_MAX_SUPPLY * 2e17) / DECIMAL_SCALING; // 20% of total supply
    
    uint256 internal constant LAUNCH_MINT_REWARDS =
        (SUP_MAX_SUPPLY * 1e17) / DECIMAL_SCALING; // 10% of total supply

    // Amount of stUSD that is eligible for minting rewards
    uint256 internal constant STUSD_MINT_THREASHOLD = 200_000_000 * DECIMAL_SCALING;
    
    uint256 internal constant POKE_REWARDS =
        (SUP_MAX_SUPPLY * 1e16) / DECIMAL_SCALING; // 1% of total supply

    constructor(
        address stUsd,
        address stakeupToken,
        address stakeupStaking
    ) {
        _stUsd = stUsd;
        _stakeupToken = stakeupToken;
        _stakeupStaking = stakeupStaking;
    }

    function _calculateDripAmount(
        uint256 rewardSupply,
        uint256 startTimestamp,
        uint256 rewardsRemaining,
        bool isRewardGauge
    ) internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp - startTimestamp;
        // Reward gauges will be seeded immediately after deployment
        // with 1 weeks worth of rewards
        if (isRewardGauge) {
            timeElapsed += 1 weeks;
        }

        uint256 rewardsPaid = rewardSupply - rewardsRemaining;
        uint256 year = Math.max(1, Math.ceilDiv(timeElapsed, 365 days));
        // If the time elapsed is greater than 5 years, then the reward supply
        // is fully unlocked
        if (year > 5) {
            return rewardSupply - rewardsPaid;
        }

        // Calculate total tokens unlocked using the formula for the sum of a geometric series
        uint256 tokensUnlocked = rewardSupply * (1 - (1 / 2**year));
        uint256 yearlyAllocation = tokensUnlocked - rewardsPaid;

        return timeElapsed * yearlyAllocation / 365 days;
    }
}