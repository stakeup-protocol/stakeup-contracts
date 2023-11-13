// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IStakeupStaking} from "src/interfaces/IStakeupStaking.sol";
import {IStakeupToken} from "src/interfaces/IStakeupToken.sol";
import {IStUSD} from "src/interfaces/IStUSD.sol";
import {ISUPVesting} from "src/interfaces/ISUPVesting.sol";

contract MockStakeupStaking is IStakeupStaking {
    address private _rewardManager;

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

    function delegateStake(
        address delegatee,
        uint256 stakeupAmount
    ) external override {}

    function getRewardManager() external view override returns (address) {
        return _rewardManager;
    }

    function setRewardManager(address rewardManager) external {
        _rewardManager = rewardManager;
    }

    function getStakupToken() external view override returns (IStakeupToken) {}

    function getSupVestingContract()
        external
        view
        override
        returns (ISUPVesting)
    {}

    function getStUSD() external view override returns (IStUSD) {}

    function totalStakeUpStaked() external view override returns (uint256) {}

    function getRewardData()
        external
        view
        override
        returns (RewardData memory)
    {}

    function getUserStakingData(
        address user
    ) external view override returns (StakingData memory) {}
}