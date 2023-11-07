// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IStakeupStaking} from "src/interfaces/IStakeupStaking.sol";

contract MockStakeupStaking is IStakeupStaking {
    function processFees(uint256 amount) external override {}

    function stake(uint256 stakeupAmount) external override {}

    function unstake(
        uint256 stakeupAmount,
        uint256 harvestAmount
    ) external override {}

    function harvest() external override {}

    function harvest(uint256 amount) external override {}

    function claimableRewards(
        address account
    ) external view override returns (uint256) {}
}