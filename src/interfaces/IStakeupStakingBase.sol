// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {MessagingReceipt, MessagingFee, OFTReceipt} from "@LayerZero/oft/interfaces/IOFT.sol";

import {ILzBridgeConfig} from "./ILzBridgeConfig.sol";
import {IStakeupToken} from "./IStakeupToken.sol";
import {IStTBY} from "./IStTBY.sol";

/**
 * @title IStakeupStakingBase
 * @notice A minimal interface for the Stakeup Staking contract
 * @dev This interface contains only the necessary functions that are
 *      used by stTBY and SUP to interact with the Staking contract
 */
interface IStakeupStakingBase is ILzBridgeConfig {

    /// @notice An unauthorized caller attempted to call a function
    error UnauthorizedCaller();

    /**
     * @notice Processes stTBY fees and sends them to StakeUp Staking
     * @dev If on a L2 chain, the fees are bridged to the mainnet
     * @param refundRecipient The address to refund the excess LayerZero bridging fees to.
     *        Is an optional parameter on mainnet and can be set to address(0). Do not set
     *        this parameter to address(0) on L2 chains or you will lose the excess fees.
     * @param settings Configuration settings for bridging using LayerZero
     * @return bridgingReceipts LzBridgeReceipts Receipts for bridging using LayerZero
     */
    function processFees(address refundRecipient, LZBridgeSettings memory settings)
        external
        payable
        returns (LzBridgeReceipts memory bridgingReceipts);
    
    /// @notice Returns the Stakeup Token
    function getStakupToken() external view returns (IStakeupToken);
    
    /// @notice Returns the stTBY token
    function getStTBY() external view returns (IStTBY);
}
