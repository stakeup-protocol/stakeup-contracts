// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

library StakeUpConstants {
    // =================== STTBY ===================

    /// @notice Performance fee bps (10%)
    uint16 constant PERFORMANCE_BPS = 1000;

    /// @notice The denominator in Bips for calculating fees
    uint16 constant BPS_DENOMINATOR = 10000;

    // =================== StakeUp ===================
    /// @notice The duration of the cliff users are subject to
    uint256 constant CLIFF_DURATION = 52 weeks;

    /// @notice The total duration of the vesting period
    uint256 constant VESTING_DURATION = 2 * CLIFF_DURATION;

    /// @notice The initial reward index
    uint256 constant INITIAL_REWARD_INDEX = 1;

    /// @notice Maximum supply of SUP tokens
    uint256 constant MAX_SUPPLY = 1_000_000_000e18;

    // =================== GENERAL ===================
    // @notice Maximum uint256 value
    uint256 constant MAX_UINT_256 = type(uint256).max;

    /// @notice Token decimal scaling for precision
    uint256 constant FIXED_POINT_ONE = 1e18;

    /// @notice One day in seconds
    uint256 constant ONE_DAY = 24 hours;
}
