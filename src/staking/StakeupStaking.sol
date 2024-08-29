// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {OFTComposeMsgCodec} from "@LayerZero/oft/libs/OFTComposeMsgCodec.sol";
import {IOAppComposer, ILayerZeroComposer} from "@LayerZero/oapp/interfaces/IOAppComposer.sol";

import {StakeUpConstants as Constants} from "../helpers/StakeUpConstants.sol";
import {StakeUpErrors as Errors} from "../helpers/StakeUpErrors.sol";
import {SUPVesting} from "./SUPVesting.sol";

import {IStUsdc} from "../interfaces/IStUsdc.sol";
import {IStakeUpToken} from "../interfaces/IStakeUpToken.sol";
import {IStakeUpStaking} from "../interfaces/IStakeUpStaking.sol";

/**
 * @title StakeUpStaking
 * @notice Allows users to stake their STAKEUP tokens to earn stUsdc rewards.
 *         Tokens can be staked for any amount of time and can be unstaked at any time.
 *         The rewards tracking system is based on the methods similar to those used by
 *         Pendle Finance for rewarding Liquidity Providers.
 * @dev Rewards will be streamed to the staking contract anytime fees are collected and
 *      are immediately claimable by the user. The rewards are denominated in stUsdc shares.
 */
contract StakeUpStaking is IStakeUpStaking, SUPVesting, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using FixedPointMathLib for uint256;

    // =================== Storage ===================

    /// @notice The stUsdc token
    IStUsdc private immutable _stUsdc;

    /// @dev Global reward data
    RewardData private _rewardData;

    /// @notice Total amount of STAKEUP staked
    uint256 private _totalStakeUpStaked;

    /// @notice The last block number when rewards were distributed
    uint256 private _lastRewardBlock;

    /// @dev Mapping of users to their staking data
    mapping(address => StakingData) private _stakingData;

    // =================== Modifiers ===================

    /// @notice Updates the global reward index and available reward balance for StakeUp
    modifier updateIndex() {
        _updateRewardIndex();
        _;
    }

    /// @notice distributes rewards to the users accrued rewards
    modifier distributeRewards() {
        _distributeRewards(msg.sender);
        _;
    }

    /// @notice Only the reward token or the contract itself can call this function
    modifier onlyStUsdc() {
        if (msg.sender != address(_stUsdc)) {
            revert Errors.UnauthorizedCaller();
        }
        _;
    }

    // ================= Constructor =================

    constructor(address stakeupToken, address stUsdc) SUPVesting(stakeupToken) {
        _stUsdc = IStUsdc(stUsdc);
        _lastRewardBlock = block.number;
    }

    // ================== functions ==================

    /// @inheritdoc IStakeUpStaking
    function stake(uint256 stakeupAmount) external override updateIndex distributeRewards {
        _stake(msg.sender, stakeupAmount);
    }

    /// @inheritdoc IStakeUpStaking
    function unstake(uint256 stakeupAmount, bool harvestRewards)
        external
        override
        nonReentrant
        updateIndex
        distributeRewards
    {
        StakingData storage userStakingData = _stakingData[msg.sender];

        if (userStakingData.amountStaked == 0) revert Errors.UserHasNoStake();

        if (stakeupAmount > userStakingData.amountStaked) {
            stakeupAmount = userStakingData.amountStaked;
        }

        if (harvestRewards) {
            uint256 rewardAmount = userStakingData.rewardsAccrued;
            if (rewardAmount > 0) {
                _transferRewards(msg.sender);
            }
        }

        userStakingData.amountStaked -= uint128(stakeupAmount);
        _totalStakeUpStaked -= stakeupAmount;

        IERC20(address(_stakeupToken)).safeTransfer(msg.sender, stakeupAmount);

        emit StakeUpUnstaked(msg.sender, stakeupAmount);
    }

    /// @inheritdoc IStakeUpStaking
    function harvest() public nonReentrant updateIndex {
        uint256 rewardAmount = _distributeRewards(msg.sender);
        if (rewardAmount == 0) revert Errors.NoRewardsToClaim();
        _transferRewards(msg.sender);
        emit RewardsHarvested(msg.sender, rewardAmount);
    }

    /// @inheritdoc IStakeUpStaking
    function processFees() public payable override onlyStUsdc nonReentrant updateIndex {
        // solhint-ignore-previous-line no-empty-blocks
    }

    /// @inheritdoc IStakeUpStaking
    function claimableRewards(address account) external view override returns (uint256) {
        return _stakingData[account].rewardsAccrued
            + _calculateRewardDelta(_stakingData[account], account, _rewardData.index);
    }

    /// @inheritdoc IStakeUpStaking
    function getStakupToken() external view returns (IStakeUpToken) {
        return _stakeupToken;
    }

    /// @inheritdoc IStakeUpStaking
    function getStUsdc() external view returns (IStUsdc) {
        return _stUsdc;
    }

    /// @inheritdoc IStakeUpStaking
    function totalStakeUpStaked() external view returns (uint256) {
        return _totalStakeUpStaked;
    }

    /// @inheritdoc IStakeUpStaking
    function getRewardData() external view returns (RewardData memory) {
        return _rewardData;
    }

    /// @inheritdoc IStakeUpStaking
    function getUserStakingData(address user) external view returns (StakingData memory) {
        return _stakingData[user];
    }

    /// @inheritdoc IStakeUpStaking
    function getLastRewardBlock() external view returns (uint256) {
        return _lastRewardBlock;
    }

    /// @dev Transfers the staked tokens to the staking contract and updates the user's total staked amount
    function _stake(address user, uint256 amount) internal nonReentrant {
        StakingData storage userStakingData = _stakingData[user];

        if (amount == 0) revert Errors.ZeroTokensStaked();

        IERC20(address(_stakeupToken)).safeTransferFrom(msg.sender, address(this), amount);

        userStakingData.amountStaked += uint128(amount);
        _totalStakeUpStaked += amount;

        emit StakeUpStaked(user, amount);
    }

    /**
     * @notice Updates the global reward index and balance for StakeUp
     * @dev This function is called every time a user interacts with the staking contract
     *     to ensure that the reward index is up to date
     * @return The updated global reward index
     */
    function _updateRewardIndex() internal returns (uint256) {
        if (_lastRewardBlock != block.number) {
            _lastRewardBlock = block.number;

            uint256 totalStakeUpLocked = _totalStakeUpStaked + _totalStakeUpVesting;
            RewardData storage rewards = _rewardData;

            uint256 accrued = _stUsdc.sharesOf(address(this)) - rewards.lastShares;

            if (rewards.index == 0) {
                rewards.index = uint128(Constants.INITIAL_REWARD_INDEX);
            }

            if (totalStakeUpLocked != 0) {
                rewards.index += uint128(accrued.divWad(totalStakeUpLocked));
            }

            rewards.lastShares = uint128(rewards.lastShares + accrued);

            return rewards.index;
        } else {
            return _rewardData.index;
        }
    }

    /**
     * @notice Distributes rewards to the user's accrued rewards data
     * @dev This function is called every time a user interacts with the staking contract
     *    to ensure that the user's rewards are up to date. It does not transfer the rewards
     *    to the user, it only updates the user's accrued rewards data.
     * @param user The address of the user to distribute rewards to
     * @return The updated amount of rewards accrued by the user
     */
    function _distributeRewards(address user) internal returns (uint256) {
        if (user == address(0)) revert Errors.ZeroAddress();

        StakingData storage userStakingData = _stakingData[user];

        if (userStakingData.index == 0) {
            userStakingData.index = uint128(Constants.INITIAL_REWARD_INDEX);
        }

        uint256 rewardIndex = _rewardData.index;
        if (rewardIndex == userStakingData.index) return 0;

        uint256 rewardDelta = _calculateRewardDelta(userStakingData, user, rewardIndex);

        userStakingData.index = uint128(rewardIndex);
        userStakingData.rewardsAccrued += uint128(rewardDelta);

        return userStakingData.rewardsAccrued;
    }

    /**
     * @notice Calculates the reward delta for a user
     * @dev The reward delta is the amount of rewards that a user has accrued since the last time
     *      their rewards were updated.
     * @param userData The user's staking data
     * @param user The users address who's reward delta is being calculated
     * @param globalIndex The global reward index the calculation is occurring at
     */
    function _calculateRewardDelta(StakingData memory userData, address user, uint256 globalIndex)
        internal
        view
        returns (uint256)
    {
        uint256 userIndex = userData.index;

        if (userIndex == 0) {
            userIndex = Constants.INITIAL_REWARD_INDEX;
        }

        if (userIndex == globalIndex || globalIndex == 0) {
            return 0;
        }

        uint256 amountStaked = userData.amountStaked + getCurrentBalance(user);
        uint256 delta = globalIndex - userIndex;

        return amountStaked.mulWad(delta);
    }

    /**
     * @notice Transfers the user's accrued rewards to the user
     * @param user The user to transfer rewards to
     */
    function _transferRewards(address user) internal {
        RewardData storage rewards = _rewardData;
        StakingData storage userStakingData = _stakingData[user];

        uint128 rewardsEarned = userStakingData.rewardsAccrued;
        if (rewardsEarned > 0) {
            userStakingData.rewardsAccrued = 0;
            rewards.lastShares -= rewardsEarned;
            _stUsdc.transferShares(user, rewardsEarned);
        }
    }

    /// @inheritdoc SUPVesting
    function _updateRewardState(address account) internal override updateIndex {
        _distributeRewards(account);
    }
}
