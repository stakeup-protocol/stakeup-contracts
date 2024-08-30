// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {StakeUpErrors as Errors} from "../helpers/StakeUpErrors.sol";

import {StUsdcLite} from "./StUsdcLite.sol";

import {IStUsdc} from "../interfaces/IStUsdc.sol";
import {IWstUsdcLite} from "../interfaces/IWstUsdcLite.sol";

/**
 * @title Wrapped Staked TBY Base
 * @notice The non-rebasing, wrapped version of the stUsdc token that accues yield from TBYs
 * @dev This contract is the minimal implementation of the WstUsdc token
 */
contract WstUsdcLite is IWstUsdcLite, ERC20 {
    // =================== Constants ===================

    /// @notice Instance of the stUsdc contract
    IStUsdc internal immutable _stUsdc;

    // ================== Constructor ==================

    constructor(address stUsdc_) ERC20("wrapped staked USDC", "wstUsdc") {
        _stUsdc = IStUsdc(stUsdc_);
    }

    // =================== Functions ===================

    /// @inheritdoc IWstUsdcLite
    function wrap(uint256 stUsdcAmount) external returns (uint256 wstUsdcAmount) {
        wstUsdcAmount = _mintWstUsdc(stUsdcAmount);
        ERC20(address(_stUsdc)).transferFrom(msg.sender, address(this), stUsdcAmount);
        emit StUsdcWrapped(msg.sender, stUsdcAmount, wstUsdcAmount);
    }

    /// @inheritdoc IWstUsdcLite
    function unwrap(uint256 wstUsdcAmount) external returns (uint256 stUsdcAmount) {
        stUsdcAmount = _stUsdc.usdByShares(wstUsdcAmount);
        if (stUsdcAmount == 0) revert Errors.ZeroAmount();

        _burn(msg.sender, wstUsdcAmount);
        StUsdcLite(address(_stUsdc)).transferShares(msg.sender, wstUsdcAmount);
        emit WtTBYUnwrapped(msg.sender, wstUsdcAmount, stUsdcAmount);
    }

    /// @inheritdoc IWstUsdcLite
    function wstUsdcByStUsdc(uint256 stUsdcAmount) external view returns (uint256) {
        return _stUsdc.sharesByUsd(stUsdcAmount);
    }

    /// @inheritdoc IWstUsdcLite
    function stUsdcByWstUsdc(uint256 wstUsdcAmount) external view returns (uint256) {
        return _stUsdc.usdByShares(wstUsdcAmount);
    }

    /// @inheritdoc IWstUsdcLite
    function stUsdcPerToken() external view returns (uint256) {
        return _stUsdc.usdByShares(1 ether);
    }

    /// @inheritdoc IWstUsdcLite
    function tokensPerStUsdc() external view returns (uint256) {
        return _stUsdc.sharesByUsd(1 ether);
    }

    /// @inheritdoc IWstUsdcLite
    function stUsdc() external view override returns (IStUsdc) {
        return _stUsdc;
    }

    /**
     * @notice Mint wstUsdc to the user
     * @param amount The amount of stUsdc to wrap
     */
    function _mintWstUsdc(uint256 amount) internal returns (uint256 wstUsdcAmount) {
        wstUsdcAmount = _stUsdc.sharesByUsd(amount);
        if (wstUsdcAmount == 0) revert Errors.ZeroAmount();
        _mint(msg.sender, wstUsdcAmount);
    }
}
