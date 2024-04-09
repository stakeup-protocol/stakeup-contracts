// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {MessagingReceipt, MessagingFee, OFTReceipt} from "@LayerZero/oft/interfaces/IOFT.sol";

interface ILzBridgeConfig {
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
    struct LzBridgeReceipts {
        MessagingReceipt msgReceipt;
        OFTReceipt oftReceipt;
    }
}
