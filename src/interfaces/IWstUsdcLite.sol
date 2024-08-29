// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {MessagingReceipt} from "@LayerZero/oft/interfaces/IOFT.sol";

import {IStUsdc} from "./IStUsdc.sol";

interface IWstUsdcLite {
    // =================== Events ===================

    /// @notice Emitted when stUsdc is wrapped to wstUsdc
    event StUsdcWrapped(address indexed user, uint256 stUsdcAmount, uint256 wstUsdcAmount);

    /// @notice Emitted when wstUsdc is unwrapped to stUsdc
    event WtTBYUnwrapped(address indexed user, uint256 wstUsdcAmount, uint256 stUsdcAmount);

    // =================== Functions ===================

    /**
     * @notice Exchanges stUsdc to wstUsdc
     * @dev Requirements:
     *  - `_stUsdcAmount` must be non-zero
     *  - msg.sender must approve at least `_stUsdcAmount` stUsdc to this
     *    contract.
     *  - msg.sender must have at least `_stUsdcAmount` of stUsdc.
     *  User should first approve _stUsdcAmount to the WstUsdc contract
     * @param stUsdcAmount amount of stUsdc to wrap in exchange for wstUsdc
     * @return wstUsdcAmount Amount of wstUsdc user receives after wrap
     */
    function wrap(uint256 stUsdcAmount) external returns (uint256 wstUsdcAmount);

    /**
     * @notice Exchanges wstUsdc to stUsdc
     * @dev Requirements:
     *  - `_wstUsdcAmount` must be non-zero
     *  - msg.sender must have at least `_wstUsdcAmount` wstUsdc.
     * @param wstUsdcAmount amount of wstUsdc to uwrap in exchange for stUsdc
     * @return stUsdcAmount Amount of stUsdc user receives after unwrap
     */
    function unwrap(uint256 wstUsdcAmount) external returns (uint256 stUsdcAmount);

    /**
     * @notice Get amount of wstUsdc for a given amount of stUsdc
     * @param stUsdcAmount amount of stUsdc
     * @return Amount of wstUsdc for a given stUsdc amount
     */
    function getWstUsdcByStUsdc(uint256 stUsdcAmount) external view returns (uint256);

    /**
     * @notice Get amount of stUsdc for a given amount of wstUsdc
     * @param wstUsdcAmount amount of wstUsdc
     * @return Amount of stUsdc for a given wstUsdc amount
     */
    function getStUsdcByWstUsdc(uint256 wstUsdcAmount) external view returns (uint256);

    /**
     * @notice Get amount of stUsdc for a one wstUsdc
     * @return Amount of stUsdc for a 1 wstUsdc
     */
    function stUsdcPerToken() external view returns (uint256);

    /**
     * @notice Get amount of wstUsdc for a one stUsdc
     * @return Amount of wstUsdc for a 1 stUsdc
     */
    function tokensPerStUsdc() external view returns (uint256);

    /**
     * @notice stUsdc token
     */
    function getStUsdc() external view returns (IStUsdc);
}
