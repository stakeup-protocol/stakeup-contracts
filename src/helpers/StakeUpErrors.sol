// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

library StakeUpErrors {
    // =================== Curve Gauge Distributor ===================
    /// @notice Emitted if the caller tries to seed the gauges to early
    error TooEarlyToSeed();

    /// @notice Emitted if the caller passes an invalid address
    error InvalidAddress();

    /// @notice Emitted if the reward allocation is not met
    error RewardAllocationNotMet();

    /// @notice Emitted if the contract is not initialized
    error NotInitialized();

    /// @notice Emitted if the contract is already initialized
    error ContractInitialized();

    // ========================= Staking ===========================
    /// @dev Error emitted when caller is not the stTBY contract
    error UnauthorizedCaller();

    // @notice Token amount is 0
    error ZeroTokensStaked();

    // @notice User has no current stake
    error UserHasNoStake();

    // @notice User has no rewards to claim
    error NoRewardsToClaim();

    // @notice No Fees were sent to the contract
    error NoFeesToProcess();

    // @notice The address is 0
    error ZeroAddress();

    // ========================= Layer Zero ===========================
    /// @dev Error emitted when the provided address is the zero address
    error InvalidMessageType();

    // @notice If the LZ Compose call fails
    error LZComposeFailed();

    // @notice If the originating OApp of the LZCompose call is invalid
    error InvalidOApp();

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

    // ========================= StTBY Token ===========================

    /// @notice Parameter out of bounds
    error ParameterOutOfBounds();

    /// @notice Insufficient balance
    error InsufficientBalance();

    /// @notice Invalid amount
    error InvalidAmount();

    /// @notice Invalid Redemption of Underlying Tokens
    error InvalidRedemption();

    /// @notice Invalid Underlying Token
    error InvalidUnderlyingToken();

    /// @notice TBY not active
    error TBYNotActive();

    /// @notice WstTBY already initialized
    error AlreadyInitialized();

    /// @notice Zero amount
    error ZeroAmount();
}
