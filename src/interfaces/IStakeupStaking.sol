// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IStakeupStaking {

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
    // --- Events --

    // event stakeupAddressSet(address _stakeupAddress);
    // event stUSDAddressSet(address _stUSDAddress);

    // event StakeChanged(address indexed staker, uint256 newStake);
    // event StakingGainsWithdrawn(address indexed staker, uint256 STUSDGain);
    // event F_STUSDUpdated(uint256 _F_STUSD);
    // event StakerSnapshotsUpdated(address _staker, uint256 _F_STUSD);
    function processFees(uint256 amount) external;

    function stake(uint256 stakeupAmount) external;

    function unstake(uint256 stakeupAmount, uint256 harvestAmount) external;

    function harvest() external;

    function harvest(uint256 amount) external;

    function claimableRewards(address account) external view returns (uint256);

}
