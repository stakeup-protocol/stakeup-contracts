// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {IStakeupStaking} from "src/interfaces/IStakeupStaking.sol";
import {IStakeupToken} from "src/interfaces/IStakeupToken.sol";
import {IStTBY} from "src/interfaces/IStTBY.sol";
import {ISUPVesting} from "src/interfaces/ISUPVesting.sol";

contract MockStakeupStaking is IStakeupStaking {
    address private _rewardManager;
    bool private _feeProcessed;

    function processFees() external override {
        _feeProcessed = true;
    }

    function stake(uint256 stakeupAmount) external override {}

    function unstake(
        uint256 stakeupAmount,
        bool harvestRewards
    ) external override {}

    function harvest() external override {}

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

    function getStTBY() external view override returns (IStTBY) {}

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

    // This function is only used for unit testing
    function setFeeProcessed(bool feeProcessed) external {
        _feeProcessed = feeProcessed;
    }

    // This function is only used for unit testing
    function isFeeProcessed() external view returns (bool) {
        return _feeProcessed;
    }

    function getAvailableTokens(
        address account
    ) external view override returns (uint256) {}

    function vestTokens(address account, uint256 amount) external override {}

    function claimAvailableTokens() external override returns (uint256) {}

    function getCurrentBalance(
        address account
    ) external view override returns (uint256) {}

    function getLastRewardBlock() external view override returns (uint256) {}
}