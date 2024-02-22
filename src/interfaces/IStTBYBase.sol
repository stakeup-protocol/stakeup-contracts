// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

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