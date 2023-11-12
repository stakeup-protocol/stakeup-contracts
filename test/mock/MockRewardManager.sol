// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IRewardManager} from "src/interfaces/IRewardManager.sol";

contract MockRewardManager is IRewardManager {
    function initialize() external override {}

    function distributePokeRewards(address rewardReceiver) external override {}

    function distributeMintRewards(
        address rewardReceiver,
        uint256 stUSDAmount
    ) external override {}
}
