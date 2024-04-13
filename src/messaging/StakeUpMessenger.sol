// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {OApp, Origin} from "@LayerZero/oapp/OApp.sol";
import {MessagingReceipt, MessagingFee} from "@LayerZero/oft/interfaces/IOFT.sol";

import {IStTBY} from "../interfaces/IStTBY.sol";
import {IStakeUpMessenger} from "../interfaces/IStakeUpMessenger.sol";

/**
 * @title StakeUpMessenger
 * @notice Contract that managing the yield distribution and global share supply messaging synchronization
 *         between cross-chain instances.
 */
contract StakeUpMessenger is IStakeUpMessenger, OApp {
    /// @dev Address of stTBY contract
    address private immutable _stTBY;

    modifier onlyStTBY() {
        if (msg.sender != _stTBY) revert UnauthorizedCaller();
        _;
    }

    constructor(
        address stTBY,
        address layerZeroEndpoint,
        address layerZeroDelegate
    ) OApp(layerZeroEndpoint, layerZeroDelegate) {
        _stTBY = stTBY;
    }

    /// @inheritdoc IStakeUpMessenger
    function syncIncreaseYield(
        uint256 totalUsdAdded,
        uint32[] memory peerEids,
        bytes memory options,
        address refundRecipient
    ) external payable onlyStTBY returns (MessagingReceipt[] memory receipts) {
        return
            _batchSend(
                MessageType.IncreaseYield,
                totalUsdAdded,
                0,
                peerEids,
                options,
                refundRecipient
            );
    }

    /// @inheritdoc IStakeUpMessenger
    function syncDecreaseYield(
        uint256 totalUsdRemoved,
        uint32[] memory peerEids,
        bytes memory options,
        address refundRecipient
    ) external payable onlyStTBY returns (MessagingReceipt[] memory receipts) {
        return
            _batchSend(
                MessageType.DecreaseYield,
                totalUsdRemoved,
                0,
                peerEids,
                options,
                refundRecipient
            );
    }

    /// @inheritdoc IStakeUpMessenger
    function syncIncreaseShares(
        uint256 originalShares,
        uint256 sharesAdded,
        uint32[] memory peerEids,
        bytes memory options,
        address refundRecipient
    ) external payable onlyStTBY returns (MessagingReceipt[] memory receipts) {
        return
            _batchSend(
                MessageType.IncreaseShares,
                originalShares, // value 1
                sharesAdded, // value 2
                peerEids,
                options,
                refundRecipient
            );
    }

    /// @inheritdoc IStakeUpMessenger
    function syncDecreaseShares(
        uint256 originalShares,
        uint256 sharesRemoved,
        uint32[] memory peerEids,
        bytes memory options,
        address refundRecipient
    ) external payable onlyStTBY returns (MessagingReceipt[] memory receipts) {
        return
            _batchSend(
                MessageType.DecreaseShares,
                originalShares, // value 1
                sharesRemoved, // value 2
                peerEids,
                options,
                refundRecipient
            );
    }

    // ========================= Quote Functions =========================
    function quoteSyncYield(
        uint32[] memory peerEids,
        bytes memory options
    ) external view returns (uint256 nativeFee) {
        return _quoteMessage(MessageType.IncreaseYield, peerEids, options);
    }

    function quoteSyncShares(
        uint32[] memory peerEids,
        bytes memory options
    ) external view returns (uint256 nativeFee) {
        return _quoteMessage(MessageType.IncreaseShares, peerEids, options);
    }

    function getStTBY() external view returns (address) {
        return _stTBY;
    }

    function _quoteMessage(
        MessageType messageType,
        uint32[] memory peerEids,
        bytes memory options
    ) internal view returns (uint256 nativeFee) {
        uint256 length = peerEids.length;
        for (uint256 i = 0; i < length; ++i) {
            MessagingFee memory fee = _quote(
                peerEids[i],
                abi.encode(messageType, 0, 0),
                options,
                false
            );

            nativeFee += fee.nativeFee;
        }
    }

    /**
     * @notice Batch sends a message to multiple StakeUpMessenger instances on other chains
     * @dev We allow for 2 values to be sent in the message the second value wont be used for
     *      the Yield message type
     * @param messageType The type of message to send
     * @param value1 The first value of the message being sent
     * @param value2 The second value of the message being sent
     * @param peerEids An array of peer endpoint ids
     * @param options LayerZero messaging options
     */
    function _batchSend(
        MessageType messageType,
        uint256 value1,
        uint256 value2, // WARNING: this value will be ignored for MessageType.Yield
        uint32[] memory peerEids,
        bytes memory options,
        address refundRecipient
    ) internal returns (MessagingReceipt[] memory receipts) {
        uint256 providedFee = msg.value;
        bytes memory message = abi.encode(messageType, value1, value2);

        uint256 length = peerEids.length;
        receipts = new MessagingReceipt[](length);

        for (uint256 i = 0; i < length; ++i) {
            MessagingReceipt memory receipt = _lzSend(
                peerEids[i],
                message,
                options,
                MessagingFee(providedFee, 0),
                payable(refundRecipient)
            );

            providedFee -= receipt.fee.nativeFee;
            receipts[i] = receipt;
        }
    }

    /**
     * @notice Receives the message an associated StakeUpMessenger instance on another chain
     *         And makes the necessary relay call to the stTBY contract
     */
    function _lzReceive(
        Origin calldata /*_origin*/,
        bytes32 /*_guid*/,
        bytes calldata _message,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) internal virtual override {
        (MessageType messageType, uint256 value1, uint256 value2) = abi.decode(
            _message,
            (MessageType, uint256, uint256)
        );

        if (messageType == MessageType.IncreaseYield) {
            IStTBY(_stTBY).accrueYield(value1);
        }

        if (messageType == MessageType.DecreaseYield) {
            IStTBY(_stTBY).removeYield(value1);
        }

        if (messageType == MessageType.IncreaseShares) {
            IStTBY(_stTBY).increaseGlobalShares(value1, value2);
        }

        if (messageType == MessageType.DecreaseShares) {
            IStTBY(_stTBY).decreaseGlobalShares(value1, value2);
        }
    }
}