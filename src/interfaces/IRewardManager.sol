// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IRewardManager {

    /// @notice Invalid caller, must be SUP
    error CallerNotSUP();

    /// @notice Invalid caller, must be stUSD
    error CallerNotStUsd();
    
    /// @notice Contract not initialized
    error NotInitialized();
    
    /**
     * @notice Sets the initial state of the Rewards Manager
     * @dev Only SUP can call this function
     */
    function initialize() external;

    /**
     * @notice Only stUSD can call this function
     * @param rewardReceiver Address of the user which the rewards will be allocated to
     */
    function distributePokeRewards(address rewardReceiver) external;
}