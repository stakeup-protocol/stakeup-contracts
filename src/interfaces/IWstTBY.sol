// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {MessagingReceipt} from "@LayerZero/oft/interfaces/IOFT.sol";

import {IWstTBYBase} from "./IWstTBYBase.sol";

interface IWstTBY is IWstTBYBase {
    // =================== Functions ===================
    /**
     * @notice Mints wstTBY directly to the user using stTBY underlying token
     * @param amount Underlying amount to deposit
     * @param settings Configuration settings for bridging using LayerZero
     * @return amountMinted Amount of wstTBY minted
     * @return msgReceipts MessagingReceipt Receipts for bridging using LayerZero
     */
    function depositUnderlying(
        uint256 amount,
        LzSettings memory settings
    )
        external
        payable
        returns (uint256 amountMinted, MessagingReceipt[] memory msgReceipts);

    /**
     * @notice Mints wstTBY directly to the user using TBYs
     * @param tby TBY address to deposit
     * @param amount TBY amount to deposit
     * @param settings Configuration settings for bridging using LayerZero
     * @return amountMinted Amount of wstTBY minted
     * @return msgReceipts MessagingReceipt Receipts for bridging using LayerZero
     */
    function depositTby(
        address tby,
        uint256 amount,
        LzSettings memory settings
    )
        external
        payable
        returns (uint256 amountMinted, MessagingReceipt[] memory msgReceipts);

    /**
     * @notice Redeem wstTBY in exchange for underlying tokens. Underlying
     * tokens can be withdrawn with the `withdraw()` method, once the
     * redemption is processed.
     * @dev Emits a {Redeemed} event.
     * @param wstTBYAmount Amount of wstTBY
     * @param settings Configuration settings for bridging using LayerZero
     * @return underlyingRedeemed The Amount of underlying tokens redeemed
     * @return msgReceipts MessagingReceipt Receipts for bridging using LayerZero
     */
    function redeemWstTBY(
        uint256 wstTBYAmount,
        LzSettings memory settings
    )
        external
        payable
        returns (
            uint256 underlyingRedeemed,
            MessagingReceipt[] memory msgReceipts
        );
}
