// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IOAppCore} from "@LayerZero/oapp/interfaces/IOAppCore.sol";

import {StakeUpErrors as Errors} from "../helpers/StakeUpErrors.sol";

import {IWstTBYBridge} from "../interfaces/IWstTBYBridge.sol";

import {ControllerBase} from "./controllers/ControllerBase.sol";

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
        address wstTBYBridge,
        address stakeUpMessenger,
        address owner
    ) Ownable2Step() {
        if (
            stTBY == address(0) ||
            wstTBYBridge == address(0) ||
            stakeUpMessenger == address(0) ||
            owner == address(0)
        ) {
            revert Errors.ZeroAddress();
        }
        _transferOwnership(owner);

        _stakeUpContracts = abi.encode(stTBY, wstTBYBridge, stakeUpMessenger);
    }

    // =================== Functions ===================

    /**
     * @notice Sets the yield oracle the network
     * @dev Can only be called by the owner
     * @param newYieldRelayer The address of the new yield relayer
     */
    function setYieldRelayer(address newYieldRelayer) external onlyOwner {
        (address stTBY, , ) = _decodeContracts();
        ControllerBase(stTBY).setYieldRelayer(newYieldRelayer);
    }

    /**
     * @notice Adds a new endpoint to the StakeUp ecosystem
     * @dev Can only be called by the owner
     * @dev The order of the peers is [stTBY, wstTBYBridge, stakeUpMessenger]
     * @param eid The endpoint ID
     * @param peers An array of peer addresses converted to bytes32 for other OApps
     */
    function setPeers(uint32 eid, bytes32[3] memory peers) external onlyOwner {
        _setPeers(eid, peers);
    }

    /**
     * @notice Updates the delegate for all contracts in the StakeUp ecosystem
     * @dev Can only be called by the owner
     * @param newDelegate Address of the new delegate
     */
    function updateDelegate(address newDelegate) external onlyOwner {
        _setDelegates(newDelegate);
    }

    /**
     * @notice Migrates the bridge operator to a new address
     * @dev Can only be called by the owner
     * @param newBridgeOperator The new bridge operator address
     */
    function migrateBridgeOperator(
        address newBridgeOperator
    ) external onlyOwner {
        _setBridgeOperator(newBridgeOperator);
    }

    /**
     * @notice Sets the wstTBY bridge address for the given endpoint ID
     * @dev Can only be called by the owner
     * @param eid The LayerZero Endpoint ID
     * @param bridgeAddress The address of the wstTBY bridge contract
     */
    function setWstTBYBridge(
        uint32 eid,
        address bridgeAddress
    ) external onlyOwner {
        (, address wstTBYBridge, ) = _decodeContracts();
        IWstTBYBridge(wstTBYBridge).setWstTBYBridge(eid, bridgeAddress);
    }

    /**
     * @notice Adds a new peer for each contract in StakeUp
     * @param eid The eid of the peer
     * @param peers An array of peer addresses for other OApps
     */
    function _setPeers(uint32 eid, bytes32[3] memory peers) internal {
        (
            address stTBY,
            address wstTBYBridge,
            address stakeUpMessenger
        ) = _decodeContracts();

        IOAppCore(stTBY).setPeer(eid, peers[0]);
        IOAppCore(wstTBYBridge).setPeer(eid, peers[1]);
        IOAppCore(stakeUpMessenger).setPeer(eid, peers[2]);
    }

    /// @notice Logic for updating the delegate for all contracts in the StakeUp ecosystem
    function _setDelegates(address newDelegate) internal {
        (
            address stTBY,
            address wstTBYBridge,
            address stakeUpMessenger
        ) = _decodeContracts();

        ControllerBase(stTBY).forceSetDelegate(newDelegate);
        ControllerBase(wstTBYBridge).forceSetDelegate(newDelegate);
        ControllerBase(stakeUpMessenger).forceSetDelegate(newDelegate);
    }

    /// @notice Logic for updating the Bridge Operator for all contracts in the StakeUp ecosystem
    function _setBridgeOperator(address newBridgeOperator) internal {
        (
            address stTBY,
            address wstTBYBridge,
            address stakeUpMessenger
        ) = _decodeContracts();

        ControllerBase(stTBY).setBridgeOperator(newBridgeOperator);
        ControllerBase(wstTBYBridge).setBridgeOperator(newBridgeOperator);
        ControllerBase(stakeUpMessenger).setBridgeOperator(newBridgeOperator);
    }

    /// @notice Decodes the _stakeUpContracts bytes to get the respective addresses
    function _decodeContracts()
        internal
        view
        returns (address stTBY, address wstTBYBridge, address stakeUpMessenger)
    {
        return abi.decode(_stakeUpContracts, (address, address, address));
    }
}
