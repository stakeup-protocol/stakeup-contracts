// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

interface IStUSD is IERC20Upgradeable {
    function getUsdByShares(uint256 _sharesAmount) external view returns (uint256);

    function getSharesByUsd(uint256 _usdAmount) external view returns (uint256);
}
