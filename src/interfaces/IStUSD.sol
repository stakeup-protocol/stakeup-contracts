// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

interface IStUSD is IERC20Upgradeable {
    // =================== Errors ===================

    /// @notice Invalid address (e.g. zero address)
    error InvalidAddress();

    /// @notice Parameter out of bounds
    error ParameterOutOfBounds();

    /// @notice Insufficient balance
    error InsufficientBalance();

    /// @notice Redemption in progress
    error RedemptionInProgress();

    /// @notice Invalid amount
    error InvalidAmount();

    /// @notice TBY not whitelisted
    error TBYNotWhitelisted();

    /// @notice WstUSD already initialized
    error AlreadyInitialized();

    /// @notice Zero amount
    error ZeroAmount();

    function getUsdByShares(uint256 _sharesAmount) external view returns (uint256);

    function getSharesByUsd(uint256 _usdAmount) external view returns (uint256);
}
