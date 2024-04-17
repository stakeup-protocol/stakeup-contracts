// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {MessagingReceipt, MessagingFee} from "@LayerZero/oft/interfaces/IOFT.sol";

import {StTBYBase} from "./StTBYBase.sol";

import {IStakeUpMessenger} from "../interfaces/IStakeUpMessenger.sol";

/**
 * @title CrossChainLST
 * @notice Abstract contract that holds the logic for distributing yield accross
 *         stTBY holders on all chains.
 */
abstract contract CrossChainLST is StTBYBase {
    /// @dev An array of peer endpoint Ids
    uint32[] public peerEids;

    /// @dev Mapping of TBYs last cached exchange rate
    mapping(address => uint256) internal _lastRate;

    constructor(
        address messanger,
        address layerZeroEndpoint,
        address layerZeroDelegate
    ) StTBYBase(messanger, layerZeroEndpoint, layerZeroDelegate) {
        // Solhint-disable-previous-line no-empty-blocks
    }

    /**
     * @notice Registers a new OFT instance on a remote chain
     * @dev This function has been overridden to allow for iteration over all peers
     * @param _eid The endpoint ID
     * @param _peer Address of the peer to be associated with the corresponding endpoint in bytes32
     */
    function setPeer(
        uint32 _eid,
        bytes32 _peer
    ) public virtual override onlyOwner {
        peers[_eid] = _peer;
        peerEids.push(_eid);
        emit PeerSet(_eid, _peer);
    }

    /**
     * @notice Decreases the total amount of shares in existence across all chains
     * @dev This function invokes a batch send message w/ LayerZero
     * @param shares Amount of shares to subtract from the global shares value
     */
    function _syncShares(
        uint256 shares,
        bool increase,
        bytes calldata options,
        uint256 msgFee
    ) internal returns (MessagingReceipt[] memory) {
        uint256 prevGlobalShares = _globalShares;

        if (increase) {
            _setGlobalShares(prevGlobalShares + shares);
        } else {
            _setGlobalShares(prevGlobalShares - shares);
        }

        return
            IStakeUpMessenger(_messenger).syncShares{value: msgFee}(
                prevGlobalShares,
                shares,
                increase,
                peerEids,
                options,
                msg.sender
            );
    }

    /**
     * @notice Distributes yield to all stTBY holders on all chains
     * @dev This function invokes a batch send message w/ LayerZero
     * @param amount The amount of total USD accrued by the protocol across all chains
     * @param options Options for the LayerZero message
     * @param msgFee The fee to send the message
     */
    function _syncYield(
        uint256 amount,
        bool increase,
        bytes calldata options,
        uint256 msgFee
    ) internal returns (MessagingReceipt[] memory) {
        if (increase) {
            _accrueYield(_getTbyYield() + amount);
        } else {
            _removeYield(amount);
        }

        return
            IStakeUpMessenger(_messenger).syncYield{value: msgFee}(
                amount,
                increase,
                peerEids,
                options,
                msg.sender
            );
    }

    /**
     *
     * @param sharesAdded Amount of shares to add to global shares value
     * @param yieldAdjustment Amount of total USD accrued or removed from the protocol across all chains
     * @param yieldAdded True if yield was added, false if yield was removed
     * @param options Options for the LayerZero message
     * @param msgFee The fee to send the message
     */
    function _fullSync(
        uint256 sharesAdded,
        uint256 yieldAdjustment,
        bool yieldAdded,
        bytes calldata options,
        uint256 msgFee
    ) internal returns (MessagingReceipt[] memory) {
        uint256 prevGlobalShares = _globalShares;
        _setGlobalShares(prevGlobalShares + sharesAdded);

        if (yieldAdded) {
            _accrueYield(yieldAdjustment);
        } else {
            _removeYield(yieldAdjustment);
        }

        return
            IStakeUpMessenger(_messenger).fullSync{value: msgFee}(
                prevGlobalShares,
                sharesAdded,
                yieldAdjustment,
                yieldAdded,
                peerEids,
                options,
                msg.sender
            );
    }

    function _getTbyYield() internal virtual returns (uint256);
}
