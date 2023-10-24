// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IStakeupStaking {
    // --- Events --

    event stakeupAddressSet(address _stakeupAddress);
    event stUSDAddressSet(address _stUSDAddress);

    event StakeChanged(address indexed staker, uint256 newStake);
    event StakingGainsWithdrawn(address indexed staker, uint256 STUSDGain);
    event F_STUSDUpdated(uint256 _F_STUSD);
    event totalStakeUpStaked(uint256 _totalStakeupStaked);
    event StakerSnapshotsUpdated(address _staker, uint256 _F_STUSD);

    function stake(uint256 _StakeupAmount) external;

    function unstake(uint256 _StakeupAmount) external;

    function increaseF_STUSD(uint256 _STAKEUPFee) external;

    function getPendingSTUSDGain(address _user) external view returns (uint256);
}
