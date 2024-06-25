// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {OFT} from "@LayerZero/oft/OFT.sol";
import {OApp, OAppCore} from "@LayerZero/oapp/OApp.sol";

import {StakeUpErrors as Errors} from "../../helpers/StakeUpErrors.sol";

/**
 * @title ControllerBase
 * @notice Base logic and storage for OApp and OFT controllers to inherit. Controllers in StakeUp are used
 *         by the BridgeOperator to manage the peer's and delegates of the StakeUp ecosystem
 */
abstract contract ControllerBase {
    // =================== Storage ===================
    /// @dev The address of the bridge operator
    address internal _bridgeOperator;

    // ================== Modifiers ==================
    modifier onlyBridgeOperator() {
        if (msg.sender != _bridgeOperator) revert Errors.UnauthorizedCaller();
        _;
    }

    // ================= Constructor =================
    constructor(address bridgeOperator) {
        if (bridgeOperator == address(0)) revert Errors.ZeroAddress();
        _bridgeOperator = bridgeOperator;
    }

    // =================== Functions ==================
    /**
     * @notice Sets the bridge operator address
     * @param newBridgeOperator The new bridge operator address
     */
    function setBridgeOperator(
        address newBridgeOperator
    ) external onlyBridgeOperator {
        if (newBridgeOperator == address(0)) revert Errors.ZeroAddress();
        _bridgeOperator = newBridgeOperator;
    }

    // =================== Interface ===================
    /// @notice Overrides the setPeer function in the OFT and OApp contracts
    function setPeer(uint32 eid, bytes32 peer) external virtual;

    /**
     * @notice Sets the delegate address for the OApp
     * @dev Can only be called by the Bridge Operator
     * @param newDelegate The address of the delegate to be set
     */
    function forceSetDelegate(address newDelegate) external virtual;

    /// @notice Get the Bridge Operator address
    function getBridgeOperator() external view returns (address) {
        return _bridgeOperator;
    }
}
