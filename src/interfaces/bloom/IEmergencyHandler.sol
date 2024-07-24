// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IBloomPool} from "./IBloomPool.sol";

interface IEmergencyHandler {
    /**
     * @notice Redeem underlying assets for lenders of a BloomPool in Emergency Exit mode
     * @param _pool BloomPool that the funds in the emergency handler contract orginated from
     * @return amount of underlying assets redeemed
     */
    function redeemLender(IBloomPool _pool) external returns (uint256);
}
