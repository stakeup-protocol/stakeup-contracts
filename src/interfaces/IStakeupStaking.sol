// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IStakeupStaking {

    // @notice Token amount is 0
    error ZeroTokensStaked();

    // @notice User has no current stake
    error UserHasNoStaked();

    // @notice User has no rewards to claim
    error NoRewardsToClaim();

    // --- Events --

    // event stakeupAddressSet(address _stakeupAddress);
    // event stUSDAddressSet(address _stUSDAddress);

    // event StakeChanged(address indexed staker, uint256 newStake);
    // event StakingGainsWithdrawn(address indexed staker, uint256 STUSDGain);
    // event F_STUSDUpdated(uint256 _F_STUSD);
    // event StakerSnapshotsUpdated(address _staker, uint256 _F_STUSD);

    function stake(uint256 stakeupAmount) external;

    function unstake(uint256 stakeupAmount, uint256 harvestAmount) external;

    function harvest() external;

    function harvest(uint256 amount) external;
}
