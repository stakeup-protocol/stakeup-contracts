// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IStUSD} from "./IStUSD.sol";

interface IWstUSD {
    // =================== Errors ===================

    /// @notice Zero amount
    error ZeroAmount();

    /**
     * @notice Exchanges stUSD to wstUSD
     * @dev Requirements:
     *  - `_stUSDAmount` must be non-zero
     *  - msg.sender must approve at least `_stUSDAmount` stUSD to this
     *    contract.
     *  - msg.sender must have at least `_stUSDAmount` of stUSD.
     *  User should first approve _stUSDAmount to the WstUSD contract
     * @param stUSDAmount amount of stUSD to wrap in exchange for wstUSD
     * @return Amount of wstUSD user receives after wrap
     */
    function wrap(uint256 stUSDAmount) external returns (uint256);
    /**
     * @notice Exchanges wstUSD to stUSD
     * @dev Requirements:
     *  - `_wstUSDAmount` must be non-zero
     *  - msg.sender must have at least `_wstUSDAmount` wstUSD.
     * @param wstUSDAmount amount of wstUSD to uwrap in exchange for stUSD
     * @return Amount of stUSD user receives after unwrap
     */
    function unwrap(uint256 wstUSDAmount) external returns (uint256);

    /**
     * @notice Get amount of wstUSD for a given amount of stUSD
     * @param stUSDAmount amount of stUSD
     * @return Amount of wstUSD for a given stUSD amount
     */
    function getWstUSDByStUSD(uint256 stUSDAmount) external view returns (uint256);
    
    /**
     * @notice Get amount of stUSD for a given amount of wstUSD
     * @param wstUSDAmount amount of wstUSD
     * @return Amount of stUSD for a given wstUSD amount
     */
    function getStUSDByWstUSD(uint256 wstUSDAmount) external view returns (uint256);

    /**
     * @notice Get amount of stUSD for a one wstUSD
     * @return Amount of stUSD for a 1 wstUSD
     */    
    function stUsdPerToken() external view returns (uint256);
    
    /**
     * @notice Get amount of wstUSD for a one stUSD
     * @return Amount of wstUSD for a 1 stUSD
     */
    function tokensPerStUsd() external view returns (uint256);
    
    /**
     * @notice StUSD token
     */
    function getStUSD() external view returns (IStUSD);
}
