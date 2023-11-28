// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

interface ISUPVesting {
    
    /// @dev The max supply of SUP tokens is 1 billion so we can use uint32 for balances
    struct VestedAllocation {
        uint256 startingBalance;
        uint256 currentBalance;
        uint256 vestingStartTime;
    }

    /// @notice Caller not the StakeUp token
    error CallerNotSUP();

    /**
     * @notice Get the amount of tokens available to be claimed by an account
     * @param account The account to check
     */
    function getAvailableTokens(address account) external view returns (uint256);

    /**
     * @notice Set the accounting variables to track vested tokens for an account
     * @dev This function is callable by the StakeUp token only
     * @param account The account to track vested tokens for
     * @param amount The amount of tokens to track
     */
    function vestTokens(address account, uint256 amount) external;

    /**
     * @notice Claim available vested tokens for an account
     */
    function claimAvailableTokens() external returns (uint256);

    /**
     * @notice Get the amount of tokens that are currently locked in the vesting contract
     * for an account
     * @param account The account to check
     */
    function getCurrentBalance(address account) external view returns (uint256);

    /**
     * @notice Get address of the SUP token
     */
    function getSUPToken() external view returns (address);

}