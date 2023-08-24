// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IBloomPool {
    function depositLender(uint256 amount) external returns (uint256 newId);

    function withdrawLender(uint256 shares) external;
}
