// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

import "./IStUSD.sol";

interface IWstUSD is IERC20Upgradeable {
    function unwrap(uint256 _wstUSDAmount) external returns (uint256);

    function getStUSDByWstUSD(uint256 _wstUSDAmount) external view returns (uint256);

    function stUSD() external view returns (IStUSD);
}
