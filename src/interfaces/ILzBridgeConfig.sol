// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {MessagingReceipt, MessagingFee, OFTReceipt} from "@LayerZero/oft/interfaces/IOFT.sol";

/**
 * @title ILzBridgeConfig
 * @notice An interfaces for the configuration settings and receipts for bridging using LayerZero
 */
interface ILzBridgeConfig {

    struct LzSettings {
        LZBridgeSettings bridgeSettings;
        LZMessageSettings messageSettings;
    }

    struct LzReceipts {
        LzBridgeReceipt bridgeReceipt;
        MessagingReceipt[] messageReceipts;
    }

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
     * @notice Receipts for bridging using LayerZero
     * @param msgReceipt Receipt returned for cross-chain messaging
     * @param oftReceipt Receipt returned for cross-chain OFT bridging
     */
    struct LzBridgeReceipt {
        MessagingReceipt msgReceipt;
        OFTReceipt oftReceipt;
    }
}
