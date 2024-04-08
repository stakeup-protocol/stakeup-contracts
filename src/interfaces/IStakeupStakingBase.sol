// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IStakeupToken} from "./IStakeupToken.sol";
import {IStTBY} from "./IStTBY.sol";

/**
 * @title IStakeupStakingBase
 * @notice A minimal interface for the Stakeup Staking contract
 * @dev This interface contains only the necessary functions that are
 *      used by stTBY and SUP to interact with the Staking contract
 */
interface IStakeupStakingBase {

    /// @notice An unauthorized caller attempted to call a function
    error UnauthorizedCaller();

    /// @notice Updates global staking data after protocol fees are taken
    function processFees() external payable;
    
    /// @notice Returns the Stakeup Token
    function getStakupToken() external view returns (IStakeupToken);
    
    /// @notice Returns the stTBY token
    function getStTBY() external view returns (IStTBY);
}
