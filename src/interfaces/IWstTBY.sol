// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {MessagingReceipt} from "@LayerZero/oft/interfaces/IOFT.sol";

import {IWstTBYBase} from "./IWstTBYBase.sol";

interface IWstTBY is IWstTBYBase {
    // =================== Functions ===================
    /**
     * @notice Mints wstTBY directly to the user using stTBY underlying token
     * @param amount Underlying amount to deposit
     * @return amountMinted Amount of wstTBY minted
     */
    function depositUnderlying(
        uint256 amount
    ) external returns (uint256 amountMinted);

    /**
     * @notice Mints wstTBY directly to the user using TBYs
     * @param tby TBY address to deposit
     * @param amount TBY amount to deposit
     * @return amountMinted Amount of wstTBY minted
     */
    function depositTby(
        address tby,
        uint256 amount
    ) external returns (uint256 amountMinted);

    /**
     * @notice Redeem wstTBY in exchange for underlying tokens. Underlying
     * tokens can be withdrawn with the `withdraw()` method, once the
     * redemption is processed.
     * @dev Emits a {Redeemed} event.
     * @param wstTBYAmount Amount of wstTBY
     * @return underlyingRedeemed The Amount of underlying tokens redeemed
     */
    function redeemWstTBY(
        uint256 wstTBYAmount
    ) external returns (uint256 underlyingRedeemed);
}
