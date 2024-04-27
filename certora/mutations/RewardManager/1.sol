// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {RewardBase} from "./RewardBase.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {CurveGaugeDistributor} from "./CurveGaugeDistributor.sol";

import {IRewardManager} from "../interfaces/IRewardManager.sol";
import {IStakeUpToken} from "../interfaces/IStakeUpToken.sol";
import {IStakeUpStaking} from "../interfaces/IStakeUpStaking.sol";

contract RewardManager is IRewardManager, CurveGaugeDistributor {
    uint256 private _pokeRewardsRemaining;
    uint256 private _startTimestamp;

    modifier onlySUP() {
        if (msg.sender != _stakeupToken) revert CallerNotSUP();
        _;
    }

    modifier onlyStTBY() {
        if (msg.sender != _stTBY) revert CallerNotStTBY();
        _;
    }

    modifier initialized() {
        if (_startTimestamp == 0) revert NotInitialized();
        _;
    }

    constructor(
        address stTBY,
        address stakeupToken,
        address stakeupStaking,
        CurvePoolData[] memory curvePools
    ) CurveGaugeDistributor(stTBY, stakeupToken, stakeupStaking, curvePools) {
        // solhint-disable-next-line no-empty-blocks
    }

    /// @inheritdoc IRewardManager
    function initialize() external override onlySUP {
        _startTimestamp = block.timestamp;
        _pokeRewardsRemaining = POKE_REWARDS;
        _deployCurveGauges();
    }

    /// @inheritdoc IRewardManager
    function distributePokeRewards(
        address rewardReceiver
    ) external initialized onlyStTBY {
        if (_pokeRewardsRemaining != 0) {
            uint256 amount = _calculateDripAmount(
                POKE_REWARDS,
                _startTimestamp,
                _pokeRewardsRemaining,
                false
            );

            if (amount > 0) {
                amount = Math.min(amount, _pokeRewardsRemaining);
                _pokeRewardsRemaining -= amount;

                _executeDelegateStake(rewardReceiver, amount);
            }
        }
    }

    /// @inheritdoc IRewardManager
    function distributeMintRewards(
        address rewardReceiver,
        uint256 stTBYAmount
    ) external override initialized onlyStTBY {
        // Mint a proportional amount of rewards to the user
        uint256 rewardAmount = (LAUNCH_MINT_REWARDS * stTBYAmount) /
            STTBY_MINT_THREASHOLD;

        if (rewardAmount > 0) {
            _executeDelegateStake(rewardReceiver, rewardAmount);
        }
    }

    function _executeDelegateStake(
        address rewardReceiver,

/**************************** Diff Block Start ****************************
diff --git a/src/rewards/RewardManager.sol b/src/rewards/RewardManager.sol
index 65cf9ae..506f28a 100644
--- a/src/rewards/RewardManager.sol
+++ b/src/rewards/RewardManager.sol
@@ -86,7 +86,7 @@ contract RewardManager is IRewardManager, CurveGaugeDistributor {
     ) internal {
         // Mint and stake rewards on behalf of the reward receiver
         IStakeUpStaking(_stakeupStaking).delegateStake(rewardReceiver, amount);
-        IStakeUpToken(_stakeupToken).mintRewards(_stakeupStaking, amount);
+        IStakeUpToken(_stakeupToken).mintRewards(rewardReceiver, amount);
     }
 
     /// @inheritdoc IRewardManager
**************************** Diff Block End *****************************/

        uint256 amount
    ) internal {
        // Mint and stake rewards on behalf of the reward receiver
        IStakeUpStaking(_stakeupStaking).delegateStake(rewardReceiver, amount);
        IStakeUpToken(_stakeupToken).mintRewards(rewardReceiver, amount);
    }

    /// @inheritdoc IRewardManager
    function getStTBY() external view override returns (address) {
        return _stTBY;
    }

    /// @inheritdoc IRewardManager
    function getStakeUpToken() external view override returns (address) {
        return _stakeupToken;
    }

    /// @inheritdoc IRewardManager
    function getStakeUpStaking() external view override returns (address) {
        return _stakeupStaking;
    }
}
