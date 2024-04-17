// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {MessagingReceipt} from "@LayerZero/oft/interfaces/IOFT.sol";

interface IStakeUpMessenger {
    /// @dev Error emitted when caller is not the stTBY contract
    error UnauthorizedCaller();

    /// @dev Error emitted when the provided address is the zero address
    error InvalidMessageType();

    /**
     * @notice Enums for different cross-chain messaging types
     * @param None Message type for no action
     * @param IncreaseYield Message type for increasing yield
     * @param DecreaseYield Message type for decreasing yield
     * @param IncreaseShares Message type for increasing shares
     * @param DecreaseShares Message type for decreasing shares
     * @param SharesAndYield  Message type for increasing shares and yield through fullSync
     */
    enum MessageType {
        None,
        IncreaseYield,
        DecreaseYield,
        IncreaseShares,
        DecreaseShares,
        SharesAndYield
    }

    /**
     * @notice Struct for cross-chain messaging
     * @param messageType The type of message being sent
     * @param enodedData The encoded data for the message
     */
    struct Message {
        MessageType messageType;
        bytes enodedData;
    }

    /**
     * @notice Sends a message to update yield and global shares on other chains
     * @param originalShares Number of shares the protocol had in existence before the update
     * @param sharesAdded Number of shares added to the global shares value
     * @param totalUsd Amount of total USD accrued or removed from the protocol across all chains
     * @param yieldIncreased True if yield was added, false if yield was removed
     * @param peerEids An array of peer endpoint ids
     * @param options LayerZero messaging options
     * @param refundRecipient Address to refund excess LayerZero messaging fees taken in the form of native tokens
     */
    function fullSync(
        uint256 originalShares,
        uint256 sharesAdded,
        uint256 totalUsd,
        bool yieldIncreased,
        uint32[] memory peerEids,
        bytes memory options,
        address refundRecipient
    ) external payable returns (MessagingReceipt[] memory receipts);

    /**
     * @notice Sends a message to increase or decrease yield on other chains
     * @param totalUsd Amount of total USD accrued in the protocol across all chains
     * @param increase True if yield was added, false if yield was removed
     * @param peerEids An array of peer endpoint ids
     * @param options LayerZero messaging options
     * @param refundRecipient Address to refund excess LayerZero messaging fees taken in the form of native tokens
     */
    function syncYield(
        uint256 totalUsd,
        bool increase,
        uint32[] memory peerEids,
        bytes memory options,
        address refundRecipient
    ) external payable returns (MessagingReceipt[] memory receipts);

    /**
     * @notice Sends a message to update global shares on other chains
     * @param originalShares Number of shares the protocol had in existence before the update
     * @param shares Number of shares added or removed from the global shares value
     * @param increase True if shares were added, false if shares were removed
     * @param peerEids An array of peer endpoint ids
     * @param options LayerZero messaging options
     * @param refundRecipient Address to refund excess LayerZero messaging fees taken in the form of native tokens
     */
    function syncShares(
        uint256 originalShares,
        uint256 shares,
        bool increase,
        uint32[] memory peerEids,
        bytes memory options,
        address refundRecipient
    ) external payable returns (MessagingReceipt[] memory receipts);

    /**
     * @notice Quotes the fee for sending a message that updates yield on other chains
     * @param peerEids An array of peer endpoint ids
     * @param options LayerZero messaging options
     */
    function quoteSyncYield(
        uint32[] memory peerEids,
        bytes memory options
    ) external view returns (uint256 nativeFee);

    /**
     * @notice Quotes the fee for sending a message that updates global shares on other chains
     * @param peerEids An array of peer endpoint ids
     * @param options LayerZero messaging options
     */
    function quoteSyncShares(
        uint32[] memory peerEids,
        bytes memory options
    ) external view returns (uint256 nativeFee);

    /**
     * @notice Quotes the fee for sending a message that updates both yield & global shares on other chains
     * @param peerEids An array of peer endpoint ids
     * @param options LayerZero messaging options
     */
    function quoteFullSync(
        uint32[] memory peerEids,
        bytes memory options
    ) external view returns (uint256 nativeFee);

    /// @notice Get the address of the stTBY contract
    function getStTBY() external view returns (address);
}
