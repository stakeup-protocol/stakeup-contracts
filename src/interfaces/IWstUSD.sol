// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./IStUSD.sol";

interface IWstUSD {
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

    function unwrap(uint256 _wstUSDAmount) external returns (uint256);

    function getStUSDByWstUSD(uint256 _wstUSDAmount) external view returns (uint256);

    function stUSD() external view returns (IStUSD);
}
