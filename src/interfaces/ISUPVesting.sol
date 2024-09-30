// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

interface ISUPVesting {
    /// @dev The max supply of SUP tokens is 1 billion so we can use uint32 for balances
    struct VestedAllocation {
        uint256 startingBalance;
        uint256 currentBalance;
        uint256 vestingStartTime;
    }

    /**
     * @notice Set the accounting variables to track vested tokens for an account
     * @dev This function is callable by the StakeUp token only
     * @param account The account to track vested tokens for
     * @param amount The amount of tokens to track
     */
    function vestTokens(address account, uint256 amount) external;

    /**
     * @notice Claim available vested tokens for an account
     * @return The amount of tokens claimed
     */
    function claimAvailableTokens() external returns (uint256);

    /**
     * @notice Get the amount of tokens available to be claimed by an account
     * @param account The account to check
     * @return The amount of tokens available to be claimed
     */
    function availableTokens(address account) external view returns (uint256);

    /**
     * @notice Get the amount of tokens that are currently locked in the vesting contract
     * for an account
     * @param account The account to check
     * @return The amount of tokens locked in the vesting contract
     */
    function currentBalance(address account) external view returns (uint256);
}
