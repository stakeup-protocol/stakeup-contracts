// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStUSD is IERC20 {
    function getPooledUsdByShares(uint256 _sharesAmount) external view returns (uint256);

    function getSharesByPooledUsd(uint256 _pooledUsdAmount) external view returns (uint256);
}
