// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IControllerBase} from "./IControllerBase.sol";

interface IStakeUpToken is IControllerBase {
    /**
     * @notice Mints SUP rewards
     * @dev This function is callable by the Reward Manager only
     * @param recipient The address that will receive the tokens
     * @param amount The amount of tokens to mint
     */
    function mintRewards(address recipient, uint256 amount) external;

    /// @notice Returns the global supply of the token
    function globalSupply() external view returns (uint256);
}
