// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {OApp, Origin} from "@LayerZero/oapp/OApp.sol";
import {MessagingReceipt, MessagingFee} from "@LayerZero/oft/interfaces/IOFT.sol";
import {OFTComposeMsgCodec} from "@LayerZero/oft/libs/OFTComposeMsgCodec.sol";

import {StakeUpErrors as Errors} from "../helpers/StakeUpErrors.sol";

import {LzOrderedMessenger} from "./LzOrderedMessenger.sol";
import {IStUsdc} from "../interfaces/IStUsdc.sol";

/**
 * @title StakeUpKeeper
 * @notice Contract that managing the yield distribution between cross-chain instances of stUsdc
 */
contract StakeUpKeeper is LzOrderedMessenger {
    using OFTComposeMsgCodec for bytes32;

    // =================== Storage ===================
    /// @dev Address of stUsdc contract
    address private immutable _stUsdc;

    // =================== Modifiers ===================
    modifier onlyStUsdc() {
        if (msg.sender != _stUsdc) revert Errors.UnauthorizedCaller();
        _;
    }

    // ================= Constructor =================
    constructor(address stUsdc_, address layerZeroEndpoint, address bridgeOperator)
        LzOrderedMessenger(layerZeroEndpoint, bridgeOperator)
    {
        _stUsdc = stUsdc_;
    }

    // =================== Functions ===================
    /**
     * @notice Syncs all stUsdc instances with the newUsdPerShare value
     * @param newUsdPerShare The new USD per share to be set in the stUsdc contract
     * @param peerEids An array of peer endpoint ids
     * @param options LayerZero messaging options
     * @param refundRecipient The address to refund any excess native fee to
     */
    function sync(uint256 newUsdPerShare, uint32[] memory peerEids, bytes memory options, address refundRecipient)
        external
        payable
        onlyStUsdc
        returns (MessagingReceipt[] memory receipts)
    {
        return _batchSend(abi.encode(newUsdPerShare), peerEids, options, refundRecipient);
    }

    // ========================= Quote Functions =========================
    /**
     * @notice Quotes the fee for syncing all stUsdc instances with the newUsdPerShare value
     * @param expectedUsdPerShare The new USD per share to be set in the stUsdc contract
     * @param peerEids An array of peer endpoint ids
     * @param options LayerZero messaging options
     * @return nativeFee The amount of native fee estimated for syncing all stUsdc instances
     */
    function quoteSync(uint256 expectedUsdPerShare, uint32[] memory peerEids, bytes memory options)
        external
        view
        returns (uint256 nativeFee)
    {
        return _quoteMessage(expectedUsdPerShare, peerEids, options);
    }

    /// @notice Returns the address of the stUsdc contract
    function stUsdc() external view returns (address) {
        return _stUsdc;
    }

    /**
     * @notice Quotes the fee for sending a message to instances on other chains
     * @param expectedUsdPerShare The expected USD per share to be set in the stUsdc contract
     * @param peerEids An array of peer endpoint ids
     * @param options LayerZero messaging options
     */
    function _quoteMessage(uint256 expectedUsdPerShare, uint32[] memory peerEids, bytes memory options)
        internal
        view
        returns (uint256 nativeFee)
    {
        uint256 length = peerEids.length;
        for (uint256 i = 0; i < length; ++i) {
            MessagingFee memory fee = _quote(peerEids[i], abi.encode(expectedUsdPerShare), options, false);
            nativeFee += fee.nativeFee;
        }
    }

    /**
     * @notice Batch sends a message to multiple StakeUpMessenger instances on other chains
     * @param message The encoded message data to send
     * @param peerEids An array of peer endpoint ids
     * @param options LayerZero messaging options
     */
    function _batchSend(bytes memory message, uint32[] memory peerEids, bytes memory options, address refundRecipient)
        internal
        returns (MessagingReceipt[] memory receipts)
    {
        uint256 providedFee = msg.value;

        uint256 length = peerEids.length;
        receipts = new MessagingReceipt[](length);

        for (uint256 i = 0; i < length; ++i) {
            MessagingReceipt memory receipt =
                _lzSend(peerEids[i], message, options, MessagingFee(providedFee, 0), address(this));
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
     *         And makes the necessary relay call to the stUsdc contract
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) internal virtual override {
        super._lzReceive(_origin, _guid, _message, _executor, _extraData);
        uint256 newUsdPerShare = _decodeUsdPerShare(_message);
        IStUsdc(_stUsdc).setUsdPerShare(newUsdPerShare);
    }

    /**
     * @notice Decodes the encoded data for share update message types
     * @param encodedData The encoded data to decode
     */
    function _decodeUsdPerShare(bytes memory encodedData) internal pure returns (uint256) {
        return abi.decode(encodedData, (uint256));
    }
}
