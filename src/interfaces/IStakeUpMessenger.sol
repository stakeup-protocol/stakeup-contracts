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
     * @notice Sends a message to increase yield on other chains
     * @param totalUsdAdded Amount of total USD accrued in the protocol across all chains
     * @param peerEids An array of peer endpoint ids
     * @param options LayerZero messaging options
     * @param refundRecipient Address to refund excess LayerZero messaging fees taken in the form of native tokens
     */
    function syncIncreaseYield(
        uint256 totalUsdAdded,
        uint32[] memory peerEids,
        bytes memory options,
        address refundRecipient
    ) external payable returns (MessagingReceipt[] memory receipts);

    /**
     * @notice Sends a message to decrease yield on other chains
     * @param totalUsdRemoved Amount of total USD removed in the protocol across all chains
     * @param peerEids An array of peer endpoint ids
     * @param options LayerZero messaging options
     * @param refundRecipient Address to refund excess LayerZero messaging fees taken in the form of native tokens
     */
    function syncDecreaseYield(
        uint256 totalUsdRemoved,
        uint32[] memory peerEids,
        bytes memory options,
        address refundRecipient
    ) external payable returns (MessagingReceipt[] memory receipts);

    /**
     * @notice Sends a message to update yield and global shares on other chains
     * @param originalShares Number of shares the protocol had in existence before the update
     * @param sharesAdded Number of shares added to the global shares value
     * @param peerEids An array of peer endpoint ids
     * @param options LayerZero messaging options
     * @param refundRecipient Address to refund excess LayerZero messaging fees taken in the form of native tokens
     */
    function syncIncreaseShares(
        uint256 originalShares,
        uint256 sharesAdded,
        uint32[] memory peerEids,
        bytes memory options,
        address refundRecipient
    ) external payable returns (MessagingReceipt[] memory receipts);

    /**
     * @notice Sends a message to update yield and global shares on other chains
     * @param originalShares Number of shares the protocol had in existence before the update
     * @param sharesRemoved Number of shares removed from the global shares value
     * @param peerEids An array of peer endpoint ids
     * @param options LayerZero messaging options
     * @param refundRecipient Address to refund excess LayerZero messaging fees taken in the form of native tokens
     */
    function syncDecreaseShares(
        uint256 originalShares,
        uint256 sharesRemoved,
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
