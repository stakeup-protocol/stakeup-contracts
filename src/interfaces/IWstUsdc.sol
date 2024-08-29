// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {MessagingReceipt} from "@LayerZero/oft/interfaces/IOFT.sol";

import {IWstUsdcLite} from "./IWstUsdcLite.sol";

interface IWstUsdc is IWstUsdcLite {
    // =================== Functions ===================
    /**
     * @notice Mints wstUsdc directly to the user using stUsdc underlying asset
     * @param amount Underlying amount to deposit
     * @return amountMinted Amount of wstUsdc minted
     */
    function depositAsset(uint256 amount) external returns (uint256 amountMinted);

    /**
     * @notice Mints wstUsdc directly to the user using TBYs
     * @param tbyId TBY ID to deposit
     * @param amount TBY amount to deposit
     * @return amountMinted Amount of wstUsdc minted
     */
    function depositTby(uint256 tbyId, uint256 amount) external returns (uint256 amountMinted);

    /**
     * @notice Redeem wstUsdc in exchange for underlying tokens.
     * @dev Emits a {Redeemed} event.
     * @param wstUsdcAmount Amount of wstUsdc
     * @return underlyingRedeemed The Amount of underlying tokens redeemed
     */
    function redeemWstUsdc(uint256 wstUsdcAmount) external returns (uint256 underlyingRedeemed);
}
