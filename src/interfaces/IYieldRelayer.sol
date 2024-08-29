// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IYieldRelayer {
    /// @notice Emitted when yield is updated by the keeper
    event YieldUpdated(uint256 yieldPerShare);

    /// @notice Update yield accrued for the stTBY contract
    function updateYield(uint256 yieldPerShares) external;

    /// @notice Updates the address of the bridge operator
    function setBridgeOperator(address bridgeOperator) external;

    /// @notice Updates the address of the keeper
    function setKeeper(address keeper) external;

    /// @notice Get the address of the bridge operator
    function bridgeOperator() external view returns (address);

    /// @notice Get the address of the keeper
    function keeper() external view returns (address);

    /// @notice Get the address of the stTBY contract
    function stUsdc() external view returns (address);
}
