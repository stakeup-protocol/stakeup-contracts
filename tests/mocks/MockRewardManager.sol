// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {MockERC20} from "./MockERC20.sol";
import {IRewardManager} from "src/interfaces/IRewardManager.sol";

contract MockRewardManager is IRewardManager {
    address private _stakeupToken;
    address private _stakeupStaking;

    function initialize() external override {}

    function distributePokeRewards(address rewardReceiver) external override {}

    function distributeMintRewards(
        address /*rewardReceiver*/,
        uint256 stUSDAmount
    ) external override {
        MockERC20(_stakeupToken).mint(_stakeupStaking, stUSDAmount);
    }

    function getStUsd() external view override returns (address) {}

    function getStakeupToken() external view override returns (address) {
        return _stakeupToken;
    }

    function getStakeupStaking() external view override returns (address) {
        return _stakeupStaking;
    }

    function setStakeupToken(address stakeupToken) external {
        _stakeupToken = stakeupToken;
    }

    function setStakeupStaking(address stakeupStaking) external {
        _stakeupStaking = stakeupStaking;
    }
}
