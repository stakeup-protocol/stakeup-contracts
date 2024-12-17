// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStakeUpTokenLite {
    /// @notice Mint tokens from the pool.
    /**
     * @dev Mint tokens from the pool.
     * @dev Only the SUP Token Pool can call this function.
     * @param to The address to mint the tokens to.
     * @param amount The amount of tokens to mint.
     */
    function mintFromPool(address to, uint256 amount) external;

    /**
     * @dev Burn tokens from the pool.
     * @dev Only the SUP Token Pool can call this function.
     * @param amount The amount of tokens to burn.
     */
    function burnFromPool(uint256 amount) external;
}
