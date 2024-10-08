// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {OFT} from "@LayerZero/oft/OFT.sol";
import {OAppCore} from "@LayerZero/oapp/OApp.sol";

import {StakeUpErrors as Errors} from "@StakeUp/helpers/StakeUpErrors.sol";
import {ControllerBase} from "@StakeUp/messaging/controllers/ControllerBase.sol";

/**
 * @title OFTController
 * @notice Contract that allows the bridge operator to manage the peer's and delegates of
 *        OFTs within the StakeUp ecosystem
 */
abstract contract OFTController is ControllerBase, OFT {
    // =================== Storage ===================
    /// @dev A list of peerEids for the OFT
    uint32[] internal _peerEids;

    // ================= Constructor =================
    constructor(string memory tokenName, string memory tokenSymbol, address layerZeroEndpoint, address bridgeOperator_)
        OFT(tokenName, tokenSymbol, layerZeroEndpoint, bridgeOperator_)
        ControllerBase(bridgeOperator_)
    {
        //solhint-disable-previous-line no-empty-blocks
    }

    // =================== Functions ===================
    /// @inheritdoc ControllerBase
    function setPeer(uint32 eid, bytes32 peer) public virtual override(ControllerBase, OAppCore) onlyBridgeOperator {
        require(eid != 0, Errors.InvalidPeerID());
        require(peer != bytes32(0), Errors.ZeroAddress());
        if (peers[eid] == bytes32(0)) _peerEids.push(eid);
        peers[eid] = peer;
        emit PeerSet(eid, peer);
    }

    /// @inheritdoc ControllerBase
    function forceSetDelegate(address newDelegate) external override onlyBridgeOperator {
        require(newDelegate != address(0), Errors.ZeroAddress());
        endpoint.setDelegate(newDelegate);
    }

    function peerEids() external view returns (uint32[] memory) {
        return _peerEids;
    }
}
