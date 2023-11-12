// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IBloomPool} from "./IBloomPool.sol";

interface IEmergencyHandler {
    struct Token {
        address token;
        uint256 rate;
        uint256 rateDecimals;
    }

    struct PoolAccounting {
        uint256 lenderDistro; // Underlying assets available for lenders
        uint256 borrowerDistro; // Underlying assets available for borrowers
        uint256 lenderShares; // Total shares available for lenders
        uint256 borrowerShares; // Total shares available for borrowers
        uint256 totalUnderlying; // Total underlying assets from the pool
        uint256 totalBill; // Total bill assets from the pool
    }

    struct RedemptionInfo {
        Token underlyingToken;
        Token billToken;
        PoolAccounting accounting;
        bool yieldGenerated;
    }

    struct ClaimStatus {
        bool claimed;
        uint256 amountRemaining;
    }

    /**
     * @notice Redeem underlying assets for lenders of a BloomPool in Emergency Exit mode
     * @param _pool BloomPool that the funds in the emergency handler contract orginated from
     * @return amount of underlying assets redeemed
     */
    function redeem(IBloomPool _pool) external returns (uint256);

    /**
     * @notice Get the necessary information to redeem underlying assets for lenders of 
     * a BloomPool in Emergency Exit mode
     * @param _pool BloomPool that the funds in the emergency handler contract orginated from
     * @return redemptionInfo RedemptionInfo struct containing redemption information
     * for a BloomPool in Emergency Exit mode
     */
    function redemptionInfo(IBloomPool _pool)
        external
        view
        returns (RedemptionInfo memory);
}