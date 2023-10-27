// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IStUSD} from "../interfaces/IStUSD.sol";
import {IWstUSD} from "../interfaces/IWstUSD.sol";

contract WstUSD is IWstUSD, ERC20 {
    using SafeERC20 for ERC20;
    // =================== Constants ===================

    /// @notice StUSD token
    IStUSD public stUSD;

    // =================== Functions ===================
    
    constructor(address _stUSD) ERC20("Wrapped staked USD", "wstUSD") {
        stUSD = IStUSD(_stUSD);
    }

    /**
     * @notice Exchanges stUSD to wstUSD
     * @dev Requirements:
     *  - `_stUSDAmount` must be non-zero
     *  - msg.sender must approve at least `_stUSDAmount` stUSD to this
     *    contract.
     *  - msg.sender must have at least `_stUSDAmount` of stUSD.
     *  User should first approve _stUSDAmount to the WstUSD contract
     * @param _stUSDAmount amount of stUSD to wrap in exchange for wstUSD
     * @return Amount of wstUSD user receives after wrap
     */
    function wrap(uint256 _stUSDAmount) external returns (uint256) {
        if (_stUSDAmount == 0) revert ZeroAmount();
        uint256 wstUSDAmount = stUSD.getSharesByUsd(_stUSDAmount);
        _mint(msg.sender, wstUSDAmount);
        ERC20(address(stUSD)).safeTransferFrom(msg.sender, address(this), _stUSDAmount);
        return wstUSDAmount;
    }

    /**
     * @notice Exchanges wstUSD to stUSD
     * @dev Requirements:
     *  - `_wstUSDAmount` must be non-zero
     *  - msg.sender must have at least `_wstUSDAmount` wstUSD.
     * @param _wstUSDAmount amount of wstUSD to uwrap in exchange for stUSD
     * @return Amount of stUSD user receives after unwrap
     */
    function unwrap(uint256 _wstUSDAmount) external returns (uint256) {
        require(_wstUSDAmount > 0, "wstUSD: zero amount unwrap not allowed");
        uint256 stUSDAmount = stUSD.getUsdByShares(_wstUSDAmount);
        _burn(msg.sender, _wstUSDAmount);
        ERC20(address(stUSD)).safeTransfer(msg.sender, stUSDAmount);
        return stUSDAmount;
    }

    /**
     * @notice Get amount of wstUSD for a given amount of stUSD
     * @param _stUSDAmount amount of stUSD
     * @return Amount of wstUSD for a given stUSD amount
     */
    function getWstUSDByStUSD(uint256 _stUSDAmount) external view returns (uint256) {
        return stUSD.getSharesByUsd(_stUSDAmount);
    }

    /**
     * @notice Get amount of stUSD for a given amount of wstUSD
     * @param _wstUSDAmount amount of wstUSD
     * @return Amount of stUSD for a given wstUSD amount
     */
    function getStUSDByWstUSD(uint256 _wstUSDAmount) external view returns (uint256) {
        return stUSD.getUsdByShares(_wstUSDAmount);
    }

    /**
     * @notice Get amount of stUSD for a one wstUSD
     * @return Amount of stUSD for a 1 wstUSD
     */
    function stUsdPerToken() external view returns (uint256) {
        return stUSD.getUsdByShares(1 ether);
    }

    /**
     * @notice Get amount of wstUSD for a one stUSD
     * @return Amount of wstUSD for a 1 stUSD
     */
    function tokensPerStUsd() external view returns (uint256) {
        return stUSD.getSharesByUsd(1 ether);
    }
}
