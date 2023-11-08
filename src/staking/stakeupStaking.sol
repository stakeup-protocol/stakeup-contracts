// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

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

    // =================== Storage ===================

    // @notice The STAKEUP token
    IStakeupToken public immutable stakeupToken;

    // @notice The SUP vesting contract
    ISUPVesting public immutable supVestingContract;

    // @notice The stUSD token
    IStUSD public immutable stUSD;

    // @dev Mapping of users to their staking data
    mapping(address => StakingData) public stakingData;

    // @dev Data pertaining to the current reward period
    RewardData public rewardData;

    // @notice Total amount of STAKEUP staked
    uint256 public totalStakeUpStaked;

    // @dev Duration of a reward period
    uint256 constant REWARD_DURATION = 1 weeks;

    // =================== Structs ====================
    /**
     * @notice Data structure containing information pertaining to a user's stake
     * @dev All rewards are denominated in stUSD shares due to the token's rebasing nature
     * @param amountStaked The amount of STAKEUP tokens currently staked
     * @param rewardsAccrued The amount of stUSD rewards that have accrued to the stake
     */
    struct StakingData {
        uint128 amountStaked;
        uint128 rewardsPerTokenPaid;
        uint128 rewardsAccrued;
    }

    /**
     * @notice Data structure containing information pertaining to a reward period
     * @dev All rewards are denominated in stUSD shares due to the token's rebasing nature
     * @param periodFinished The end time of the reward period
     * @param lastUpdate The last time the staking rewards were updated
     * @param rewardRate The amount of stUSD rewards per second for the reward period
     * @param rewardPerTokenStaked The amount of stUSD rewards per STAKEUP staked
     * @param availableRewards The amount of stUSD rewards available for the reward period
     * @param pendingRewards The amount of stUSD rewards that have not been claimed
     */
    struct RewardData {
        uint32 periodFinished;
        uint32 lastUpdate;
        uint96 rewardRate;
        uint96 rewardPerTokenStaked;
        uint128 availableRewards;
        uint128 pendingRewards;
    }

    // =================== Events ====================

    /**
     * @notice Emitted when a user's stakes their Stakeup Token
     * @param user Address of the user who has staked their STAKEUP
     * @param amount Amount of STAKEUP staked
     */
    event StakeupStaked(address indexed user, uint256 amount);

    /**
     * @notice Emitted when a user's stakes their Stakeup Token
     * @param user Address of the user who is unstaking their STAKEUP
     * @param amount Amount of STAKEUP unstaked
     */
    event StakeupUnstaked(address indexed user, uint256 amount);

    constructor(
        address _stakeupToken,
        address _supVestingContract,
        address _stUSD
    ) {
        stakeupToken = IStakeupToken(_stakeupToken);
        supVestingContract = ISUPVesting(_supVestingContract);
        stUSD = IStUSD(_stUSD);

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
            StakingData storage userStakingData = stakingData[account];
            RewardData storage rewards = rewardData;

            uint256 newRewardPerTokenStaked = _rewardPerToken();
            rewards.rewardPerTokenStaked = uint96(newRewardPerTokenStaked);
            rewards.lastUpdate = uint32(
                _lastTimeRewardApplicable(rewards.periodFinished)
            );

            if (account != address(0)) {
                userStakingData.rewardsPerTokenPaid = uint128(
                    newRewardPerTokenStaked
                );
                userStakingData.rewardsAccrued = uint128(
                    _rewardsEarned(account)
                );
            }
        }
        _;
    }

    modifier onlyReward() {
        if (msg.sender != address(stUSD)) revert OnlyRewardToken();
        _;
    }

    // ================== functions ==================

    /**
     * @notice Stake Stakeup Token's to earn stUSD rewards
     * @param stakeupAmount Amount of STAKEUP to stake
     */
    function stake(
        uint256 stakeupAmount
    ) external override nonReentrant updateReward(msg.sender) {
        StakingData storage userStakingData = stakingData[msg.sender];

        if (stakeupAmount == 0) revert ZeroTokensStaked();

        userStakingData.amountStaked += uint128(stakeupAmount);
        totalStakeUpStaked += stakeupAmount;

        IERC20(address(stakeupToken)).safeTransferFrom(
            msg.sender,
            address(this),
            stakeupAmount
        );

        emit StakeupStaked(msg.sender, stakeupAmount);
    }

    /**
     * @notice Unstakes the user's STAKEUP and sends it back to them, along with their accumulated stUSD gains
     * @param stakeupAmount Amount of STAKEUP to unstake
     * @param harvestShares Number of stUSD shares to claim
     */
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

    /**
     * @notice Claim all stUSD rewards accrued by the user
     */
    function harvest() external {
        harvest(type(uint256).max);
    }

    /**
     * @notice Claim a specific amount of stUSD rewards
     * @param shares Shares of stUSD to claim
     */
    function harvest(
        uint256 shares
    ) public nonReentrant updateReward(msg.sender) {
        StakingData storage userStakingData = stakingData[msg.sender];

        if (userStakingData.amountStaked == 0) revert UserHasNoStaked();
        if (userStakingData.rewardsAccrued == 0) revert NoRewardsToClaim();

        shares = Math.min(shares, userStakingData.rewardsAccrued);

        _harvest(userStakingData, shares);
    }

    /**
     * @notice Adds stUSD rewards to the next period's reward pool
     * @param shares Amount of shares of stUSD to add to the reward pool
     */
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
            rewards.rewardRate = uint96(
                rewards.availableRewards / REWARD_DURATION
            );
        }

        rewardData.lastUpdate = uint32(block.timestamp);
    }

    /**
     * @notice How much stUSD rewards a user has earned
     * @param account Address of the user to query rewards for
     * @return Amount of stUSD rewards earned
     */
    function claimableRewards(
        address account
    ) external view override returns (uint256) {
        return _rewardsEarned(account);
    }

    function _harvest(
        StakingData storage userStakingData,
        uint256 shares
    ) internal {
        uint256 amount = stUSD.getUsdByShares(shares);
        userStakingData.rewardsAccrued -= uint128(shares);
        IERC20(address(stUSD)).safeTransfer(msg.sender, amount);
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
        uint256 timeElapsed = _lastTimeRewardApplicable(
            rewardData.periodFinished
        ) - rewardData.lastUpdate;

        return
            uint256(rewardData.rewardPerTokenStaked) +
            ((timeElapsed * 1e18) / totalStakupLocked);
    }

    function _rewardsEarned(address account) internal view returns (uint256) {
        StakingData storage userStakingData = stakingData[account];
        uint256 amountEligibleForRewards = uint256(
            userStakingData.amountStaked
        ) + _supLockedInVesting(account);

        return
            (amountEligibleForRewards *
                (_rewardPerToken() -
                    uint256(userStakingData.rewardsPerTokenPaid))) /
            1e18 +
            uint256(userStakingData.rewardsAccrued);
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
