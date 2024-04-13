// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {Test} from "forge-std/Test.sol";

import { MessagingFee, SendParam, MessagingReceipt } from "@LayerZero/oft/interfaces/IOFT.sol";
import {OptionsBuilder} from "@LayerZero/oapp/libs/OptionsBuilder.sol";
import {StakeUpMessenger} from "src/messaging/StakeUpMessenger.sol";

import {StTBY} from "src/token/StTBY.sol";
import {ILzBridgeConfig} from "src/interfaces/ILzBridgeConfig.sol";

abstract contract MessagingHelpers is Test {
    using OptionsBuilder for bytes;

    BridgeOptions internal l2BridgeEmpty;

    struct BridgeOptions {
        SendParam sendParam;
        MessagingFee fee;
    }

    enum Operation {
        Deposit,
        Withdraw,
        Poke,
        Redeem
    }

    function _generateSettings(
        StakeUpMessenger messenger,
        Operation operation,
        BridgeOptions memory l2Bridge
    ) internal view returns (ILzBridgeConfig.LzSettings memory) {
        uint32[] memory eids;
        try StTBY(messenger.getStTBY()).peerEids(0) returns (uint32 eid) {
            eids = new uint32[](1);
            eids[0] = eid;
        } catch {
            eids = new uint32[](0);
        }

        bytes memory msgOptions = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(200000, 0);

        uint256 msgFee;
        if (operation == Operation.Deposit) {
            msgFee = messenger.quoteSyncShares(
                eids,
                msgOptions
            );
        } else if (operation == Operation.Withdraw) {
            msgFee = messenger.quoteSyncShares(
                eids,
                msgOptions
            );
        } else if (operation == Operation.Poke) {
            msgFee += messenger.quoteSyncYield(
                eids,
                msgOptions
            );
            msgFee += messenger.quoteSyncShares(
                eids,
                msgOptions
            );
        } else if (operation == Operation.Redeem) {
            msgFee += messenger.quoteSyncYield(
                eids,
                msgOptions
            );
            msgFee += messenger.quoteSyncShares(
                eids,
                msgOptions
            );
        }

        ILzBridgeConfig.LZBridgeSettings memory settings = ILzBridgeConfig.LZBridgeSettings({
            options: l2Bridge.sendParam.extraOptions,
            fee: MessagingFee({
                nativeFee: l2Bridge.fee.nativeFee,
                lzTokenFee: 0
            })
        });

        ILzBridgeConfig.LZMessageSettings memory messageSettings = ILzBridgeConfig.LZMessageSettings({
            options: msgOptions,
            fee: MessagingFee({
                nativeFee: msgFee,
                lzTokenFee: 0
            })
        });

        return ILzBridgeConfig.LzSettings({
            bridgeSettings: settings,
            messageSettings: messageSettings
        });    
    }
}