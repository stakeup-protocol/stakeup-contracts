// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStUSD is IERC20 {
    function getUsdByShares(uint256 _sharesAmount) external view returns (uint256);

    function getSharesByUsd(uint256 _usdAmount) external view returns (uint256);
}
