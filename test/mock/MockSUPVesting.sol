// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {ISUPVesting} from "src/interfaces/ISUPVesting.sol";

contract MockSUPVesting is ISUPVesting {

    function getAvailableTokens(
        address account
    ) external view override returns (uint256) {}

    function vestTokens(address account, uint256 amount) external override {
        // do nothing
    }

    function claimAvailableTokens() external override returns (uint256) {}

    function getCurrentBalance(
        address account
    ) external view override returns (uint256) {}

    function getSUPToken() external view override returns (address) {}
}