// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

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
    constructor(
        address layerZeroEndpoint,
        address bridgeOperator
    ) OApp(layerZeroEndpoint, bridgeOperator) ControllerBase(bridgeOperator) {
        // Solhint-disable-previous-line no-empty-blocks
    }

    // =================== Functions ===================
    /// @inheritdoc ControllerBase
    function setPeer(
        uint32 eid,
        bytes32 peer
    ) public virtual override(ControllerBase, OAppCore) onlyBridgeOperator {
        peers[eid] = peer;
        emit PeerSet(eid, peer);
    }

    /// @inheritdoc ControllerBase
    function forceSetDelegate(
        address newDelegate
    ) external override onlyBridgeOperator {
        endpoint.setDelegate(newDelegate);
    }
}
