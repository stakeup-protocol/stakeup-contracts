// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {StakeUpConstants as Constants} from "../helpers/StakeUpConstants.sol";
import {StakeUpErrors as Errors} from "../helpers/StakeUpErrors.sol";
import {StakeUpRewardMathLib} from "./lib/StakeUpRewardMathLib.sol";

import {ICurveGaugeDistributor} from "../interfaces/ICurveGaugeDistributor.sol";
import {IChildLiquidityGaugeFactory} from "../interfaces/curve/IChildLiquidityGaugeFactory.sol";
import {ICurvePoolGauge} from "../interfaces//curve/ICurvePoolGauge.sol";
import {IStakeUpToken} from "../interfaces/IStakeUpToken.sol";

contract CurveGaugeDistributor is ICurveGaugeDistributor, ReentrancyGuard, Ownable2Step {
    using SafeERC20 for IERC20;

    /// @notice Curve pool data
    CurvePoolData[] internal _curvePools;

    /// @notice Address of the SUP token
    IStakeUpToken internal _stakeupToken;

    /// @notice Timestamp of the pool deployment
    SeedTimestamp internal _seedTimestamp;

    /// @notice If the contract is initialized
    bool internal _initialized;

    // =================== Modifiers ===================

    modifier initialized() {
        if (!_initialized) revert Errors.NotInitialized();
        _;
    }

    // ================= Constructor =================

    constructor(address owner) Ownable2Step() {
        _initialized = false;
        _transferOwnership(owner);
    }

    // =================== Functions ===================

    function initialize(CurvePoolData[] calldata curvePools, address stakeupToken) external onlyOwner {
        if (stakeupToken == address(0)) revert Errors.InvalidAddress();
        if (_initialized) revert Errors.AlreadyInitialized();

        _stakeupToken = IStakeUpToken(stakeupToken);
        _initialized = true;

        _setCurvePools(curvePools);
        _deployCurveGauges();
    }

    /// @inheritdoc ICurveGaugeDistributor
    function seedGauges() external initialized nonReentrant {
        CurvePoolData[] memory curvePools = _curvePools;
        SeedTimestamp storage timestamps = _seedTimestamp;
        uint256 length = curvePools.length;

        uint256 timeElapsed = block.timestamp - timestamps.lastSeed;
        if (timestamps.lastSeed != 0 && timeElapsed < Constants.SEED_INTERVAL) {
            revert Errors.TooEarlyToSeed();
        }

        for (uint256 i = 0; i < length; ++i) {
            // If this is the first time seeding the gauge, then register SUP as the reward token
            if (timestamps.lastSeed == 0) {
                timestamps.rewardStart = uint128(block.timestamp);
                ICurvePoolGauge(curvePools[i].curveGauge).add_reward(address(_stakeupToken), address(this));
            }
            // Calculate the amount of rewards to mint
            uint256 amount = StakeUpRewardMathLib._calculateDripAmount(
                curvePools[i].maxRewards, timestamps.rewardStart, curvePools[i].rewardsRemaining, true
            );

            if (amount > 0) {
                amount = Math.min(amount, curvePools[i].rewardsRemaining);
                _curvePools[i].rewardsRemaining -= amount;

                // Mint the rewards and deposit tokens into the gauge
                _stakeupToken.mintRewards(address(this), amount);
                IERC20(address(_stakeupToken)).safeApprove(curvePools[i].curveGauge, amount);
                ICurvePoolGauge(curvePools[i].curveGauge).deposit_reward_token(address(_stakeupToken), amount);

                emit GaugeSeeded(curvePools[i].curveGauge, amount);
            }
        }

        timestamps.lastSeed = uint128(block.timestamp);
    }

    /// @inheritdoc ICurveGaugeDistributor
    function curvePoolData() external view override returns (CurvePoolData[] memory) {
        return _curvePools;
    }

    function _deployCurveGauges() internal {
        CurvePoolData[] storage curvePools = _curvePools;
        uint256 length = curvePools.length;
        uint256 totalRewards = Constants.POOL_REWARDS;

        for (uint256 i = 0; i < length; ++i) {
            // Deploy the Curve guage and register SUP as the reward token
            address gauge = IChildLiquidityGaugeFactory(curvePools[i].gaugeFactory).deploy_gauge(curvePools[i].curvePool, bytes32("STAKEUP | Global Savings"));
            curvePools[i].curveGauge = gauge;

            totalRewards -= curvePools[i].maxRewards;

            emit GaugeDeployed(gauge, curvePools[i].curvePool);
        }
        if (totalRewards != 0) revert Errors.RewardAllocationNotMet();
    }

    /**
     * @notice Set the Curve pools to distribute rewards to
     * @param curvePools Array of Curve pool data
     */
    function _setCurvePools(CurvePoolData[] calldata curvePools) internal {
        uint256 length = curvePools.length;

        for (uint256 i = 0; i < length; ++i) {
            if (curvePools[i].gaugeFactory == address(0)) {
                revert Errors.ZeroAddress();
            }

            if (curvePools[i].curvePool == address(0)) {
                revert Errors.ZeroAddress();
            }

            _curvePools.push(curvePools[i]);
        }
    }
}
