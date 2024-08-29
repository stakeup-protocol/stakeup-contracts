// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IStTBYBase {
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
     * and corresponding stTBY amount.
     * The stTBY amount is calculated twice: before and after the burning incurred rebase.
     * @param account holder of the burnt shares
     * @param preRebaseTokenAmount amount of stTBY the burnt shares corresponded to before the burn
     * @param postRebaseTokenAmount amount of stTBY the burnt shares corresponded to after the burn
     * @param sharesAmount amount of burnt shares
     */
    event SharesBurnt(
        address indexed account, uint256 preRebaseTokenAmount, uint256 postRebaseTokenAmount, uint256 sharesAmount
    );

    /// @notice Emitted when yieldPerShares is updated
    event UpdatedYieldPerShare(uint256 yieldPerShares);

    /**
     * @notice Distribute yield according to the consentration of shares relative to
     *         implementations on other chains.
     * @param yieldPerShares The additional yield per share to be distributed.
     */
    function accrueYield(uint256 yieldPerShares) external;

    /**
     * @notice Transfer shares from caller to recipient
     * @dev Emits a `TransferShares` event.
     * @dev Emits a `Transfer` event.
     * @dev The `sharesAmount` argument is the amount of shares, not tokens.
     * Requirements:
     * - `recipient` cannot be the zero address.
     * - the caller must have at least `sharesAmount` shares.
     * @param recipient recipient of stTBY tokens
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
     * @param sender Sender of stTBY tokens
     * @param recipient Destination of stTBY tokens
     * @param sharesAmount Amount of shares being transfered
     */
    function transferSharesFrom(address sender, address recipient, uint256 sharesAmount) external returns (uint256);

    /**
     * @return the entire amount of Usd controlled by the protocol.
     * @dev The sum of all USD balances in the protocol, equals to the total supply of stTBY.
     */
    function getTotalUsd() external view returns (uint256);

    /**
     * @notice Get the total amount of shares in existence.
     * @dev The sum of all accounts' shares can be an arbitrary number, therefore
     * it is necessary to store it in order to calculate each account's relative share.
     */
    function getTotalShares() external view returns (uint256);

    /**
     * @notice Get the amount of shares owned by `_account`
     * @param account Account to get shares of
     */
    function sharesOf(address account) external view returns (uint256);

    /**
     * @notice Get the amount of shares that corresponds to a given dollar value.
     * @param usdAmount Amount of Usd
     */
    function getSharesByUsd(uint256 usdAmount) external view returns (uint256);

    /**
     * @notice Get the amount of Usd that corresponds to a given number of token shares.
     * @param sharesAmount Amount of shares
     * @return Amount of Usd that corresponds to `sharesAmount` token shares.
     */
    function getUsdByShares(uint256 sharesAmount) external view returns (uint256);
}
