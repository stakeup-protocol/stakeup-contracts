// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {StakeUpErrors as Errors} from "@StakeUp/helpers/StakeUpErrors.sol";
import {IControllerBase} from "@StakeUp/interfaces/IControllerBase.sol";

/**
 * @title ControllerBase
 * @notice Base logic and storage for OApp and OFT controllers to inherit. Controllers in StakeUp are used
 *         by the BridgeOperator to manage the peer's and delegates of the StakeUp ecosystem
 */
abstract contract ControllerBase is IControllerBase {
    // =================== Storage ===================
    /// @dev The address of the bridge operator
    address internal _bridgeOperator;

    // ================== Modifiers ==================
    modifier onlyBridgeOperator() {
        require(msg.sender == _bridgeOperator, Errors.UnauthorizedCaller());
        _;
    }

    // ================= Constructor =================
    constructor(address bridgeOperator_) {
        require(bridgeOperator_ != address(0), Errors.ZeroAddress());
        _bridgeOperator = bridgeOperator_;
    }

    // =================== Functions ==================
    /**
     * @notice Sets the bridge operator address
     * @param bridgeOperator_ The new bridge operator address
     */
    function setBridgeOperator(address bridgeOperator_) external onlyBridgeOperator {
        require(bridgeOperator_ != address(0), Errors.ZeroAddress());
        _bridgeOperator = bridgeOperator_;
    }

    /// @inheritdoc IControllerBase
    function bridgeOperator() external view returns (address) {
        return _bridgeOperator;
    }

    // =================== Additional Interface ===================
    /// @notice Overrides the setPeer function in the OFT and OApp contracts
    function setPeer(uint32 eid, bytes32 peer) external virtual;

    /**
     * @notice Sets the delegate address for the OApp
     * @dev Can only be called by the Bridge Operator
     * @param newDelegate The address of the delegate to be set
     */
    function forceSetDelegate(address newDelegate) external virtual;
}
