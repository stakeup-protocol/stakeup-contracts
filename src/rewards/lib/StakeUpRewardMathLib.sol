// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {StakeUpConstants as Constants} from "../../helpers/StakeUpConstants.sol";

/**
 * @title StakeUpRewardMathLib
 * @notice Libraries that provides mint reward cutoffs for different chains as well as logic to set the
 *         mint reward allocation for a given stUsdc deployment based on the chain ID.
 * @dev This library contains the mint rewards for chains that support native minting and burning as well as
 *      testnets.
 */
library StakeUpRewardMathLib {
    /**
     * @notice Calculates the amount of tokens to drip via a linear halving schedule over 5 years
     * @param rewardSupply The total amount of rewards to be distributed during the 5 year period
     * @param startTimestamp The timestamp when the reward period started
     * @param rewardsRemaining The amount of rewards that have not been distributed
     * @param isRewardGauge True if the reward is for a reward gauge, false otherwise
     */
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
        uint256 year = Math.ceilDiv(timeElapsed, Constants.ONE_YEAR);
        // If the time elapsed is greater than 5 years, then the reward supply
        // is fully unlocked
        if (year > 5) {
            tokensUnlocked = rewardSupply;
        } else {
            // Calculate total tokens unlocked using the formula for the sum of a geometric series
            tokensUnlocked = (rewardSupply * (Constants.FIXED_POINT_ONE - (Constants.FIXED_POINT_ONE / 2 ** year)))
                / Constants.FIXED_POINT_ONE;
        }

        if (year > 1 && timeElapsed % Constants.ONE_YEAR != 0) {
            uint256 previousYear = year - 1;
            previousYearAllocation = (
                rewardSupply * (Constants.FIXED_POINT_ONE - (Constants.FIXED_POINT_ONE / 2 ** previousYear))
            ) / Constants.FIXED_POINT_ONE;

            if (rewardsPaid > 0) {
                uint256 previousYearsRewardsPaid = Math.min(rewardsPaid, previousYearAllocation);
                leftoverRewards = previousYearAllocation - previousYearsRewardsPaid;
                rewardsPaid -= previousYearsRewardsPaid;
            }
        }

        uint256 allocationForYear = tokensUnlocked - previousYearAllocation;
        uint256 timeElapsedInYear =
            timeElapsed % Constants.ONE_YEAR == 0 ? Constants.ONE_YEAR : timeElapsed % Constants.ONE_YEAR;

        return ((timeElapsedInYear * allocationForYear) / Constants.ONE_YEAR) + leftoverRewards - rewardsPaid;
    }
}
