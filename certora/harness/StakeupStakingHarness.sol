// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {StakeUpStaking} from "../../src/staking/StakeUpStaking.sol";

contract StakeUpStakingHarness is StakeUpStaking { 
    
    constructor(
        address stakeupToken,
        address rewardManager,
        address stTBY
    ) StakeUpStaking(stakeupToken, rewardManager, stTBY) { }
}
