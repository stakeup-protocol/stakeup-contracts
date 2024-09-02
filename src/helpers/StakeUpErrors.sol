// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

library StakeUpErrors {
    // =================== Curve Gauge Distributor ===================
    /// @notice Emitted if the caller tries to seed the gauges to early
    error TooEarlyToSeed();

    /// @notice Emitted if the reward allocation is not met
    error RewardAllocationNotMet();

    /// @notice Emitted if the contract is not initialized
    error NotInitialized();

    // ========================= Staking ===========================
    // @notice Token amount is 0
    error ZeroTokensStaked();

    // @notice User has no current stake
    error UserHasNoStake();

    // @notice User has no rewards to claim
    error NoRewardsToClaim();

    // ========================= Layer Zero ===========================
    /// @dev Error emitted when the provided address is the zero address
    error InvalidMessageType();

    // @notice If the LZ Compose call fails
    error LZComposeFailed();

    // @notice If the originating OApp of the LZCompose call is invalid
    error InvalidOApp();

    // @notice Invalid Peer ID
    error InvalidPeerID();

    // ========================= SUP Token ===========================
    /// @notice Amount being minted is greater than the available tokens
    error ExceedsAvailableTokens();

    ///@notice Amount being minted is greater than the allocation limit
    error ExceedsMaxAllocationLimit();

    /// @notice Amount being minted is greater than the supply cap
    error ExceedsMaxSupply();

    /// @notice Invalid recipient, must be non-zero address
    error InvalidRecipient();

    /// @notice Invalid caller, must be StakeUpStaking or the CurveGaugeDistributor
    error CallerAuthorizedMinter();

    /// @notice The total number of shares have not been fully allocated
    error SharesNotFullyAllocated();

    // ========================= StUsdc Token ===========================
    /// @notice Parameter out of bounds
    error ParameterOutOfBounds();

    /// @notice Insufficient balance
    error InsufficientBalance();

    /// @notice Invalid Redemption of Underlying Tokens
    error InvalidRedemption();

    /// @notice Invalid Underlying Token
    error InvalidUnderlyingToken();

    /// @notice TBY not active
    error TBYNotActive();

    /// @notice Too long between rate updates
    error RateUpdateNeeded();

    /// @notice Redemptions are not allowed, while mint rewards are still available
    error RedemptionsNotAllowed();

    // ========================= General ===========================
    /// @notice Zero amount
    error ZeroAmount();

    // @notice The address is 0
    error ZeroAddress();

    /// @dev Error emitted when caller is not allowed to execute a function
    error UnauthorizedCaller();

    /// @notice WstUsdc already initialized
    error AlreadyInitialized();

    /// @notice Emitted if the caller passes an invalid address
    error InvalidAddress();
}
