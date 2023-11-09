// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

abstract contract RewardBase {

    uint256 internal constant DECIMAL_SCALING = 1e18;
    uint256 internal constant SUP_MAX_SUPPLY = 1_000_000_000 * DECIMAL_SCALING;
    uint256 internal constant FIVE_YEARS = 5 * 365 days;

    // Additional reward allocations; Follow a 5-year annual halving schedule
    uint256 internal constant STUSD_USDC_REWARDS =
        (SUP_MAX_SUPPLY * 1e5) / DECIMAL_SCALING; // 10% of total supply
    uint256 internal constant WSTUSD_WSTETH_REWARDS =
        (SUP_MAX_SUPPLY * 5e4) / DECIMAL_SCALING; // 5% of total supply
    uint256 internal constant WSTUSD_CHAI_REWARDS =
        (SUP_MAX_SUPPLY * 3e4) / DECIMAL_SCALING; // 3% of total supply
    uint256 internal constant WSTUSD_SUP_REWARDS =
        (SUP_MAX_SUPPLY * 1e4) / DECIMAL_SCALING; // 2% of total supply
    uint256 internal constant SUP_LIQUIDITY_REWARDS =
        (SUP_MAX_SUPPLY * 1e4) / DECIMAL_SCALING; // 2% of total supply
    uint256 internal constant POKE_REWARDS =
        (SUP_MAX_SUPPLY * 1e4) / DECIMAL_SCALING; // 1% of total supply

    function _calculateDripAmount(
        uint256 rewardSupply,
        uint256 startTimestamp,
        uint256 lastRemainingSupply
    ) internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp - startTimestamp;
        uint256 year = timeElapsed / 365 days;

        uint256 supplyUnlocked = rewardSupply / (2**year);
        uint256 existingSupply = rewardSupply - lastRemainingSupply;

        return supplyUnlocked - existingSupply;
    }
}