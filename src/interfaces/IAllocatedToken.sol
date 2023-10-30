// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IAllocatedToken {
    /**
     * @dev TokenRecipient is a struct that represents a recipient of tokens and the
     * percentage of the total supply that they will receive.
     */
    struct TokenRecipient {
        address recipient;
        uint64 percentShare;
    }

    /**
     * @dev Allocation is a struct that represents a specific allocation of tokens
     * to a group of recipients.
     */
    struct Allocation {
        Schedule schedule;
        TokenRecipient[] contributorShares;
        uint64 percentShare;
    }

    /**
     * @notice The different minting/vestinng schedules available for the SUP token.
     * @dev standardMint: Tokens are minted and distributed immediately
     * @dev linearVesting: Tokens are minted immediately and distributed linearly over the vesting period
     * Vesting Period Breakdown:
     * - 3 Year Vesting Period
     * - 1 Year Cliff (1/3 of tokens unlocked at the end of the cliff)
     * - 2 Year Vesting Period (1/24 of tokens vested every month)
     * @dev annualHalving: Tokens are minted and distributed on an annual basis for 5 years, with the
     * amount of tokens minted halving every year.
     */
    enum Schedule {
        standardMint,
        linearVesting,
        annualHalving
    }

    /**
     * @notice AllocationType is an enum that represents the different types of allocations
     * that are available for the SUP token.
     * @dev startupContributors: 21% of the total supply, linearVesting
     * @dev investors: 24% of the total supply, linearVesting
     * @dev operators: 9% of the total supply, linearVesting
     */
    enum AllocationType {
        startupContributors,
        investors,
        operators,
        airdrop
    }

    /// @notice Invalid allocation type used
    error InvalidAllocationType();

    /// @notice Invalid recipient, must be non-zero address
    error InvalidRecipient();

    /// @notice Invalid shares, must be non-zero and less than remaining shares
    error InvalidShares();

    /// @notice The total number of shares have not been fully allocated
    error SharesNotFullyAllocated();

}