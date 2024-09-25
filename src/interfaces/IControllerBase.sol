// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

/**
 * @title IControllerBase
 * @notice Interface for the ControllerBase contract
 */
interface IControllerBase {
    /// @notice Get the Bridge Operator address
    function bridgeOperator() external view returns (address);
}
