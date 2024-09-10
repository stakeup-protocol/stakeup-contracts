// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {StakeUpErrors as Errors} from "../helpers/StakeUpErrors.sol";

import {IStUsdc} from "../interfaces/IStUsdc.sol";
import {IYieldRelayer} from "../interfaces/IYieldRelayer.sol";

/**
 * @title YieldRelayer
 * @notice Contract that managing the yield distribution
 */
contract YieldRelayer is IYieldRelayer {
    // =================== Storage ===================

    /// @dev Address of the bridge operator
    address private _bridgeOperator;

    /// @dev Address of the keeper
    address private _keeper;

    // =================== Immutables ===================

    /// @dev Address of stUsdc contract
    address private immutable _stUsdc;

    // =================== Modifiers ===================

    modifier onlyBridgeOperator() {
        if (msg.sender != _bridgeOperator) revert Errors.UnauthorizedCaller();
        _;
    }

    modifier onlyKeeper() {
        if (msg.sender != _keeper) revert Errors.UnauthorizedCaller();
        _;
    }

    // ================= Constructor =================

    constructor(address stUsdc_, address bridgeOperator_, address keeper_) {
        _stUsdc = stUsdc_;
        _bridgeOperator = bridgeOperator_;
        _keeper = keeper_;
    }

    // =================== Functions ===================

    /// @inheritdoc IYieldRelayer
    function updateYield(uint256 yieldPerShare) external override onlyKeeper {
        IStUsdc(_stUsdc).setUsdPerShare(yieldPerShare);
        emit YieldUpdated(yieldPerShare);
    }

    /**
     * @notice Sets the bridge operator address
     * @param bridgeOperator_ The new bridge operator address
     */
    function setBridgeOperator(address bridgeOperator_) external onlyBridgeOperator {
        if (bridgeOperator_ == address(0)) revert Errors.ZeroAddress();
        _bridgeOperator = bridgeOperator_;
    }

    /// @inheritdoc IYieldRelayer
    function setKeeper(address keeper_) external override onlyBridgeOperator {
        if (keeper_ == address(0)) revert Errors.ZeroAddress();
        _keeper = keeper_;
    }

    /// @inheritdoc IYieldRelayer
    function bridgeOperator() external view override returns (address) {
        return _bridgeOperator;
    }

    /// @inheritdoc IYieldRelayer
    function keeper() external view override returns (address) {
        return _keeper;
    }

    /// @inheritdoc IYieldRelayer
    function stUsdc() external view returns (address) {
        return _stUsdc;
    }
}
