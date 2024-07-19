// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {OApp, Origin} from "@LayerZero/oapp/OApp.sol";
import {MessagingReceipt, MessagingFee} from "@LayerZero/oft/interfaces/IOFT.sol";

import {StakeUpErrors as Errors} from "../helpers/StakeUpErrors.sol";

import {IStTBY} from "../interfaces/IStTBY.sol";
import {IStakeUpMessenger} from "../interfaces/IStakeUpMessenger.sol";

import {OAppController} from "./controllers/OAppController.sol";

/**
 * @title StakeUpMessenger
 * @notice Contract that managing the yield distribution and global share supply messaging synchronization
 *         between cross-chain instances.
 */
contract StakeUpMessenger is IStakeUpMessenger, OAppController {
    // =================== Storage ===================

    /// @dev Address of stTBY contract
    address private immutable _stTBY;

    // =================== Modifiers ===================

    modifier onlyStTBY() {
        if (msg.sender != _stTBY) revert Errors.UnauthorizedCaller();
        _;
    }

    // ================= Constructor =================

    constructor(
        address stTBY,
        address layerZeroEndpoint,
        address bridgeOperator
    ) OAppController(layerZeroEndpoint, bridgeOperator) {
        _stTBY = stTBY;
    }

    // =================== Functions ===================

    /// @inheritdoc IStakeUpMessenger
    function fullSync(
        uint256 newGlobalShares,
        uint256 totalUsd,
        bool yieldIncrease,
        uint32[] memory peerEids,
        bytes memory options,
        address refundRecipient
    ) external payable onlyStTBY returns (MessagingReceipt[] memory receipts) {
        return
            _batchSend(
                MessageType.SharesAndYield,
                abi.encode(newGlobalShares, totalUsd, yieldIncrease),
                peerEids,
                options,
                refundRecipient
            );
    }

    /// @inheritdoc IStakeUpMessenger
    function syncYield(
        uint256 totalUsdAdded,
        bool increase,
        uint32[] memory peerEids,
        bytes memory options,
        address refundRecipient
    ) external payable onlyStTBY returns (MessagingReceipt[] memory receipts) {
        return
            _batchSend(
                increase
                    ? MessageType.IncreaseYield
                    : MessageType.DecreaseYield,
                abi.encode(totalUsdAdded),
                peerEids,
                options,
                refundRecipient
            );
    }

    // ========================= Quote Functions =========================

    /// @inheritdoc IStakeUpMessenger
    function quoteSyncYield(
        uint32[] memory peerEids,
        bytes memory options
    ) external view returns (uint256 nativeFee) {
        return _quoteMessage(MessageType.IncreaseYield, peerEids, options);
    }

    /// @inheritdoc IStakeUpMessenger
    function quoteFullSync(
        uint32[] memory peerEids,
        bytes memory options
    ) external view returns (uint256 nativeFee) {
        return _quoteMessage(MessageType.SharesAndYield, peerEids, options);
    }

    /// @inheritdoc IStakeUpMessenger
    function getStTBY() external view returns (address) {
        return _stTBY;
    }

    /**
     * @notice Quotes the fee for sending a message to instances on other chains
     * @param messageType The type of LayerZero message being sent
     * @param peerEids An array of peer endpoint ids
     * @param options LayerZero messaging options
     */
    function _quoteMessage(
        MessageType messageType,
        uint32[] memory peerEids,
        bytes memory options
    ) internal view returns (uint256 nativeFee) {
        uint256 length = peerEids.length;
        for (uint256 i = 0; i < length; ++i) {
            MessagingFee memory fee = _quote(
                peerEids[i],
                abi.encode(messageType, abi.encode(0, 0)),
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
     * @param encodedData The encoded data to send
     * @param peerEids An array of peer endpoint ids
     * @param options LayerZero messaging options
     */
    function _batchSend(
        MessageType messageType,
        bytes memory encodedData,
        uint32[] memory peerEids,
        bytes memory options,
        address refundRecipient
    ) internal returns (MessagingReceipt[] memory receipts) {
        uint256 providedFee = msg.value;
        bytes memory message = abi.encode(messageType, encodedData);

        uint256 length = peerEids.length;
        receipts = new MessagingReceipt[](length);

        for (uint256 i = 0; i < length; ++i) {
            MessagingReceipt memory receipt = _lzSend(
                peerEids[i],
                message,
                options,
                MessagingFee(providedFee, 0),
                address(this)
            );

            providedFee -= receipt.fee.nativeFee;
            receipts[i] = receipt;
        }

        // If there is excess fee, refund it to the refundRecipient
        if (providedFee > 0) {
            payable(refundRecipient).transfer(providedFee);
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
        (MessageType messageType, bytes memory encodedData) = abi.decode(
            _message,
            (MessageType, bytes)
        );

        if (messageType == MessageType.IncreaseYield) {
            uint256 totalUsd = _decodeYieldData(encodedData);
            IStTBY(_stTBY).accrueYield(totalUsd);
            return;
        }

        if (messageType == MessageType.DecreaseYield) {
            uint256 totalUsd = _decodeYieldData(encodedData);
            IStTBY(_stTBY).removeYield(totalUsd);
            return;
        }

        if (messageType == MessageType.SharesAndYield) {
            (
                uint256 newGlobalShares,
                uint256 totalUsd,
                bool yieldIncreased
            ) = abi.decode(encodedData, (uint256, uint256, bool));

            IStTBY(_stTBY).setGlobalShares(newGlobalShares);

            yieldIncreased
                ? IStTBY(_stTBY).accrueYield(totalUsd)
                : IStTBY(_stTBY).removeYield(totalUsd);

            return;
        }

        revert Errors.InvalidMessageType();
    }

    /**
     * @notice Pays the native fee associated with the message
     * @dev Overrides the OAppSender._payNative function in order to allow for batch sending of messages
     * @dev Without the override, the OAppSender._payNative would revert on the second message due to a
     *      failed conditional checking if msg.value is greater than or equal to the native fee. Instead,
     *      we should check if the balance of the contract is greater than or equal to the native fee
     * @param _nativeFee The native fee to pay
     * @return nativeFee The amount of native fee paid
     */
    function _payNative(
        uint256 _nativeFee
    ) internal view override returns (uint256 nativeFee) {
        uint256 balance = address(this).balance;
        if (balance < _nativeFee) revert NotEnoughNative(balance);
        return _nativeFee;
    }

    /**
     * @notice Decodes the encoded data for the yield update message types
     * @param encodedData The encoded data to decode
     */
    function _decodeYieldData(
        bytes memory encodedData
    ) internal pure returns (uint256 totalUsd) {
        (totalUsd) = abi.decode(encodedData, (uint256));
    }

    /**
     * @notice Decodes the encoded data for share update message types
     * @param encodedData The encoded data to decode
     */
    function _decodeShareData(
        bytes memory encodedData
    ) internal pure returns (uint256 originalShares, uint256 sharesAdded) {
        (originalShares, sharesAdded) = abi.decode(
            encodedData,
            (uint256, uint256)
        );
    }

    receive() external payable {}
}
