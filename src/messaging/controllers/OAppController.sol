// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {OApp, OAppCore} from "@LayerZero/oapp/OApp.sol";

import {StakeUpErrors as Errors} from "../../helpers/StakeUpErrors.sol";

import {ControllerBase} from "./ControllerBase.sol";

/**
 * @title OAppController
 * @notice Contract that allows the bridge operator to manage the peer's and delegates of
 *        OApps within the StakeUp ecosystem
 */
abstract contract OAppController is ControllerBase, OApp {
    // ================= Constructor =================
    constructor(address layerZeroEndpoint, address bridgeOperator_)
        OApp(layerZeroEndpoint, bridgeOperator_)
        ControllerBase(bridgeOperator_)
    {
        // Solhint-disable-previous-line no-empty-blocks
    }

    // =================== Functions ===================
    /// @inheritdoc ControllerBase
    function setPeer(uint32 eid, bytes32 peer) public virtual override(ControllerBase, OAppCore) onlyBridgeOperator {
        if (eid == 0) {
            revert Errors.InvalidPeerID();
        }
        if (peer == bytes32(0)) {
            revert Errors.ZeroAddress();
        }
        peers[eid] = peer;
        emit PeerSet(eid, peer);
    }

    /// @inheritdoc ControllerBase
    function forceSetDelegate(address newDelegate) external override onlyBridgeOperator {
        if (newDelegate == address(0)) {
            revert Errors.ZeroAddress();
        }
        endpoint.setDelegate(newDelegate);
    }
}
