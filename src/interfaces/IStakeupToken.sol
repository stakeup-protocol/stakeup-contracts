// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IStakeupToken {

    /// @notice Amount being minted is greater than the available tokens
    error ExceedsAvailableTokens();

    /// @notice Amount being minted is greater than the supply cap
    error ExceedsMaxSupply();

    /// @notice Invalid recipient, must be non-zero address
    error InvalidRecipient();

    /// @notice The total number of shares have not been fully allocated
    error SharesNotFullyAllocated();

    /**
     * @dev Allocation is a struct that represents a specific allocation of tokens
     * to a group of recipients. 
     * @dev The percentOfSupply is the percentage of the total supply that this allocation
     * represents.
     * @dev The recipients array is an array of TokenRecipients that will receive tokens
     */
    struct Allocation {
        TokenRecipient[] recipients;
        uint64 percentOfSupply; 
    }

    /**
     * @dev TokenRecipient is a struct that represents a recipient of tokens and the
     * percentage of the total supply that they will receive.
     * @dev The percentOfAllocation is the percentage of the total allocation that this
     * recipient will receive.
     * @dev The recipient is the address that will receive tokens
     */
    struct TokenRecipient {
        address recipient;
        uint64 percentOfAllocation;
    }

    /**
     * @notice Mints and vests tokens for accounts who have provided initial liquidity
     * to one of the supported pools.
     * @dev This function is callable by the owner only
     * @dev The pools eligible for rewards are:
     * - stUSD-USDC: (mainnet only)
     * - wstUSD-wstETH: (mainnet only)
     * - wstUSD-chai: (mainnet only)
     * - wstUSD-SUP: (mainnet only)
     * @param allocations The allocations of tokens to mint
     */
    function mintLpSupply(Allocation[] memory allocations) external;

}

