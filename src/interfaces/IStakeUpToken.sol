// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IStakeUpTokenLite} from "@StakeUp/interfaces/IStakeUpTokenLite.sol";

interface IStakeUpToken is IStakeUpTokenLite {
    /// @notice Returns the global supply of the token
    function globalSupply() external view returns (uint256);
}
