// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {IRewardManager} from "src/interfaces/IRewardManager.sol";

contract MockRewardManager is IRewardManager {
    function initialize() external override {}

    function distributePokeRewards(address rewardReceiver) external override {}

    function distributeMintRewards(
        address rewardReceiver,
        uint256 stUSDAmount
    ) external override {}

    function getStUsd() external view override returns (address) {}

    function getStakeupToken() external view override returns (address) {}

    function getStakeupStaking() external view override returns (address) {}
}
