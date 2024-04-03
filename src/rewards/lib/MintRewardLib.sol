// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title MintRewardLib
 * @notice Libraries that provides mint reward cutoffs for different chains as well as logic to set the
 *         mint reward allocation for a given stTBY deployment based on the chain ID.
 * @dev This library contains the mint rewards for chains that support native minting and burning as well as
 *      testnets.
 */
library MintRewardLib {
    /// @notice Mint reward cutoff for native minting on Ethereum Mainnet | 2.5% of total SUP supply
    uint256 private constant MINT_REWARD_CUTOFF_MAINNET = 30_000_000e18;

    /// @notice Mint reward cutoff for native minting on Arbitrum | 1.5% of total SUP supply
    uint256 private constant MINT_REWARD_CUTOFF_ARBITRUM = 15_000_000e18;

    /// @notice Mint reward cutoff for native minting on Polygon POS | 0.66% of total SUP supply
    uint256 private constant MINT_REWARD_CUTOFF_POLYGON = 10_000_000e18;

    /// @notice Mint reward cutoff for native minting on Horizen EON | 0.34% of total SUP supply
    uint256 private constant MINT_REWARD_CUTOFF_EON = 5_000_000e18;

    /// @notice Mint reward cutoff for native minting on Sepolia Testnet (This is for testing purposes only)
    uint256 private constant MINT_REWARD_CUTOFF_SEPOLIA = 100_000_000e18;

    /// @notice Mint reward cutoff for native minting on Plume Testnet (This is for testing purposes only)
    uint256 private constant MINT_REWARD_CUTOFF_PLUME_TESTNET = 100_000_000e18;

    /// @notice Mint reward cutoff for native minting on Berachain Testnet (This is for testing purposes only)
    uint256 private constant MINT_REWARD_CUTOFF_BERACHAIN_TESTNET = 100_000_000e18;

    /// @notice Mint reward cutoff for local development (This is for testing purposes only)
    uint256 private constant MINT_REWARD_CUTOFF_LOCAL = 200_000_000e18;

    function _getMintRewardAllocation() internal view returns (uint256) {
        if (block.chainid == 1) {
            return MINT_REWARD_CUTOFF_MAINNET;
        } 
        if (block.chainid == 42161) {
            return MINT_REWARD_CUTOFF_ARBITRUM;
        }
        if (block.chainid == 137) {
            return MINT_REWARD_CUTOFF_POLYGON;
        }
        if (block.chainid == 7332) {
            return MINT_REWARD_CUTOFF_EON;
        }
        if (block.chainid == 11155111) {
            return MINT_REWARD_CUTOFF_SEPOLIA;
        }
        if (block.chainid == 161221135) {
            return MINT_REWARD_CUTOFF_PLUME_TESTNET;
        }
        if (block.chainid == 80085) {
            return MINT_REWARD_CUTOFF_BERACHAIN_TESTNET;
        }
        if (block.chainid == 31337) {
            return MINT_REWARD_CUTOFF_LOCAL;
        }
        
        return 0;
    }
}