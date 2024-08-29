// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {OFT} from "@LayerZero/oft/OFT.sol";
import {OAppCore} from "@LayerZero/oapp/OApp.sol";

import {StakeUpErrors as Errors} from "../../helpers/StakeUpErrors.sol";

import {ControllerBase} from "./ControllerBase.sol";
import {IYieldRelayer} from "../../interfaces/IYieldRelayer.sol";

/**
 * @title OFTController
 * @notice Contract that allows the bridge operator to manage the peer's and delegates of
 *        OFTs within the StakeUp ecosystem
 */
abstract contract OFTController is ControllerBase, OFT {
    IYieldRelayer internal _yieldRelayer;

    // ================= Constructor =================
    constructor(string memory tokenName, string memory tokenSymbol, address layerZeroEndpoint, address bridgeOperator)
        OFT(tokenName, tokenSymbol, layerZeroEndpoint, bridgeOperator)
        ControllerBase(bridgeOperator)
    {
        // Solhint-disable-previous-line no-empty-blocks
    }

    // =================== Functions ===================

    /**
     * @notice Sets the yield relayer the network
     * @param yieldRelayer The address of the new yield relayer
     */
    function setYieldRelayer(address yieldRelayer) external onlyBridgeOperator {
        if (yieldRelayer == address(0)) {
            revert Errors.ZeroAddress();
        }
        _yieldRelayer = IYieldRelayer(yieldRelayer);
    }

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
