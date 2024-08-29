// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {StakeUpErrors as Errors} from "../helpers/StakeUpErrors.sol";

import {StUsdcLite} from "./StUsdcLite.sol";

import {IStUsdc} from "../interfaces/IStUsdc.sol";
import {IWstUsdcLite} from "../interfaces/IWstUsdcLite.sol";

/**
 * @title Wrapped Staked TBY Base
 * @notice The non-rebasing, wrapped version of the stTBY token that accues yield from TBYs
 * @dev This contract is the minimal implementation of the WstTBY token
 */
contract WstUsdcLite is IWstUsdcLite, ERC20 {
    // =================== Constants ===================

    /// @notice Instance of the stTBY contract
    IStTBY internal immutable _stTBY;

    // ================== Constructor ==================

    constructor(address stTBY) ERC20("Wrapped staked TBY", "wstTBY") {
        _stTBY = IStTBY(stTBY);
    }

    // =================== Functions ===================

    /// @inheritdoc IWstTBYBase
    function wrap(uint256 stTBYAmount) external returns (uint256 wstTBYAmount) {
        wstTBYAmount = _mintWstTBY(stTBYAmount);

        ERC20(address(_stTBY)).transferFrom(msg.sender, address(this), stTBYAmount);

        emit StTBYWrapped(msg.sender, stTBYAmount, wstTBYAmount);
    }

    /// @inheritdoc IWstTBYBase
    function unwrap(uint256 wstTBYAmount) external returns (uint256 stTBYAmount) {
        stTBYAmount = _stTBY.getUsdByShares(wstTBYAmount);
        if (stTBYAmount == 0) revert Errors.ZeroAmount();

        _burn(msg.sender, wstTBYAmount);
        StTBYBase(address(_stTBY)).transferShares(msg.sender, wstTBYAmount);

        emit WtTBYUnwrapped(msg.sender, wstTBYAmount, stTBYAmount);
    }

    /// @inheritdoc IWstTBYBase
    function getWstTBYByStTBY(uint256 stTBYAmount) external view returns (uint256) {
        return _stTBY.getSharesByUsd(stTBYAmount);
    }

    /// @inheritdoc IWstTBYBase
    function getStTBYByWstTBY(uint256 wstTBYAmount) external view returns (uint256) {
        return _stTBY.getUsdByShares(wstTBYAmount);
    }

    /// @inheritdoc IWstTBYBase
    function stTBYPerToken() external view returns (uint256) {
        return _stTBY.getUsdByShares(1 ether);
    }

    /// @inheritdoc IWstTBYBase
    function tokensPerStTBY() external view returns (uint256) {
        return _stTBY.getSharesByUsd(1 ether);
    }

    /// @inheritdoc IWstTBYBase
    function getStTBY() external view override returns (IStTBY) {
        return _stTBY;
    }

    /**
     * @notice Mint wstTBY to the user
     * @param amount The amount of stTBY to wrap
     */
    function _mintWstTBY(uint256 amount) internal returns (uint256 wstTBYAmount) {
        wstTBYAmount = _stTBY.getSharesByUsd(amount);
        if (wstTBYAmount == 0) revert Errors.ZeroAmount();
        _mint(msg.sender, wstTBYAmount);
    }
}
