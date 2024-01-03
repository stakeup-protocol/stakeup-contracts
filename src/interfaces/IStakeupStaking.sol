// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IStakeupToken} from "./IStakeupToken.sol";
import {IStUSD} from "./IStUSD.sol";
import {ISUPVesting} from "./ISUPVesting.sol";

interface IStakeupStaking is ISUPVesting {

    // @notice Token amount is 0
    error ZeroTokensStaked();

    // @notice User has no current stake
    error UserHasNoStaked();

    // @notice User has no rewards to claim
    error NoRewardsToClaim();

    // @notice Only the reward token can call this function
    error OnlyRewardToken();

    // @notice No Fees were sent to the contract
    error NoFeesToProcess();

    // =================== Structs ====================
    /**
     * @notice Data structure containing information pertaining to a user's stake
     * @dev All rewards are denominated in stUSD shares due to the token's rebasing nature
     * @param amountStaked The amount of STAKEUP tokens currently staked
     * @param rewardsAccrued The amount of stUSD rewards that have accrued to the stake
     */
    struct StakingData {
        uint256 amountStaked;
        uint256 rewardsPerTokenPaid;
        uint256 rewardsAccrued;
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
        uint256 rewardRate;
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

    /**
     * @notice Emitted when a user claims their stUSD rewards
     * @param user Address of the user who is claiming their rewards
     * @param shares Shares of stUSD claimed
     */
    event RewardsHarvested(address indexed user, uint256 shares);


    function processFees(uint256 amount) external;

    /**
     * @notice Stake Stakeup Token's to earn stUSD rewards
     * @param stakeupAmount Amount of STAKEUP to stake
     */
    function stake(uint256 stakeupAmount) external;

    /**
     * @notice Stake Stakeup Token's to earn stUSD rewards on behalf of another user
     * @param receiver The address of the user who will receive the staked STAKEUP
     * @param stakeupAmount Amount of STAKEUP to stake
     */
    function delegateStake(address receiver, uint256 stakeupAmount) external;

    /**
     * @notice Unstakes the user's STAKEUP and sends it back to them, along with their accumulated stUSD gains
     * @param stakeupAmount Amount of STAKEUP to unstake
     * @param harvestShares Number of stUSD shares to claim
     */
    function unstake(uint256 stakeupAmount, uint256 harvestShares) external;

    /**
     * @notice Claim all stUSD rewards accrued by the user
     */
    function harvest() external;

    /**
     * @notice Claim a specific amount of stUSD rewards
     * @param shares Shares of stUSD to claim
     */
    function harvest(uint256 shares) external;

    /**
     * @notice Adds stUSD rewards to the next period's reward pool
     * @param shares Amount of shares of stUSD to add to the reward pool
     */
    function claimableRewards(address shares) external view returns (uint256);
    
    /// @notice Returns the Stakeup Token
    function getStakupToken() external view returns (IStakeupToken);
    
    /// @notice Returns the stUSD token
    function getStUSD() external view returns (IStUSD);

    /// @notice Returns the address of the Reward Manager
    function getRewardManager() external view returns (address);
    
    /// @notice Returns the total amount of STAKEUP staked within the contract
    function totalStakeUpStaked() external view returns (uint256);

    /// @notice Gets the information for the current rewards period
    function getRewardData() external view returns (RewardData memory);

    /**
     * @notice Gets the staking data for a user
     * @param user Address of the user to get the staking data for
     */
    function getUserStakingData(address user) external view returns (StakingData memory);
}
