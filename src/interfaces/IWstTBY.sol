// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {MessagingReceipt} from "@LayerZero/oft/interfaces/IOFT.sol";

import {IWstTBYBase} from "./IWstTBYBase.sol";

interface IWstTBY is IWstTBYBase {
    /**
     * @notice Mints wstTBY directly to the user using stTBY underlying token
     * @param amount Underlying amount to deposit
     * @param settings Configuration settings for bridging using LayerZero
     * @return amountMinted Amount of wstTBY minted
     * @return msgReceipts MessagingReceipt Receipts for bridging using LayerZero
     */
    function mintWstTBY(
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
    function mintWstTBY(
        address tby,
        uint256 amount,
        LzSettings memory settings
    )
        external
        payable
        returns (uint256 amountMinted, MessagingReceipt[] memory msgReceipts);
}
