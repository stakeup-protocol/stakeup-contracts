// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {MessagingReceipt, MessagingFee, OFTReceipt} from "@LayerZero/oft/interfaces/IOFT.sol";

/**
 * @title ILayerZeroSettings
 * @notice An interfaces for the configuration settings and receipts for bridging using LayerZero
 */
interface ILayerZeroSettings {
    // ============================ Settings ============================

    /**
     * @notice Messages for bridging using LayerZero
     * @param options a bytes represention of executor options
     * @param fee fee amounts for bridging
     */
    struct LZMessageSettings {
        bytes options;
        MessagingFee fee;
    }

    /**
     * @notice Configuration settings to be used for bridging using LayerZero
     * @param options a bytes represention of executor options
     * @param fee fee amounts for bridging
     */
    struct LZBridgeSettings {
        bytes options;
        MessagingFee fee;
    }

    /**
     * @notice Configuration settings to be used for bridging using LayerZero
     * @param bridgeSettings settings for bridging using LayerZero
     * @param messageSettings settings for messaging using LayerZero
     */
    struct LzSettings {
        LZBridgeSettings bridgeSettings;
        LZMessageSettings messageSettings;
    }

    // ============================ Receipts ============================

    /**
     * @notice Aggregated receipt package for StakeUp transactions
     * @param bridgeReceipt Receipts for bridging using LayerZero
     * @param messageReceipts Receipt returned for cross-chain messaging
     */
    struct LzReceipts {
        LzBridgeReceipt bridgeReceipt;
        MessagingReceipt[] messageReceipts;
    }

    /**
     * @notice Receipts for bridging using LayerZero
     * @param msgReceipt Receipt returned for cross-chain messaging
     * @param oftReceipt Receipt returned for cross-chain OFT bridging
     */
    struct LzBridgeReceipt {
        MessagingReceipt msgReceipt;
        OFTReceipt oftReceipt;
    }
}