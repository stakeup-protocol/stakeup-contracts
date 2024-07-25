// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {StakeUpErrors as Errors} from "../helpers/StakeUpErrors.sol";

import {IStTBY} from "../interfaces/IStTBY.sol";
import {IYieldRelayer} from "../interfaces/IYieldRelayer.sol";

/**
 * @title YieldRelayer
 * @notice Contract that managing the yield distribution
 */
contract YieldRelayer is IYieldRelayer {
    // =================== Storage ===================

    /// @dev Address of stTBY contract
    address private immutable _stTBY;

    /// @dev Address of the keeper
    address private _keeper;

    // =================== Modifiers ===================
    modifier onlyKeeper() {
        if (msg.sender != _keeper) revert Errors.UnauthorizedCaller();
        _;
    }

    // ================= Constructor =================

    constructor(address stTBY, address keeper) {
        _stTBY = stTBY;
        _keeper = keeper;
    }

    // =================== Functions ===================

    /// @inheritdoc IYieldRelayer
    function updateYield(uint256 yieldPerShare) external override onlyKeeper {
        IStTBY(_stTBY).accrueYield(yieldPerShare);
        emit YieldUpdated(yieldPerShare);
    }

    /// @inheritdoc IYieldRelayer
    function getStTBY() external view returns (address) {
        return _stTBY;
    }
}
