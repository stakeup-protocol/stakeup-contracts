// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IControllerBase} from "./IControllerBase.sol";

interface IRebasingOFT is IControllerBase {
    // =================== Events ===================
    /**
     * @notice An executed shares transfer from `sender` to `recipient`.
     * @dev emitted in pair with an ERC20-defined `Transfer` event.
     * @param from Address of the sender
     * @param to Address of the recipient
     * @param sharesAmount Amount of shares transferred
     */
    event TransferShares(address indexed from, address indexed to, uint256 sharesAmount);

    // =================== Functions ===================
    /**
     * @notice Transfers shares to a recipient
     * @param recipient The recipient of the shares
     * @param sharesAmount The amount of shares to transfer
     * @return The amount of tokens transferred
     */
    function transferShares(address recipient, uint256 sharesAmount) external returns (uint256);

    /**
     * @notice Transfers shares from a specified user to a recipient
     * @param sender The user sending the shares
     * @param recipient The recipient of the shares
     * @param sharesAmount The amount of shares to transfer
     * @return The amount of tokens transferred
     */
    function transferSharesFrom(address sender, address recipient, uint256 sharesAmount) external returns (uint256);

    /// @notice Get the amount of shares for a specified account
    function sharesOf(address account) external view returns (uint256);

    /// @notice Get the total amount of shares
    function totalShares() external view returns (uint256);
}
