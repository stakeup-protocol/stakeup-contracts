// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {StakeupToken} from "../../src/token/StakeupToken.sol";

contract StakeupTokenHarness is StakeupToken { 
    
    constructor(
        address layerZeroEndpoint,
        address stakeupStaking,
        address rewardManager,
        address owner
    ) StakeupToken(layerZeroEndpoint, stakeupStaking, rewardManager, owner) { }

    function DECIMAL_SCALING_HARNESS() external returns (uint256) {
        return DECIMAL_SCALING;
    }

    function MAX_SUPPLY_HARNESS() external returns (uint256) {
        return MAX_SUPPLY;
    }
}
