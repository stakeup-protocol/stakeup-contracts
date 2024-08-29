// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title StakeUpMintRewardLib
 * @notice Libraries that provides mint reward cutoffs for different chains as well as logic to set the
 *         mint reward allocation for a given stTBY deployment based on the chain ID.
 * @dev This library contains the mint rewards for chains that support native minting and burning as well as
 *      testnets.
 */
library StakeUpMintRewardLib {
    // =================== Mint Reward Cutoffs ===================

    /// @notice Mint reward cutoff for native minting on Ethereum Mainnet | 5% of total SUP supply
    uint256 private constant MINT_REWARD_CUTOFF_ARBITRUM = 50_000_000e18;

    /// @notice Mint reward cutoff for native minting on Arbitrum Sepolia Testnet (This is for testing purposes only)
    uint256 private constant MINT_REWARD_CUTOFF_ARB_SEPOLIA = 100_000_000e18;

    /// @notice Mint reward cutoff for local development (This is for testing purposes only)
    uint256 private constant MINT_REWARD_CUTOFF_LOCAL = 200_000_000e18;

    // ======================== Functions ========================

    /// @notice Returns the mint reward allocation for a given stTBY deployment based on the chain ID
    function _getMintRewardAllocation() internal view returns (uint256) {
        if (block.chainid == 42161) {
            return MINT_REWARD_CUTOFF_ARBITRUM;
        }
        if (block.chainid == 421614) {
            return MINT_REWARD_CUTOFF_ARB_SEPOLIA;
        }
        if (block.chainid == 31337) {
            return MINT_REWARD_CUTOFF_LOCAL;
        }
        return 0;
    }
}
