// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IStakeUpToken} from "./IStakeUpToken.sol";
import {IStTBY} from "./IStTBY.sol";
import {ISUPVesting} from "./ISUPVesting.sol";

interface IStakeUpStaking is ISUPVesting {
    // =================== Structs ====================
    /**
     * @notice Data structure containing information pertaining to a user's stake
     * @dev All rewards are denominated in stTBY shares due to the token's rebasing nature
     * @param amountStaked The amount of STAKEUP tokens currently staked
     * @param index The last index that the users rewards were updated
     * @param rewardsAccrued The amount of stTBY rewards that have accrued to the stake
     */
    struct StakingData {
        uint256 amountStaked;
        uint128 index;
        uint128 rewardsAccrued;
    }

    /**
     * @notice Data structure containing information pertaining to a reward period
     * @dev All rewards are denominated in stTBY shares due to the token's rebasing nature
     * @param index The last index that the rewards were updated
     * @param lastBalance The last balance of rewards available in the contract
     */
    struct RewardData {
        uint128 index;
        uint128 lastBalance;
    }

    // =================== Events ====================

    /**
     * @notice Emitted when a user's stakes their StakeUp Token
     * @param user Address of the user who has staked their STAKEUP
     * @param amount Amount of STAKEUP staked
     */
    event StakeUpStaked(address indexed user, uint256 amount);

    /**
     * @notice Emitted when a user's stakes their StakeUp Token
     * @param user Address of the user who is unstaking their STAKEUP
     * @param amount Amount of STAKEUP unstaked
     */
    event StakeUpUnstaked(address indexed user, uint256 amount);

    /**
     * @notice Emitted when a user claims their stTBY rewards
     * @param user Address of the user who is claiming their rewards
     * @param shares Shares of stTBY claimed
     */
    event RewardsHarvested(address indexed user, uint256 shares);

    // =================== Functions ====================

    /**
     * @notice Stake StakeUp Token's to earn stTBY rewards
     * @param stakeupAmount Amount of STAKEUP to stake
     */
    function stake(uint256 stakeupAmount) external;

    /**
     * @notice Unstakes the user's STAKEUP and sends it back to them, along with their accumulated stTBY gains
     * @param stakeupAmount Amount of STAKEUP to unstake
     * @param harvestRewards True if the user wants to claim their stTBY rewards
     */
    function unstake(uint256 stakeupAmount, bool harvestRewards) external;

    /**
     * @notice Claim all stTBY rewards accrued by the user
     */
    function harvest() external;

    /// @notice Processes stTBY fees and sends them to StakeUp Staking
    function processFees() external payable;

    /// @notice Returns the StakeUp Token
    function getStakupToken() external view returns (IStakeUpToken);

    /// @notice Returns the stTBY token
    function getStTBY() external view returns (IStTBY);

    /**
     * @notice Adds stTBY rewards to the next period's reward pool
     * @param shares Amount of shares of stTBY to add to the reward pool
     */
    function claimableRewards(address shares) external view returns (uint256);

    /// @notice Returns the total amount of STAKEUP staked within the contract
    function totalStakeUpStaked() external view returns (uint256);

    /// @notice Gets the information for the current rewards period
    function getRewardData() external view returns (RewardData memory);

    /**
     * @notice Gets the staking data for a user
     * @param user Address of the user to get the staking data for
     */
    function getUserStakingData(
        address user
    ) external view returns (StakingData memory);

    /// @notice Returns the last block that global reward data was updated
    function getLastRewardBlock() external view returns (uint256);
}
