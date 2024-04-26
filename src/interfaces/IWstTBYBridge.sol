// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {ILayerZeroSettings} from "./ILayerZeroSettings.sol";

interface IWstTBYBridge is ILayerZeroSettings {
    /**
     *
     * @param destinationAddress The address to send the bridged wstTBY to
     * @param wstTBYAmount Amount of wstTBY to bridge
     * @param dstEid The destination LayerZero Endpoint ID
     * @param settings Configuration settings for bridging using LayerZero
     * @return bridgingReceipt LzBridgeReceipt Receipts for bridging using LayerZero
     */
    function bridgeWstTBY(
        address destinationAddress,
        uint256 wstTBYAmount,
        uint32 dstEid,
        LZBridgeSettings calldata settings
    ) external payable returns (LzBridgeReceipt memory bridgingReceipt);
}
