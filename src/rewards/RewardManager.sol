// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {RewardBase} from "./RewardBase.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IRewardManager} from "../interfaces/IRewardManager.sol";
import {IStakeupToken} from "../interfaces/IStakeupToken.sol";
import {IStakeupStaking} from "../interfaces/IStakeupStaking.sol";

contract RewardManager is IRewardManager, RewardBase {
    address private _token;
    address private _stakeupStaking;

    uint256 private _pokeRewardsRemaining;
    uint256 private _startTimestamp;

    modifier onlySUP() {
        if (msg.sender != _token) revert CallerNotSUP();
        _;
    }

    modifier onlyStUsd() {
        if (msg.sender != _token) revert CallerNotStUsd();
        _;
    }

    constructor(address token, address stakeupStaking) {
        _token = token;
        _stakeupStaking = stakeupStaking;
    }

    function initialize() external override onlySUP {
        _startTimestamp = block.timestamp;
        _pokeRewardsRemaining = POKE_REWARDS;
    }

    function distributePokeRewards(address rewardReceiver) external onlyStUsd {
        if (_pokeRewardsRemaining != 0) {

            uint256 amount = _calculateDripAmount(
                POKE_REWARDS,
                _startTimestamp,
                _pokeRewardsRemaining
            );
            
            if (amount > 0) {
                amount = Math.min(amount, _pokeRewardsRemaining);

                _pokeRewardsRemaining -= amount;
                
                // Mint and stake rewards on behalf of the reward receiver
                IStakeupStaking(_stakeupStaking).delegateStake(rewardReceiver, amount);
                IStakeupToken(_token).mintRewards(_stakeupStaking, amount);
            }
        }
    }

}