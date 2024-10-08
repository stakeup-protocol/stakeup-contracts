// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IOAppCore} from "@LayerZero/oapp/interfaces/IOAppCore.sol";

import {StakeUpErrors as Errors} from "@StakeUp/helpers/StakeUpErrors.sol";

import {ControllerBase} from "@StakeUp/messaging/controllers/ControllerBase.sol";
import {StUsdcLite} from "@StakeUp/token/StUsdcLite.sol";
import {IWstUsdcBridge} from "@StakeUp/interfaces/IWstUsdcBridge.sol";

/**
 * @title BridgeOperator
 * @notice Contract that manages the endpoints and peerId's for all contracts within the StakeUp ecosystem
 */
contract BridgeOperator is Ownable2Step {
    // =================== Storage ===================
    /// @notice Bytes encoded with the addresses of various contracts in the StakeUp ecosystem
    bytes private _stakeUpContracts;

    // ================== Constructor ================
    constructor(address stUsdc, address supToken, address wstUsdcBridge, address owner) Ownable2Step() {
        require(
            stUsdc != address(0) && supToken != address(0) && wstUsdcBridge != address(0) && owner != address(0),
            Errors.ZeroAddress()
        );
        _transferOwnership(owner);

        address keeper = address(StUsdcLite(stUsdc).keeper());
        require(keeper != address(0), Errors.ZeroAddress());

        _stakeUpContracts = abi.encode(stUsdc, supToken, wstUsdcBridge, keeper);
    }

    // =================== Functions ===================
    /**
     * @notice Adds a new endpoint/peer pair to the StakeUp ecosystem
     * @dev Can only be called by the owner
     * @dev The order of the peers is [stUsdc, supToken, wstUsdcBridge, keeper]
     * @param eid The endpoint ID
     * @param peers An array of peer addresses converted to bytes32 for other OApps
     */
    function setPeers(uint32 eid, bytes32[4] memory peers) external onlyOwner {
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
    function migrateBridgeOperator(address newBridgeOperator) external onlyOwner {
        _setBridgeOperator(newBridgeOperator);
    }

    /**
     * @notice Sets the wstUsdc bridge address for the given endpoint ID
     * @dev Can only be called by the owner
     * @param eid The LayerZero Endpoint ID
     * @param bridge The address of the wstUsdc bridge contract (casted to bytes32)
     */
    function setWstUsdcBridge(uint32 eid, bytes32 bridge) external onlyOwner {
        require(bridge != bytes32(0), Errors.ZeroAddress());
        (,, address wstUsdcBridge,) = _decodeContracts();
        IWstUsdcBridge(wstUsdcBridge).setWstUsdcBridge(eid, bridge);
    }

    /**
     * @notice Adds a new peer for each contract in StakeUp
     * @param eid The eid of the peer
     * @param peers An array of peer addresses for other OApps
     */
    function _setPeers(uint32 eid, bytes32[4] memory peers) internal {
        (address stUsdc, address supToken, address wstUsdcBridge, address keeper) = _decodeContracts();

        IOAppCore(stUsdc).setPeer(eid, peers[0]);
        IOAppCore(supToken).setPeer(eid, peers[1]);
        IOAppCore(wstUsdcBridge).setPeer(eid, peers[2]);
        IOAppCore(keeper).setPeer(eid, peers[3]);
    }

    /// @notice Logic for updating the delegate for all contracts in the StakeUp ecosystem
    function _setDelegates(address newDelegate) internal {
        require(newDelegate != address(0), Errors.ZeroAddress());
        (address stUsdc, address supToken, address wstUsdcBridge, address keeper) = _decodeContracts();

        ControllerBase(stUsdc).forceSetDelegate(newDelegate);
        ControllerBase(supToken).forceSetDelegate(newDelegate);
        ControllerBase(wstUsdcBridge).forceSetDelegate(newDelegate);
        ControllerBase(keeper).forceSetDelegate(newDelegate);
    }

    /// @notice Logic for updating the Bridge Operator for all contracts in the StakeUp ecosystem
    function _setBridgeOperator(address newBridgeOperator) internal {
        (address stUsdc, address supToken, address wstUsdcBridge, address keeper) = _decodeContracts();

        ControllerBase(stUsdc).setBridgeOperator(newBridgeOperator);
        ControllerBase(supToken).setBridgeOperator(newBridgeOperator);
        ControllerBase(wstUsdcBridge).setBridgeOperator(newBridgeOperator);
        ControllerBase(keeper).setBridgeOperator(newBridgeOperator);
    }

    /// @notice Decodes the _stakeUpContracts bytes to get the respective addresses
    function _decodeContracts()
        internal
        view
        returns (address stUsdc, address supToken, address wstUsdcBridge, address keeper)
    {
        return abi.decode(_stakeUpContracts, (address, address, address, address));
    }
}
