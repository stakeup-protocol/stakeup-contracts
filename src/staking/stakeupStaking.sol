// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../interfaces/IStUSD.sol";

contract stakeupStaking {
    /**
     *
     */
    /**
     * Storage *************
     */
    /**
     *
     */

    // @dev Mapping of user to their stakes
    mapping(address => uint256) public stakes;

    // @dev Mapping of F_STUSD, taken at the point at which their latest deposit was made
    mapping(address => Snapshot) public snapshots;

    // @notice Total amount of STAKEUP staked
    uint256 public totalStakeUpStaked;

    // @notice Running sum of STAKEUP fees per-StakeUP-staked
    uint256 public F_STUSD;

    // @notice The total amount of STAKEUP fees accrued
    struct Snapshot {
        uint256 F_STUSD_Snapshot;
    }

    // @notice The stUSD token
    IStUSD public stUSD;

    /**
     *
     */
    /**
     * Functions **********
     */
    /**
     *
     */

    // If caller has a pre-existing stake, send any accumulated stUSD gains to the caller.
    function stake(uint256 _StakeupAmount) external override {
        _requireNonZeroAmount(_StakeupAmount);

        uint256 STUSDGain;
        // Grab any accumulated stUSD gains from the current stake
        if (currentStake != 0) {
            STUSDGain = _getPendingSTUSDGain(msg.sender);
        }

        _updateUserSnapshots(msg.sender);

        uint256 newStake = currentStake.add(_StakeupAmount);

        // Increase user's stake and total STAKEUP staked
        stakes[msg.sender] = newStake;
        totalStakeUpStaked = totalStakeUpStaked.add(_StakeupAmount);
        emit totalStakeUpStakedUpdated(totalStakeUpStaked);

        // Transfer STAKEUP from the caller to this contract
        stakeupToken.sendToStakeupStaking(msg.sender, _StakeupAmount);

        emit StakeChanged(msg.sender, newStake);
        emit StakingGainsWithdrawn(msg.sender, STUSDGain);

        // Send accumulated stUSD gains to the caller
        if (currentStake != 0) {
            stUSD.transfer(msg.sender, STUSDGain);
        }
    }

    // Unstake the STAKEUP and send it back to the caller, along with their accumulated stUSD gains.
    // If requested amount > stake, send their entire stake.
    function unstake(uint256 _StakeupAmount) external override {
        uint256 currentStake = stakes[msg.sender];
        _requireUserHasStake(currentStake);

        // Grab any accumulated stUSD gains from the current stake
        uint256 STUSDGain = _getPendingSTUSDGain(msg.sender);

        _updateUserSnapshots(msg.sender);

        if (_Stakeupamount > 0) {
            uint256 stakeupToWithdraw = Math.min(_StakeupAmount, currentStake);

            uint256 newStake = currentStake.sub(stakeupToWithdraw);

            // Decrease user's stake and total STAKEUP staked
            stakes[msg.sender] = newStake;
            totalStakeUpStaked = totalStakeUpStaked.sub(stakeupToWithdraw);
            emit totalStakeUpStakedUpdated(totalStakeUpStaked);

            // Transfer unstaked STAKEUP to the caller
            stakeupToken.transfer(msg.sender, stakeupToWithdraw);
            emit StakeChanged(msg.sender, newStake);
        }

        emit StakingGainsWithdrawn(msg.sender, STUSDGain);

        // Send accumulated stUSD gains to the caller
        stUSD.transfer(msg.sender, STUSDGain);
    }

    // Pending reward functions
    function getPendingSTUSDGain(address _user) external view override returns (uint256) {
        return _getPendingSTUSDGain(_user);
    }

    function _getPendingSTUSDGain(address _user) internal view returns (uint256) {
        uint256 F_STUSD_Snapshot = snapshots[_user].F_STUSD_Snapshot;
        uint256 STUSDGain = stakes[_user].mul(F_STUSD.sub(F_STUSD_Snapshot)).div(1e18);
        return STUSDGain;
    }

    function _updateUserSnapshots(address _user) internal {
        snapshots[_user].F_STUSD_Snapshot = F_STUSD;
        emit StakerSnapshotsUpdated(_user, F_STUSD);
    }

    function _requireUserHasStake(uint256 currentStake) internal pure {
        if (currentStake == 0) {
            revert("User has no stake");
        }
    }

    function _requireNonZeroAmount(uint256 amount) internal pure {
        if (amount == 0) {
            revert("Amount must be greater than 0");
        }
    }
}
