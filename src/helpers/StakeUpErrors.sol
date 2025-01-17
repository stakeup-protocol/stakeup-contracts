// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

library StakeUpErrors {
    // =================== Staking ===================
    /// @notice Emitted if the staking is locked due to a user depositing less than 24 hours ago
    error Locked();

    // ========================= Staking ===========================
    // @notice Token amount is 0
    error ZeroTokensStaked();

    // @notice User has no current stake
    error UserHasNoStake();

    // @notice User has no rewards to claim
    error NoRewardsToClaim();

    // ========================= SUP Token ===========================
    /// @notice Emitted if the contract is not initialized
    error NotInitialized();

    /// @notice Amount being minted is greater than the supply cap
    error ExceedsMaxSupply();

    /// @notice Invalid recipient, must be non-zero address
    error InvalidRecipient();

    // ========================= StUsdc Token ===========================
    /// @notice Error emitted if the asset does not match the BloomPool's asset
    error InvalidAsset();

    /// @notice Insufficient balance
    error InsufficientBalance();

    /// @notice TBY redeemable
    error RedeemableTbyNotAllowed();

    /// @notice Keepers are not allowed for this deployment of stUsdc
    error KeepersNotAllowed();

    /// @notice Rate update too often
    error RateUpdateTooOften();

    /// @notice Invalid start and end for generating consecutive TBY IDs
    error InvalidStartEnd();

    // ========================= General ===========================
    /// @notice Zero amount
    error ZeroAmount();

    // @notice The address is 0
    error ZeroAddress();

    /// @dev Error emitted when caller is not allowed to execute a function
    error UnauthorizedCaller();

    /// @notice Contract has already been initialized
    error AlreadyInitialized();
}
