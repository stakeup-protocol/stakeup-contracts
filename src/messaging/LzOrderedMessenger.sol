// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {OApp, Origin} from "@LayerZero/oapp/OApp.sol";
import {StakeUpErrors as Errors} from "@StakeUp/helpers/StakeUpErrors.sol";
import {OAppController} from "@StakeUp/messaging/controllers/OAppController.sol";

/**
 * @title LzOrderedMessengers
 * @notice A contract used to enforce sequential message delivery on LayerZero Messages
 */
abstract contract LzOrderedMessenger is OAppController {
    // =================== Storage ===================
    // Mapping to track the maximum received nonce for each source endpoint and sender
    mapping(uint32 eid => mapping(bytes32 sender => uint64 nonce)) private receivedNonce;

    // ================= Constructor =================
    constructor(address layerZeroEndpoint, address bridgeOperator) OAppController(layerZeroEndpoint, bridgeOperator) {
        // Solhint-disable-previous-line no-empty-blocks
    }

    /**
     * @dev Public function to get the next expected nonce for a given source endpoint and sender.
     * @param _srcEid Source endpoint ID.
     * @param _sender Sender's address in bytes32 format.
     * @return uint64 Next expected nonce.
     */
    function nextNonce(uint32 _srcEid, bytes32 _sender) public view virtual override returns (uint64) {
        return receivedNonce[_srcEid][_sender] + 1;
    }

    /**
     * @dev Internal function to accept nonce from the specified source endpoint and sender.
     * @param _srcEid Source endpoint ID.
     * @param _sender Sender's address in bytes32 format.
     * @param _nonce The nonce to be accepted.
     */
    function _acceptNonce(uint32 _srcEid, bytes32 _sender, uint64 _nonce) internal virtual {
        receivedNonce[_srcEid][_sender] += 1;
        require(_nonce == receivedNonce[_srcEid][_sender], Errors.InvalidNonce());
    }

    /**
     * @notice Receives the message an associated StakeUpMessenger instance on another chain
     *         And makes the necessary relay call to the stUsdc contract
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32, /*_guid*/
        bytes calldata, /*_message*/
        address, /*_executor*/
        bytes calldata /*_extraData*/
    ) internal virtual override {
        _acceptNonce(_origin.srcEid, _origin.sender, _origin.nonce);
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
    function _payNative(uint256 _nativeFee) internal view override returns (uint256 nativeFee) {
        uint256 balance = address(this).balance;
        if (balance < _nativeFee) revert NotEnoughNative(balance);
        return _nativeFee;
    }

    receive() external payable {}
}
