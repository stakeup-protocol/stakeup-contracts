// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./IStUSD.sol";

interface IWstUSD is IERC20 {
    function unwrap(uint256 _wstUSDAmount) external returns (uint256);

    function getStUSDByWstUSD(uint256 _wstUSDAmount) external view returns (uint256);

    function stUSD() external view returns (IStUSD);
}
