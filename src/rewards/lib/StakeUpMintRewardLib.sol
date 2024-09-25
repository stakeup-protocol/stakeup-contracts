// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

/**
 * @title StakeUpMintRewardLib
 * @notice Libraries that provides mint reward cutoffs for different chains as well as logic to set the
 *         mint reward allocation for a given stUsdc deployment based on the chain ID.
 * @dev This library contains the mint rewards for chains that support native minting and burning as well as
 *      testnets.
 */
library StakeUpMintRewardLib {
    // =================== Mint Reward Cutoffs ===================

    /// @notice Mint reward cutoff for native minting on Base Mainnet | 5% of total SUP supply
    uint256 private constant MINT_REWARD_CUTOFF_BASE = 50_000_000e18;

    /// @notice Mint reward cutoff for native minting on Base Sepolia Testnet (This is for testing purposes only)
    uint256 private constant MINT_REWARD_CUTOFF_BASE_SEPOLIA = 100_000_000e18;

    /// @notice Mint reward cutoff for local development (This is for testing purposes only)
    uint256 private constant MINT_REWARD_CUTOFF_LOCAL = 200_000_000e18;

    // ======================== Functions ========================

    /// @notice Returns the mint reward allocation for a given stUsdc deployment based on the chain ID
    function _getMintRewardAllocation() internal view returns (uint256) {
        if (block.chainid == 8453) {
            return MINT_REWARD_CUTOFF_BASE;
        }
        if (block.chainid == 84532) {
            return MINT_REWARD_CUTOFF_BASE_SEPOLIA;
        }
        if (block.chainid == 31337) {
            return MINT_REWARD_CUTOFF_LOCAL;
        }
        return 0;
    }
}
