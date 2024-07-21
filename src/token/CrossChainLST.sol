// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {MessagingReceipt} from "@LayerZero/oft/interfaces/IOFT.sol";

import {StTBYBase} from "./StTBYBase.sol";

import {ILayerZeroSettings} from "../interfaces/ILayerZeroSettings.sol";
import {IStakeUpMessenger} from "../interfaces/IStakeUpMessenger.sol";

/**
 * @title CrossChainLST
 * @notice Abstract contract that holds the logic for distributing yield accross
 *         stTBY holders on all chains.
 */
abstract contract CrossChainLST is StTBYBase, ILayerZeroSettings {
    // =================== Storage ===================

    /// @dev An array of peer endpoint Ids
    uint32[] public peerEids;

    /// @dev Mapping of TBYs last cached exchange rate
    mapping(address => uint256) internal _lastRate;

    // ================= Constructor =================

    constructor(
        address messenger,
        address layerZeroEndpoint,
        address bridgeOperator
    ) StTBYBase(messenger, layerZeroEndpoint, bridgeOperator) {
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
    ) public virtual override onlyBridgeOperator {
        peerEids.push(_eid);
        super.setPeer(_eid, _peer);
    }

    

    /**
     * @notice Syncs both global shares and yield across all chains
     * @dev Uses the current global shares value.
     * @param yieldAdjustment Amount of total USD accrued or removed from the protocol across all chains
     * @param yieldAdded True if yield was added, false if yield was removed
     * @param msgSettings Settings for the LayerZero messages
     */
    function _fullSync(
        uint256 yieldAdjustment,
        bool yieldAdded,
        LzSettings calldata msgSettings
    ) internal returns (MessagingReceipt[] memory) {
        if (yieldAdded) {
            _accrueYield(yieldAdjustment);
        } else {
            _removeYield(yieldAdjustment);
        }

        return
            IStakeUpMessenger(_messenger).fullSync{
                value: msgSettings.fee.nativeFee
            }(
                getGlobalShares(),
                yieldAdjustment,
                yieldAdded,
                peerEids,
                msgSettings.options,
                msgSettings.refundRecipient
            );
    }

    function _getTbyYield() internal virtual returns (uint256);
}
