// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

library StakeUpConstants {
    // =================== STTBY ===================

    /// @notice Performance fee bps (10%)
    uint16 constant PERFORMANCE_BPS = 1000;

    /// @notice The denominator in Bips for calculating fees
    uint16 constant BPS_DENOMINATOR = 10000;

    /// @notice The amount of time before the end of the commit phase where excess funds will be autostaked in Bloom Pools
    uint256 constant AUTO_STAKE_PHASE = 1 days;

    // =================== VESTING ===================
    /// @notice The duration of the cliff users are subject to
    uint256 constant CLIFF_DURATION = 52 weeks;

    /// @notice The total duration of the vesting period
    uint256 constant VESTING_DURATION = 3 * CLIFF_DURATION;

    /// @notice The initial reward index
    uint256 constant INITIAL_REWARD_INDEX = 1;

    // =================== REWARDS ===================
    /// @notice Curve Reward gauges will be seeded every week
    uint256 constant SEED_INTERVAL = 1 weeks;

    /// @notice Maximum supply of SUP tokens
    uint256 constant MAX_SUPPLY = 1_000_000_000e18;

    /// @notice Total rewards to be distributed to Curve pools
    uint256 constant POOL_REWARDS = 350_000_000e18;

    /// @notice Amount of rewards to be distributed to users for poking the contract (mainnet only)
    uint256 constant POKE_REWARDS = 10_000_000e18;

    // =================== GENERAL ===================
    // @notice Maximum uint256 value
    uint256 constant MAX_UINT_256 = type(uint256).max;

    /// @notice Token decimal scaling for precision
    uint256 constant FIXED_POINT_ONE = 1e18;

    /// @notice One year in seconds
    uint256 constant ONE_YEAR = 52 weeks;
}
