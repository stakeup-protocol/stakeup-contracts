// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {StakeUpKeeper} from "@StakeUp/messaging/StakeUpKeeper.sol";

import {IControllerBase} from "./IControllerBase.sol";
import {IRebasingOFT} from "./IRebasingOFT.sol";

interface IStUsdcLite is IRebasingOFT {
    // =================== Events ===================
    /// @notice Emitted when usdPerShare is updated
    event UpdatedUsdPerShare(uint256 usdPerShare);

    // =================== Functions ===================
    /**
     * @notice Distribute yield according to the consentration of shares relative to
     *         implementations on other chains.
     * @param usdPerShare The new usdPerShare value
     * @param timestamp The timestamp of the last rate update
     */
    function setUsdPerShare(uint256 usdPerShare, uint256 timestamp) external;

    /**
     * @return the entire amount of Usd controlled by the protocol.
     * @dev The sum of all USD balances in the protocol, equals to the total supply of stUsdc.
     */
    function totalUsd() external view returns (uint256);

    /// @notice Get the rewardPerSecond of yield accrual that is distributed 24 hours after rate updates
    function rewardPerSecond() external view returns (uint256);

    /**
     * @notice Get the amount of shares that corresponds to a given dollar value.
     * @param usdAmount Amount of Usd
     */
    function sharesByUsd(uint256 usdAmount) external view returns (uint256);

    /**
     * @notice Get the amount of Usd that corresponds to a given number of token shares.
     * @param sharesAmount Amount of shares
     * @return Amount of Usd that corresponds to `sharesAmount` token shares.
     */
    function usdByShares(uint256 sharesAmount) external view returns (uint256);

    /// @notice Get the total USD value of the protocol
    function totalUsdFloor() external view returns (uint256);

    /// @notice Return the usdPerShare value at the time of the last rate update.
    function lastUsdPerShare() external view returns (uint256);

    /// @notice Get the keeper that can update the yield per share
    function keeper() external view returns (StakeUpKeeper);

    /// @notice The last time the rate was updated
    function lastRateUpdate() external view returns (uint256);
}
