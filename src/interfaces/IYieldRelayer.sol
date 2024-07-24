// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

interface IYieldRelayer {
    /// @notice Accrue yield for the stTBY contract
    function accrueYield(uint256 yieldPerShares) external;

    /// @notice Get the address of the stTBY contract
    function getStTBY() external view returns (address);
}
