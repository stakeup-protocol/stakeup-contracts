// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IControllerBase} from "./IControllerBase.sol";

interface IStUsdcLite is IControllerBase {
    // =================== Events ===================
    /**
     * @notice An executed shares transfer from `sender` to `recipient`.
     * @dev emitted in pair with an ERC20-defined `Transfer` event.
     * @param from Address of the sender
     * @param to Address of the recipient
     * @param sharesAmount Amount of shares transferred
     */
    event TransferShares(address indexed from, address indexed to, uint256 sharesAmount);

    /**
     * @notice An executed `burnShares` request
     * @dev Reports simultaneously burnt shares amount
     * and corresponding stUsdc amount.
     * The stUsdc amount is calculated twice: before and after the burning incurred rebase.
     * @param account holder of the burnt shares
     * @param preRebaseTokenAmount amount of stUsdc the burnt shares corresponded to before the burn
     * @param postRebaseTokenAmount amount of stUsdc the burnt shares corresponded to after the burn
     * @param sharesAmount amount of burnt shares
     */
    event SharesBurnt(
        address indexed account, uint256 preRebaseTokenAmount, uint256 postRebaseTokenAmount, uint256 sharesAmount
    );

    /// @notice Emitted when usdPerShare is updated
    event UpdatedUsdPerShare(uint256 usdPerShare);

    // ==================== Structs ====================
    /**
     * @notice Struct for holding yield data in a single storage slot
     * @param lastRateUpdate The last rate update timestamp
     * @param lastUsdPerShare The usdPerShare value at the time of the last rate update
     * @param rewardPerSecond The rewardPerSecond of yield accrual that is distributed 24 hours after rate updates (per share)
     */
    struct YieldData {
        uint256 lastRateUpdate;
        uint256 lastUsdPerShare;
        uint256 rewardPerSecond;
    }

    // =================== Functions ===================
    /**
     * @notice Distribute yield according to the consentration of shares relative to
     *         implementations on other chains.
     * @param usdPerShare The new usdPerShare value
     * @param timestamp The timestamp of the last rate update
     */
    function setUsdPerShare(uint256 usdPerShare, uint64 timestamp) external;

    /**
     * @notice Transfer shares from caller to recipient
     * @dev Emits a `TransferShares` event.
     * @dev Emits a `Transfer` event.
     * @dev The `sharesAmount` argument is the amount of shares, not tokens.
     * Requirements:
     * - `recipient` cannot be the zero address.
     * - the caller must have at least `sharesAmount` shares.
     * @param recipient recipient of stUsdc tokens
     * @param sharesAmount Amount of shares being transfered
     */
    function transferShares(address recipient, uint256 sharesAmount) external returns (uint256);

    /**
     * @notice Transfer shares from one account to another
     * @dev Emits a `TransferShares` event.
     * @dev Emits a `Transfer` event.
     * Requirements:
     * - `sender` and `recipient` cannot be the zero addresses.
     * - `sender` must have at least `sharesAmount` shares.
     * - the caller must have allowance for `sender`'s tokens of at least `getUsdByShares(sharesAmount)`.
     * @param sender Sender of stUsdc tokens
     * @param recipient Destination of stUsdc tokens
     * @param sharesAmount Amount of shares being transfered
     */
    function transferSharesFrom(address sender, address recipient, uint256 sharesAmount) external returns (uint256);

    /**
     * @return the entire amount of Usd controlled by the protocol.
     * @dev The sum of all USD balances in the protocol, equals to the total supply of stUsdc.
     */
    function totalUsd() external view returns (uint256);

    /**
     * @notice Get the total amount of shares in existence.
     * @dev The sum of all accounts' shares can be an arbitrary number, therefore
     * it is necessary to store it in order to calculate each account's relative share.
     */
    function totalShares() external view returns (uint256);

    /// @notice Get the rewardPerSecond of yield accrual that is distributed 24 hours after rate updates
    function rewardPerSecond() external view returns (uint256);

    /**
     * @notice Get the amount of shares owned by `_account`
     * @param account Account to get shares of
     */
    function sharesOf(address account) external view returns (uint256);

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

    /// @notice Get the address of the keeper that can update the yield per share
    function keeper() external view returns (address);

    // /// @notice The last time the rate was updated
    // function lastRateUpdate() external view returns (uint256);
}
