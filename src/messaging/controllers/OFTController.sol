// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {OFT} from "@LayerZero/oft/OFT.sol";
import {OAppCore} from "@LayerZero/oapp/OApp.sol";

import {StakeUpErrors as Errors} from "../../helpers/StakeUpErrors.sol";

import {ControllerBase} from "./ControllerBase.sol";

/**
 * @title OFTController
 * @notice Contract that allows the bridge operator to manage the peer's and delegates of
 *        OFTs within the StakeUp ecosystem
 */
abstract contract OFTController is ControllerBase, OFT {
    // ================= Constructor =================
    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        address layerZeroEndpoint,
        address bridgeOperator
    )
        OFT(tokenName, tokenSymbol, layerZeroEndpoint, bridgeOperator)
        ControllerBase(bridgeOperator)
    {
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
