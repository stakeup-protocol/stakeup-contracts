// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

abstract contract RewardBase {
    using FixedPointMathLib for uint256;

    address internal immutable _stTBY;
    address internal immutable _stakeupToken;
    address internal immutable _stakeupStaking;

    uint256 internal constant DECIMAL_SCALING = 1e18;
    uint256 internal constant SUP_MAX_SUPPLY = 1_000_000_000 * DECIMAL_SCALING;
    // Additional reward allocations; Follow a 5-year annual halving schedule
    uint256 internal constant POOL_REWARDS =
        (SUP_MAX_SUPPLY * 2e17) / DECIMAL_SCALING; // 20% of total supply

    uint256 internal constant LAUNCH_MINT_REWARDS =
        (SUP_MAX_SUPPLY * 1e17) / DECIMAL_SCALING; // 10% of total supply

    // Amount of stTBY that is eligible for minting rewards
    uint256 internal constant STTBY_MINT_THREASHOLD = 200_000_000 * DECIMAL_SCALING;
    
    uint256 internal constant POKE_REWARDS =
        (SUP_MAX_SUPPLY * 1e16) / DECIMAL_SCALING; // 1% of total supply
    
    uint256 internal constant ONE_YEAR = 52 weeks;

    constructor(
        address stTBY,
        address stakeupToken,
        address stakeupStaking
    ) {
        _stTBY = stTBY;
        _stakeupToken = stakeupToken;
        _stakeupStaking = stakeupStaking;
    }

    function _calculateDripAmount(
        uint256 rewardSupply,
        uint256 startTimestamp,
        uint256 rewardsRemaining,
        bool isRewardGauge
    ) internal view returns (uint256) {
        uint256 tokensUnlocked;
        uint256 leftoverRewards;
        uint256 previousYearAllocation;

        if (rewardsRemaining == 0) return 0;

        uint256 timeElapsed = block.timestamp - startTimestamp;
        // Reward gauges will be seeded immediately after deployment
        // with 1 weeks worth of rewards
        if (isRewardGauge) {
            timeElapsed += 1 weeks;
        }

        uint256 rewardsPaid = rewardSupply - rewardsRemaining;
        uint256 year = Math.ceilDiv(timeElapsed, ONE_YEAR);
        // If the time elapsed is greater than 5 years, then the reward supply
        // is fully unlocked
        if (year > 5) {
            tokensUnlocked = rewardSupply;
        } else {
            // Calculate total tokens unlocked using the formula for the sum of a geometric series
            tokensUnlocked = rewardSupply * (DECIMAL_SCALING - (DECIMAL_SCALING / 2**year)) / DECIMAL_SCALING;
        }
        
        if (year > 1 && timeElapsed % ONE_YEAR != 0) {
            uint256 previousYear = year - 1;
            previousYearAllocation = rewardSupply * (DECIMAL_SCALING - (DECIMAL_SCALING / 2**previousYear)) / DECIMAL_SCALING;

            if (rewardsPaid > 0) {
                uint256 previousYearsRewardsPaid = Math.min(rewardsPaid, previousYearAllocation);
                leftoverRewards = previousYearAllocation - previousYearsRewardsPaid;
                rewardsPaid -= previousYearsRewardsPaid;
            }
        }

/**************************** Diff Block Start ****************************
diff --git a/src/rewards/RewardBase.sol b/src/rewards/RewardBase.sol
index f5cdf77..02b5b54 100644
--- a/src/rewards/RewardBase.sol
+++ b/src/rewards/RewardBase.sol
@@ -82,6 +82,6 @@ abstract contract RewardBase {
         uint256 allocationForYear = tokensUnlocked - previousYearAllocation;
         uint256 timeElapsedInYear = timeElapsed % ONE_YEAR == 0 ? ONE_YEAR : timeElapsed % ONE_YEAR;
 
-        return (timeElapsedInYear * allocationForYear / ONE_YEAR) + leftoverRewards - rewardsPaid;
+        return (timeElapsedInYear * allocationForYear / ONE_YEAR) + leftoverRewards + rewardsPaid;
     }
 }
 No newline at end of file
**************************** Diff Block End *****************************/


        uint256 allocationForYear = tokensUnlocked - previousYearAllocation;
        uint256 timeElapsedInYear = timeElapsed % ONE_YEAR == 0 ? ONE_YEAR : timeElapsed % ONE_YEAR;

        return (timeElapsedInYear * allocationForYear / ONE_YEAR) + leftoverRewards + rewardsPaid;
    }
}
