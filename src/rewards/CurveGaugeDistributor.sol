// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;


import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {RewardBase} from "./RewardBase.sol";

import {ICurveGaugeDistributor} from "../interfaces/ICurveGaugeDistributor.sol";
import {ICurvePoolFactory} from "../interfaces/curve/ICurvePoolFactory.sol";
import {ICurvePoolGauge} from "../interfaces//curve/ICurvePoolGauge.sol";
import {IStakeupToken} from "../interfaces/IStakeupToken.sol";

abstract contract CurveGaugeDistributor is ICurveGaugeDistributor, RewardBase {
    using SafeERC20 for IERC20;

    CurvePoolData[] internal _curvePools;
    uint256 private _poolDeploymentTimestamp;
    uint256 private _lastSeedTimestamp;

    // Can only seed during the last 12 hours of the gauge epoch
    uint256 internal constant SEED_INTERVAL = 1 weeks - 12 hours;

    constructor(
        address stUsd,
        address stakeupToken,
        address stakeupStaking,
        CurvePoolData[] memory curvePools
    ) RewardBase(stUsd, stakeupToken, stakeupStaking) {
        _setCurvePools(curvePools);
    }

    /// @inheritdoc ICurveGaugeDistributor
    function seedGauges() external {
        CurvePoolData[] memory curvePools = _curvePools;
        uint256 length = curvePools.length;
        
        uint256 timeElapsed = block.timestamp - _lastSeedTimestamp;
        if (_lastSeedTimestamp != 0 && timeElapsed < SEED_INTERVAL) revert TooEarlyToSeed();

        _lastSeedTimestamp = block.timestamp;

        for (uint256 i=0; i < length; ++i) {
            // Calculate the amount of rewards to mint
            uint256 amount = _calculateDripAmount(
                curvePools[i].maxRewards,
                _poolDeploymentTimestamp,
                curvePools[i].rewardsRemaining,
                true
            );

            if (amount > 0) {
                amount = Math.min(amount, curvePools[i].rewardsRemaining);
                _curvePools[i].rewardsRemaining -= amount;

                // Mint the rewards and deposit tokens into the gauge
                IStakeupToken(_stakeupToken).mintRewards(address(this), amount);
                IERC20(_stakeupToken).safeApprove(curvePools[i].curveGauge, amount);
                ICurvePoolGauge(curvePools[i].curveGauge).deposit_reward_token(_stakeupToken, amount);
                
                emit GaugeSeeded(curvePools[i].curveGauge, amount);
            }
        }
    }
    
    /// @inheritdoc ICurveGaugeDistributor
    function getCurvePoolData() external view override returns (CurvePoolData[] memory) {
        return _curvePools;
    }

    function _setCurvePools(CurvePoolData[] memory curvePools) internal {
        uint256 length = curvePools.length;

        for (uint i = 0; i < length; ++i) {
            if (curvePools[i].curveFactory == address(0)) revert InvalidAddress();
            if (curvePools[i].curvePool == address(0)) revert InvalidAddress();
            
            _curvePools.push(curvePools[i]);
        }
    }

    function _deployCurveGauges() internal returns (uint256) {
        CurvePoolData[] storage curvePools = _curvePools;
        uint256 length = curvePools.length;
        uint256 totalRewards = POOL_REWARDS;

        for (uint256 i = 0; i < length; ++i) {
            // Deploy the Curve guage and register SUP as the reward token
            address gauge = ICurvePoolFactory(curvePools[i].curveFactory).deploy_gauge(curvePools[i].curvePool);
            ICurvePoolGauge(gauge).add_reward(_stakeupToken, address(this));
            curvePools[i].curveGauge = gauge;

            totalRewards -= curvePools[i].maxRewards;

            emit GaugeDeployed(gauge, curvePools[i].curvePool);
        }
        if (totalRewards != 0) revert RewardAllocationNotMet();
        
        _poolDeploymentTimestamp = block.timestamp;

        return totalRewards;
    }
}