// SPD-License-Identifier: MIT

pragma solidity 0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {IStUSD} from "../interfaces/IStUSD.sol";

contract WstUSD is ERC20 {
    IStUSD public stUSD;

    /// @param _stUSD address of the StUSD token to wrap
    constructor(IStUSD _stUSD) ERC20("Wrapped staked USD", "wstUSD", 18) {
        stUSD = _stUSD;
    }

    /// @notice Exchanges stUSD to wstUSD
    /// @param _stUSDAmount amount of stUSD to wrap in exchange for wstUSD
    /// @dev Requirements:
    ///  - `_stUSDAmount` must be non-zero
    ///  - msg.sender must approve at least `_stUSDAmount` stUSD to this
    ///    contract.
    ///  - msg.sender must have at least `_stUSDAmount` of stUSD.
    /// User should first approve _stUSDAmount to the WstUSD contract
    /// @return Amount of wstUSD user receives after wrap
    function wrap(uint256 _stUSDAmount) external returns (uint256) {
        require(_stUSDAmount > 0, "wstUSD: can't wrap zero stUSD");
        uint256 wstUSDAmount = stUSD.getSharesByPooledUsd(_stUSDAmount);
        _mint(msg.sender, wstUSDAmount);
        stUSD.transferFrom(msg.sender, address(this), _stUSDAmount);
        return wstUSDAmount;
    }

    /// @notice Exchanges wstUSD to stUSD
    /// @param _wstUSDAmount amount of wstUSD to uwrap in exchange for stUSD
    /// @dev Requirements:
    ///  - `_wstUSDAmount` must be non-zero
    ///  - msg.sender must have at least `_wstUSDAmount` wstUSD.
    /// @return Amount of stUSD user receives after unwrap
    function unwrap(uint256 _wstUSDAmount) external returns (uint256) {
        require(_wstUSDAmount > 0, "wstUSD: zero amount unwrap not allowed");
        uint256 stUSDAmount = stUSD.getPooledUsdByShares(_wstUSDAmount);
        _burn(msg.sender, _wstUSDAmount);
        stUSD.transfer(msg.sender, stUSDAmount);
        return stUSDAmount;
    }

    /// @notice Get amount of wstUSD for a given amount of stUSD
    /// @param _stUSDAmount amount of stUSD
    /// @return Amount of wstUSD for a given stUSD amount
    function getWstUSDByStUSD(
        uint256 _stUSDAmount
    ) external view returns (uint256) {
        return stUSD.getSharesByPooledUsd(_stUSDAmount);
    }

    /// @notice Get amount of stUSD for a given amount of wstUSD
    /// @param _wstUSDAmount amount of wstUSD
    /// @return Amount of stUSD for a given wstUSD amount
    function getStUSDByWstUSD(
        uint256 _wstUSDAmount
    ) external view returns (uint256) {
        return stUSD.getPooledUsdByShares(_wstUSDAmount);
    }

    /// @notice Get amount of stUSD for a one wstUSD
    /// @return Amount of stUSD for 1 wstUSD
    function stUsdPerToken() external view returns (uint256) {
        return stUSD.getPooledUsdByShares(1 ether);
    }

    /// @notice Get amount of wstUSD for a one stUSD
    /// @return Amount of wstUSD for a 1 stUSD
    function tokensPerStUsd() external view returns (uint256) {
        return stUSD.getSharesByPooledUsd(1 ether);
    }
}
