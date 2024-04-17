// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.22;

import {StakeUpRewardMathLib} from "src/rewards/lib/StakeUpRewardMathLib.sol";

// This contract is a wrapper created to isolate the internal function _calculateDripAmount within the RewardBase contract
contract MockDripRewarder {
    function calculateDripAmount(
        uint256 rewardSupply,
        uint256 startTimestamp,
        uint256 rewardsRemaining,
        bool isRewardGauge
    ) external view returns (uint256) {
        return
            StakeUpRewardMathLib._calculateDripAmount(
                rewardSupply,
                startTimestamp,
                rewardsRemaining,
                isRewardGauge
            );
    }
}
