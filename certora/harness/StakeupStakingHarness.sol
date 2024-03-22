// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {StakeupStaking} from "../../src/staking/StakeupStaking.sol";

contract StakeupStakingHarness is StakeupStaking { 
    
    constructor(
        address stakeupToken,
        address rewardManager,
        address stTBY
    ) StakeupStaking(stakeupToken, rewardManager, stTBY) { }
}
