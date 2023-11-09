// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {RewardBase} from "./RewardBase.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {CurveGaugeDistributor} from "./CurveGaugeDistributor.sol";

import {IRewardManager} from "../interfaces/IRewardManager.sol";
import {IStakeupToken} from "../interfaces/IStakeupToken.sol";
import {IStakeupStaking} from "../interfaces/IStakeupStaking.sol";

contract RewardManager is IRewardManager, CurveGaugeDistributor {
    uint256 private _pokeRewardsRemaining;
    uint256 private _startTimestamp;

    modifier onlySUP() {
        if (msg.sender != _stakeupToken) revert CallerNotSUP();
        _;
    }

    modifier onlyStUsd() {
        if (msg.sender != _stUsd) revert CallerNotStUsd();
        _;
    }

    modifier initialized() {
        if (_startTimestamp == 0) revert NotInitialized();
        _;
    }

    constructor(
        address stUsd,
        address stakeupToken,
        address stakeupStaking,
        CurvePoolData[] memory curvePools
    ) 
        CurveGaugeDistributor(stUsd, stakeupToken, stakeupStaking, curvePools)
    {
        // solhint-disable-next-line no-empty-blocks
    }

    /// @inheritdoc IRewardManager
    function initialize() external override onlySUP {
        _startTimestamp = block.timestamp;
        _pokeRewardsRemaining = POKE_REWARDS;
        _deployCurveGauges(_curvePools);
    }

    /// @inheritdoc IRewardManager
    function distributePokeRewards(address rewardReceiver) external initialized onlyStUsd {
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
                IStakeupToken(_stakeupToken).mintRewards(_stakeupStaking, amount);
            }
        }
    }

}