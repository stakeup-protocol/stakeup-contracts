// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {MessagingReceipt} from "@LayerZero/oft/interfaces/IOFT.sol";

import {ILayerZeroSettings} from "./ILayerZeroSettings.sol";
import {IStTBY} from "./IStTBY.sol";

interface IWstTBY is ILayerZeroSettings {
    /**
     * @notice Exchanges stTBY to wstTBY
     * @dev Requirements:
     *  - `_stTBYAmount` must be non-zero
     *  - msg.sender must approve at least `_stTBYAmount` stTBY to this
     *    contract.
     *  - msg.sender must have at least `_stTBYAmount` of stTBY.
     *  User should first approve _stTBYAmount to the WstTBY contract
     * @param stTBYAmount amount of stTBY to wrap in exchange for wstTBY
     * @return Amount of wstTBY user receives after wrap
     */
    function wrap(uint256 stTBYAmount) external returns (uint256);

    /**
     * @notice Exchanges wstTBY to stTBY
     * @dev Requirements:
     *  - `_wstTBYAmount` must be non-zero
     *  - msg.sender must have at least `_wstTBYAmount` wstTBY.
     * @param wstTBYAmount amount of wstTBY to uwrap in exchange for stTBY
     * @return Amount of stTBY user receives after unwrap
     */
    function unwrap(uint256 wstTBYAmount) external returns (uint256);

    /**
     * @notice Mints wstTBY directly to the user
     * @param tby TBY address. To deposit stTBY underlying token enter address(0)
     * @param amount TBY amount to deposit
     * @param settings Configuration settings for bridging using LayerZero
     * @return amountMinted Amount of wstTBY minted
     * @return bridgingReceipt LzBridgeReceipt Receipts for bridging using LayerZero
     */
    function mintWstTBY(
        address tby,
        uint256 amount,
        LzSettings memory settings
    )
        external
        payable
        returns (
            uint256 amountMinted,
            LzBridgeReceipt memory bridgingReceipt,
            MessagingReceipt[] memory msgReceipts
        );

    /**
     * @notice Get amount of wstTBY for a given amount of stTBY
     * @param stTBYAmount amount of stTBY
     * @return Amount of wstTBY for a given stTBY amount
     */
    function getWstTBYByStTBY(
        uint256 stTBYAmount
    ) external view returns (uint256);

    /**
     * @notice Get amount of stTBY for a given amount of wstTBY
     * @param wstTBYAmount amount of wstTBY
     * @return Amount of stTBY for a given wstTBY amount
     */
    function getStTBYByWstTBY(
        uint256 wstTBYAmount
    ) external view returns (uint256);

    /**
     * @notice Get amount of stTBY for a one wstTBY
     * @return Amount of stTBY for a 1 wstTBY
     */
    function stTBYPerToken() external view returns (uint256);

    /**
     * @notice Get amount of wstTBY for a one stTBY
     * @return Amount of wstTBY for a 1 stTBY
     */
    function tokensPerStTBY() external view returns (uint256);

    /**
     * @notice stTBY token
     */
    function getStTBY() external view returns (IStTBY);
}
