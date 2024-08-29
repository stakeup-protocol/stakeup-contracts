// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IBloomFactory {
    /**
     * @notice Returns the last created pool that was created from the factory
     */
    function getLastCreatedPool() external view returns (address);
}
