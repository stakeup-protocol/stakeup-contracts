// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {IOAppCore} from "@LayerZero/oapp/interfaces/IOAppCore.sol";
import {StakeUpErrors as Errors} from "../helpers/StakeUpErrors.sol";

/**
 * @title BridgeOperator
 * @notice Contract that manages the endpoints and peerId's for all contracts within the StakeUp ecosystem
 */
contract BridgeOperator is Ownable2Step {
    // =================== Storage ===================
    bytes private _stakeUpContracts;

    // ================== Constructor ================
    constructor(
        address stTBY,
        address wstTBY,
        address wstTBYBridge,
        address stakeUpMessenger,
        address owner
    ) Ownable2Step() {
        if (
            stTBY == address(0) ||
            wstTBY == address(0) ||
            wstTBYBridge == address(0) ||
            stakeUpMessenger == address(0) ||
            owner == address(0)
        ) {
            revert Errors.ZeroAddress();
        }
        _transferOwnership(owner);

        _stakeUpContracts = abi.encodePacked(
            stTBY,
            wstTBY,
            wstTBYBridge,
            stakeUpMessenger
        );
    }

    // =================== Functions ===================
    /**
     * @notice Adds a new endpoint to the StakeUp ecosystem
     * @dev Can only be called by the owner
     * @param eid The endpoint ID
     * @param endpoint The address of the LayerZero endpoint in bytes32 format
     */
    function setPeers(uint32 eid, bytes32 endpoint) external onlyOwner {
        if (eid == 0) {
            revert Errors.InvalidPeerID();
        }
        if (endpoint == bytes32(0)) {
            revert Errors.ZeroAddress();
        }
        _setPeers(eid, endpoint);
    }

    /**
     * @notice Updates the delegate for all contracts in the StakeUp ecosystem
     * @dev Can only be called by the owner
     * @param newDelegate Address of the new delegate
     */
    function updateDelegate(address newDelegate) external onlyOwner {
        if (newDelegate == address(0)) {
            revert Errors.ZeroAddress();
        }
        _setDelegates(newDelegate);
    }

    /**
     * @notice Adds a new peer for each contract in StakeUp
     * @param eid The eid of the peer
     * @param endpoint The address of the LayerZero endpoint
     */
    function _setPeers(uint32 eid, bytes32 endpoint) internal {
        (
            address stTBY,
            address wstTBY,
            address wstTBYBridge,
            address stakeUpMessenger
        ) = _decodeContracts();

        IOAppCore(stTBY).setPeer(eid, endpoint);
        IOAppCore(wstTBY).setPeer(eid, endpoint);
        IOAppCore(wstTBYBridge).setPeer(eid, endpoint);
        IOAppCore(stakeUpMessenger).setPeer(eid, endpoint);
    }

    /// @notice Logic for updating the delegate for all contracts in the StakeUp ecosystem
    function _setDelegates(address newDelegate) internal {
        if (newDelegate == address(0)) {
            revert Errors.ZeroAddress();
        }

        (
            address stTBY,
            address wstTBY,
            address wstTBYBridge,
            address stakeUpMessenger
        ) = _decodeContracts();

        IOAppCore(stTBY).setDelegate(newDelegate);
        IOAppCore(wstTBY).setDelegate(newDelegate);
        IOAppCore(wstTBYBridge).setDelegate(newDelegate);
        IOAppCore(stakeUpMessenger).setDelegate(newDelegate);
    }

    /// @notice Decodes the _stakeUpContracts bytes to get the respective addresses
    function _decodeContracts()
        internal
        view
        returns (
            address stTBY,
            address wstTBY,
            address wstTBYBridge,
            address stakeUpMessenger
        )
    {
        (stTBY, wstTBY, wstTBYBridge, stakeUpMessenger) = abi.decode(
            _stakeUpContracts,
            (address, address, address, address)
        );
    }
}