// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

import {IRewardManager} from "../interfaces/IRewardManager.sol";
import {IStUSD} from "../interfaces/IStUSD.sol";
import {IStakeupToken} from "../interfaces/IStakeupToken.sol";
import {IStakeupStaking} from "../interfaces/IStakeupStaking.sol";
import {ISUPVesting} from "../interfaces/ISUPVesting.sol";

/**
 * @title StakeupStaking
 * @notice Allows users to stake their STAKEUP tokens to earn stUSD rewards.
 *         Tokens can be staked for any amount of time and can be unstaked at any time.
 *         The rewards tracking system is based on the methods used by Convex Finance & 
 *         Aura Finance but have been modified to fit the needs of the StakeUp Protocol.
 * @dev There will be one week reward periods. This is to ensure that the reward rate
 *      is updated frequently enough to keep up with the changing amount of STAKEUP staked.
 */
contract StakeupStaking is IStakeupStaking, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using FixedPointMathLib for uint256;

    // =================== Storage ===================

    // @notice The STAKEUP token
    IStakeupToken public immutable stakeupToken;

    // @notice The SUP vesting contract
    ISUPVesting public immutable supVestingContract;

    // @notice The stUSD token
    IStUSD public immutable stUSD;

    // @notice Address of the reward manager
    IRewardManager public immutable rewardManager;

    // @dev Mapping of users to their staking data
    mapping(address => StakingData) public stakingData;

    // @dev Data pertaining to the current reward period
    RewardData public rewardData;

    // @notice Total amount of STAKEUP staked
    uint256 public totalStakeUpStaked;

    // @dev Duration of a reward period
    uint256 constant REWARD_DURATION = 1 weeks;

    constructor(
        address _stakeupToken,
        address _supVestingContract,
        address _rewardManager,
        address _stUSD
    ) {
        stakeupToken = IStakeupToken(_stakeupToken);
        supVestingContract = ISUPVesting(_supVestingContract);
        stUSD = IStUSD(_stUSD);
        rewardManager = IRewardManager(_rewardManager);

        rewardData = RewardData({
            periodFinished: uint32(block.timestamp + REWARD_DURATION),
            lastUpdate: uint32(block.timestamp),
            rewardRate: 0,
            rewardPerTokenStaked: 0,
            availableRewards: 0,
            pendingRewards: 0
        });
    }

    /**
     * @notice Updates the rewards accrued for a user and global reward state
     * @param account Address of the user who is getting their rewards updated
     */
    modifier updateReward(address account) {
        {
            RewardData storage rewards = rewardData;

            uint256 newRewardPerTokenStaked = _rewardPerToken();
            rewards.rewardPerTokenStaked = uint96(newRewardPerTokenStaked);
            rewards.lastUpdate = uint32(
                _lastTimeRewardApplicable(rewards.periodFinished)
            );

            if (account != address(0)) {
                stakingData[account].rewardsAccrued = _rewardsEarned(account);
                stakingData[account]
                    .rewardsPerTokenPaid = newRewardPerTokenStaked;
            }
        }
        _;
    }

    /**
     *
     * @notice Only the reward token can call this function
     */
    modifier onlyReward() {
        if (msg.sender != address(stUSD)) revert OnlyRewardToken();
        _;
    }

    // ================== functions ==================

    /// @inheritdoc IStakeupStaking
    function stake(uint256 stakeupAmount) external override {
        _stake(msg.sender, stakeupAmount);
    }

    /// @inheritdoc IStakeupStaking
    function delegateStake(address receiver, uint256 stakeupAmount) external override {
        _stake(receiver, stakeupAmount);
    }

    /// @inheritdoc IStakeupStaking
    function unstake(
        uint256 stakeupAmount,
        uint256 harvestShares
    ) external override nonReentrant updateReward(msg.sender) {
        StakingData storage userStakingData = stakingData[msg.sender];

        if (userStakingData.amountStaked == 0) revert UserHasNoStaked();

        stakeupAmount = Math.min(stakeupAmount, userStakingData.amountStaked);
        harvestShares = Math.min(harvestShares, userStakingData.rewardsAccrued);

        userStakingData.amountStaked -= uint128(stakeupAmount);
        totalStakeUpStaked -= stakeupAmount;

        if (harvestShares > 0) {
            _harvest(userStakingData, harvestShares);
        }

        IERC20(address(stakeupToken)).safeTransfer(msg.sender, stakeupAmount);

        emit StakeupUnstaked(msg.sender, stakeupAmount);
    }

    /// @inheritdoc IStakeupStaking
    function harvest() external {
        harvest(type(uint256).max);
    }

    /// @inheritdoc IStakeupStaking
    function harvest(
        uint256 shares
    ) public nonReentrant updateReward(msg.sender) {
        StakingData storage userStakingData = stakingData[msg.sender];

        if (userStakingData.amountStaked == 0) revert UserHasNoStaked();
        if (userStakingData.rewardsAccrued == 0) revert NoRewardsToClaim();

        shares = Math.min(shares, userStakingData.rewardsAccrued);

        _harvest(userStakingData, shares);
    }

    /// @inheritdoc IStakeupStaking
    function processFees(
        uint256 shares
    ) external nonReentrant onlyReward updateReward(address(0)) {
        if (shares == 0) revert NoFeesToProcess();

        RewardData storage rewards = rewardData;

        rewards.pendingRewards += uint128(shares);

        // If the current reward period has ended, update the reward rate
        // and add the leftover rewards to the next period's reward pool
        if (block.timestamp >= rewards.periodFinished) {
            rewards.availableRewards += rewards.pendingRewards;
            rewards.pendingRewards = 0;
            rewards.periodFinished = uint32(block.timestamp + REWARD_DURATION);
            rewards.rewardRate = uint256(rewards.availableRewards).divWad(
                REWARD_DURATION
            );
        }

        rewardData.lastUpdate = uint32(block.timestamp);
    }

    /// @inheritdoc IStakeupStaking
    function claimableRewards(
        address account
    ) external view override returns (uint256) {
        return _rewardsEarned(account);
    }

    function getRewardManager() external view override returns (address) {
        return address(rewardManager);
    }

    function _stake(address user, uint256 amount) internal nonReentrant updateReward(user) {
        StakingData storage userStakingData = stakingData[user];

        if (amount == 0) revert ZeroTokensStaked();

        userStakingData.amountStaked += uint128(amount);
        totalStakeUpStaked += amount;

        // If the reward manager is the sender, then there is no need to transfer tokens
        // as the tokens will be minted directly to the staking contract
        if (msg.sender != address(rewardManager)) {
            IERC20(address(stakeupToken)).safeTransferFrom(
                msg.sender,
                address(this),
                amount
            );
        }

        emit StakeupStaked(user, amount);
    }

    function _harvest(
        StakingData storage userStakingData,
        uint256 shares
    ) internal {
        uint256 amount = stUSD.getUsdByShares(shares);
        userStakingData.rewardsAccrued -= uint128(shares);
        IERC20(address(stUSD)).safeTransfer(msg.sender, amount);
        emit RewardsHarvested(msg.sender, shares);
    }

    function _lastTimeRewardApplicable(
        uint32 periodFinished
    ) internal view returns (uint32) {
        return uint32(Math.min(block.timestamp, periodFinished));
    }

    function _rewardPerToken() internal view returns (uint256) {
        uint256 totalStakupLocked = totalStakeUpStaked +
            _totalSupLockedInVesting();

        if (totalStakupLocked == 0) {
            return rewardData.rewardPerTokenStaked;
        }
        uint256 timeElapsed = uint256(
            _lastTimeRewardApplicable(rewardData.periodFinished)
        ) - rewardData.lastUpdate;

        return
            uint256(rewardData.rewardPerTokenStaked) +
            timeElapsed.mulWad(rewardData.rewardRate).divWad(totalStakupLocked);
    }

    /**
     * @dev There will be some dust left over due to precision loss within the
     *     FixedPointMathLib library. This dust will be added to the next reward period
     */
    function _rewardsEarned(address account) internal view returns (uint256) {
        StakingData storage userStakingData = stakingData[account];
        uint256 amountEligibleForRewards = uint256(
            userStakingData.amountStaked
        );

        return
            amountEligibleForRewards
                .mulWad(
                    _rewardPerToken() -
                        uint256(userStakingData.rewardsPerTokenPaid)
                )
                .divWad(1e18) + uint256(userStakingData.rewardsAccrued);
    }

    function _supLockedInVesting(
        address account
    ) internal view returns (uint256) {
        return supVestingContract.getCurrentBalance(account);
    }

    function _totalSupLockedInVesting() internal view returns (uint256) {
        return
            IERC20(address(stakeupToken)).balanceOf(
                address(supVestingContract)
            );
    }
}