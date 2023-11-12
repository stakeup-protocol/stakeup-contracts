// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

abstract contract RewardBase {
    address internal _stUsd;
    address internal _stakeupToken;
    address internal _stakeupStaking;

    uint256 internal constant DECIMAL_SCALING = 1e18;
    uint256 internal constant SUP_MAX_SUPPLY = 1_000_000_000 * DECIMAL_SCALING;
    uint256 internal constant FIVE_YEARS = 5 * 365 days;

    // Additional reward allocations; Follow a 5-year annual halving schedule
    uint256 internal constant POOL_REWARDS =
        (SUP_MAX_SUPPLY * 2e17) / DECIMAL_SCALING; // 20% of total supply
    
    uint256 internal constant LAUNCH_MINT_REWARDS =
        (SUP_MAX_SUPPLY * 1e17) / DECIMAL_SCALING; // 10% of total supply

    // Amount of stUSD that is eligible for minting rewards
    uint256 internal constant STUSD_MINT_THREASHOLD = 200_000_000 * DECIMAL_SCALING;
    
    uint256 internal constant POKE_REWARDS =
        (SUP_MAX_SUPPLY * 1e16) / DECIMAL_SCALING; // 1% of total supply

    constructor(
        address stUsd,
        address stakeupToken,
        address stakeupStaking
    ) {
        _stUsd = stUsd;
        _stakeupToken = stakeupToken;
        _stakeupStaking = stakeupStaking;
    }

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