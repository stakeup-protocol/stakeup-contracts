// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IRebasingERC20} from "@StakeUp/interfaces/IRebasingERC20.sol";
import {IWstUsdcLite} from "@StakeUp/interfaces/IWstUsdcLite.sol";

interface IStUsdcLite is IRebasingERC20 {
    // =================== Events ===================
    /// @notice Emitted when usdPerShare is updated
    event UpdatedUsdPerShare(uint256 usdPerShare);

    // =================== Functions ===================

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
    function totalUsd() external view returns (uint256);

    /// @notice The last time the rate was updated
    function lastRateUpdate() external view returns (uint256);

    function mintShares(address to, uint256 sharesAmount) external;

    function burnShares(uint256 sharesAmount) external;
}
