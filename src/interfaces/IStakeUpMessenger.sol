// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {MessagingReceipt} from "@LayerZero/oft/interfaces/IOFT.sol";

interface IStakeUpMessenger {

    error UnauthorizedCaller();

    enum MessageType {
        None,
        IncreaseYield,
        DecreaseYield,
        IncreaseShares,
        DecreaseShares
    }

    function syncIncreaseYield(
        uint256 totalUsdAdded,
        uint32[] memory peerEids,
        bytes memory options,
        address refundRecipient
    ) external payable returns (MessagingReceipt[] memory receipts);

    function syncDecreaseYield(
        uint256 totalUsdAdded,
        uint32[] memory peerEids,
        bytes memory options,
        address refundRecipient
    ) external payable returns (MessagingReceipt[] memory receipts);

    function syncIncreaseShares(
        uint256 originalShares,
        uint256 sharesAdded,
        uint32[] memory peerEids,
        bytes memory options,
        address refundRecipient
    ) external payable returns (MessagingReceipt[] memory receipts);

    function syncDecreaseShares(
        uint256 originalShares,
        uint256 sharesRemoved,
        uint32[] memory peerEids,
        bytes memory options,
        address refundRecipient
    ) external payable returns (MessagingReceipt[] memory receipts);
}