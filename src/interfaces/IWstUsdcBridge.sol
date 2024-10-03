// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {ILayerZeroSettings} from "./ILayerZeroSettings.sol";
import {MessagingFee} from "@LayerZero/oft/interfaces/IOFT.sol";

import {IControllerBase} from "./IControllerBase.sol";

interface IWstUsdcBridge is ILayerZeroSettings, IControllerBase {
    // =================== Events ===================

    /// @notice Emitted when a new bridge is set for WstUsdc
    event WstUsdcBridgeSet(uint32 eid, bytes32 bridgeAddress);

    /// @notice Emitted when wstUsdc is bridged sent to another chain
    event WstUsdcBridged(uint32 srcEid, uint32 dstEid, uint256 wstUsdcAmount);

    // =================== Functions ===================

    /**
     * @notice Bridges wstUsdc to another chain using LayerZero
     * @param dstEid The destination LayerZero Endpoint ID
     * @param destinationAddress The address to send the bridged wstUsdc to (casted to bytes32)
     * @param wstUsdcAmount Amount of wstUsdc to bridge
     * @param settings Configuration settings for bridging using LayerZero
     * @return bridgingReceipt LzBridgeReceipt Receipts for bridging using LayerZero
     */
    function bridgeWstUsdc(
        uint32 dstEid,
        bytes32 destinationAddress,
        uint256 wstUsdcAmount,
        LzSettings calldata settings
    ) external payable returns (LzBridgeReceipt memory bridgingReceipt);

    /**
     * @notice Sets the wstUsdc bridge address for the given endpoint ID
     * @param eid The LayerZero Endpoint ID
     * @param bridgeAddress The address of the wstUsdc bridge contract (casted to bytes32)
     */
    function setWstUsdcBridge(uint32 eid, bytes32 bridgeAddress) external;

    /**
     * @notice Quotes the fee for bridging wstUsdc
     * @param dstEid The destination LayerZero Endpoint ID
     * @param destinationAddress The address to send the bridged wstUsdc to (casted to bytes32)
     * @param wstUsdcAmount The amount of wstUsdc being bridged
     * @param options The executor options for calling `bridgeWstUsdc`
     * @return fee The messaging fee for bridging wstUsdc
     */
    function quoteBridgeWstUsdc(
        uint32 dstEid,
        bytes32 destinationAddress,
        uint256 wstUsdcAmount,
        bytes calldata options
    ) external view returns (MessagingFee memory fee);

    /// @notice Returns the address of the stUsdc contract
    function stUsdc() external view returns (address);

    /// @notice Returns the address of the wstUsdc contract
    function wstUsdc() external view returns (address);

    /**
     * @notice Returns the address of the wstUsdc bridge contract for the given endpoint ID
     * @param eid The LayerZero Endpoint ID
     * @return The address of the wstUsdc bridge contract (casted to bytes32)
     */
    function bridgeByEid(uint32 eid) external view returns (bytes32);
}
