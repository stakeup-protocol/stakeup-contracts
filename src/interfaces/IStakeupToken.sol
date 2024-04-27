// SPDX-License-Identifier: MIT

pragma solidity 0.8.22;

interface IStakeUpToken {
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
     * - stTBY-USDC: (mainnet only)
     * - wstTBY-wstETH: (mainnet only)
     * - wstTBY-chai: (mainnet only)
     * - wstTBY-SUP: (mainnet only)
     * @param allocations The allocations of tokens to mint
     */
    function mintLpSupply(Allocation[] memory allocations) external;

    /**
     * @notice Mints SUP rewards
     * @dev This function is callable by the Reward Manager only
     * @param recipient The address that will receive the tokens
     * @param amount The amount of tokens to mint
     */
    function mintRewards(address recipient, uint256 amount) external;

    /**
     * @notice Airdrops tokens to recipients
     * @param recipients An array of TokenRecipients that will receive tokens
     * @param percentOfTotalSupply The percentage of the total supply that will be minted
     */
    function airdropTokens(
        TokenRecipient[] memory recipients,
        uint256 percentOfTotalSupply
    ) external;

    /**
     * @notice Mints the initial supply of tokens
     * @param allocations An array of token Allocations for the initial supply mint
     * @param initialMintPercentage The percentage of the total supply that will be minted
     */
    function mintInitialSupply(
        Allocation[] memory allocations,
        uint256 initialMintPercentage
    ) external;
}
