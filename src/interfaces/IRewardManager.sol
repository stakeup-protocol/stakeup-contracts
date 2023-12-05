// SPDX-License-Identifier: MIT

pragma solidity 0.8.22;

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
     * @notice Distributes rewards to users who execute the poke function
     * @dev Only stUSD can call this function
     * @param rewardReceiver Address of the user which the rewards will be allocated to
     */
    function distributePokeRewards(address rewardReceiver) external;

    /**
     * @notice Distributes rewards to the first users who mint the first 200M stUSD
     * @dev Only stUSD can call this function
     * @param rewardReceiver The address of the user to receive the rewards
     * @param stUSDAmount The amount of stUSD that was minted by the user
     */
    function distributeMintRewards(address rewardReceiver, uint256 stUSDAmount) external;

    /**
     * @notice Returns the address of the stUSD contract
     */
    function getStUsd() external view returns (address);

    /**
     * @notice Returns the address of the SUP contract
     */
    function getStakeupToken() external view returns (address);

    /**
     * @notice Returns the address of the StakeupStaking Protocol
     */
    function getStakeupStaking() external view returns (address);
}