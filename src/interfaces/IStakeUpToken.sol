// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

interface IStakeUpToken {
    /// @notice Returns the global supply of the token
    function globalSupply() external view returns (uint256);
}
