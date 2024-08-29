// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {StakeUpErrors as Errors} from "../helpers/StakeUpErrors.sol";

import {IStUsdc} from "../interfaces/IStUsdc.sol";
import {IYieldRelayer} from "../interfaces/IYieldRelayer.sol";

/**
 * @title YieldRelayer
 * @notice Contract that managing the yield distribution
 */
contract YieldRelayer is IYieldRelayer {
    // =================== Storage ===================

    /// @dev Address of stUsdc contract
    address private immutable _stUsdc;

    /// @dev Address of the bridge operator
    address private _bridgeOperator;

    /// @dev Address of the keeper
    address private _keeper;

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

    constructor(address stUsdc, address bridgeOperator, address keeper) {
        _stUsdc = stUsdc;
        _bridgeOperator = bridgeOperator;
        _keeper = keeper;
    }

    // =================== Functions ===================

    /// @inheritdoc IYieldRelayer
    function updateYield(uint256 yieldPerShare) external override onlyKeeper {
        IStUsdc(_stUsdc).accrueYield(yieldPerShare);
        emit YieldUpdated(yieldPerShare);
    }

    /**
     * @notice Sets the bridge operator address
     * @param bridgeOperator The new bridge operator address
     */
    function setBridgeOperator(address bridgeOperator) external onlyBridgeOperator {
        if (bridgeOperator == address(0)) revert Errors.ZeroAddress();
        _bridgeOperator = bridgeOperator;
    }

    /// @inheritdoc IYieldRelayer
    function setKeeper(address keeper) external override onlyBridgeOperator {
        if (keeper == address(0)) revert Errors.ZeroAddress();
        _keeper = keeper;
    }

    /// @inheritdoc IYieldRelayer
    function getBridgeOperator() external view override returns (address) {
        return _bridgeOperator;
    }

    /// @inheritdoc IYieldRelayer
    function getKeeper() external view override returns (address) {
        return _keeper;
    }

    /// @inheritdoc IYieldRelayer
    function getStUsdc() external view returns (address) {
        return _stUsdc;
    }
}
