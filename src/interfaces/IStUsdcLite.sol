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

    /**
     * @notice Get the USD per share value from the data feed
     * @dev This function is only available for Lite Deployments where data feeds are used
     */
    function usdPerShareAnswer() external view returns (uint256);

    /// @notice Get the total USD value of the protocol
    function totalUsd() external view returns (uint256);

    /// @notice Get the address of the contract that has the mint and burn roles
    function mintBurnRole() external view returns (address);

    /// @notice Get the address of the data feed that returns the USD per share
    function usdPerShareFeed() external view returns (address);

    /// @notice Get whether the token is a Lite Deployment
    function isLite() external view returns (bool);

    /// @notice Mint shares on the destination chain as part of the bridging process for CCIP burn & mint pools.
    function mintShares(address to, uint256 sharesAmount) external;

    /// @notice Burn shares on the source chain as part of the bridging process for CCIP burn & mint pools.
    function burnShares(uint256 sharesAmount) external;
}
