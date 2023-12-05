// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IStUSD} from "../interfaces/IStUSD.sol";
import {IWstUSD} from "../interfaces/IWstUSD.sol";

contract WstUSD is IWstUSD, ERC20 {
    using SafeERC20 for ERC20;
    // =================== Constants ===================

    IStUSD private immutable _stUSD;

    // =================== Functions ===================

    constructor(address stUSD) ERC20("Wrapped staked USD", "wstUSD") {
        _stUSD = IStUSD(stUSD);
    }

    /// @inheritdoc IWstUSD
    function wrap(uint256 stUSDAmount) external returns (uint256) {
        if (stUSDAmount == 0) revert ZeroAmount();
        uint256 wstUSDAmount = _stUSD.getSharesByUsd(stUSDAmount);
        _mint(msg.sender, wstUSDAmount);
        ERC20(address(_stUSD)).safeTransferFrom(
            msg.sender,
            address(this),
            stUSDAmount
        );
        return wstUSDAmount;
    }

    /// @inheritdoc IWstUSD
    function unwrap(uint256 wstUSDAmount) external returns (uint256) {
        if (wstUSDAmount == 0) revert ZeroAmount();
        uint256 stUSDAmount = _stUSD.getUsdByShares(wstUSDAmount);
        _burn(msg.sender, wstUSDAmount);
        ERC20(address(_stUSD)).safeTransfer(msg.sender, stUSDAmount);
        return stUSDAmount;
    }

    /// @inheritdoc IWstUSD
    function getWstUSDByStUSD(
        uint256 stUSDAmount
    ) external view returns (uint256) {
        return _stUSD.getSharesByUsd(stUSDAmount);
    }

    /// @inheritdoc IWstUSD
    function getStUSDByWstUSD(
        uint256 wstUSDAmount
    ) external view returns (uint256) {
        return _stUSD.getUsdByShares(wstUSDAmount);
    }

    /// @inheritdoc IWstUSD
    function stUsdPerToken() external view returns (uint256) {
        return _stUSD.getUsdByShares(1 ether);
    }

    /// @inheritdoc IWstUSD
    function tokensPerStUsd() external view returns (uint256) {
        return _stUSD.getSharesByUsd(1 ether);
    }

    /// @inheritdoc IWstUSD
    function getStUSD() external view override returns (IStUSD) {
        return _stUSD;
    }
}
