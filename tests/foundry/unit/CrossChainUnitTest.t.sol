// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {LibRLP} from "solady/utils/LibRLP.sol";
import {OptionsBuilder} from "@LayerZero/oapp/libs/OptionsBuilder.sol";
import {OFTComposeMsgCodec} from "@LayerZero/oft/libs/OFTComposeMsgCodec.sol";
import {MessagingFee, SendParam} from "@LayerZero/oft/interfaces/IOFT.sol";

import {StUsdc} from "src/token/StUsdc.sol";
import {StUsdcLite} from "src/token/StUsdcLite.sol";
import {YieldRelayer} from "src/messaging/YieldRelayer.sol";
import {WstUsdc} from "src/token/WstUsdc.sol";
import {WstUsdcLite} from "src/token/WstUsdcLite.sol";
import {WstUsdcBridge} from "src/messaging/WstUsdcBridge.sol";

import {ILayerZeroSettings} from "src/interfaces/ILayerZeroSettings.sol";
import {CrossChainSetup} from "../CrossChainSetup.t.sol";

contract CrossChainUnitTest is CrossChainSetup {
    using OFTComposeMsgCodec for address;
    using OptionsBuilder for bytes;
    using OFTComposeMsgCodec for bytes32;

    // ADJUST THIS VALUE FOR MORE CHAIN DEPLOYMENTS
    uint32 internal constant CHAIN_DEPLOYMENTS = 3;

    function setUp() public virtual override(CrossChainSetup) {
        _setNumberOfEndpoints(CHAIN_DEPLOYMENTS);
        super.setUp();
    }

    function testBridge() public {
        uint256 amount = 10000e6;
        _depositAsset(alice, amount);

        uint256 initialBalanceA = stUsdc.balanceOf(alice);
        uint256 tokensToSend = 1 ether;

        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam = _createSendParam(3, alice, tokensToSend, options);

        uint256 totalUSDValueA = stUsdc.totalUsd();
        StUsdcLite stUsdcDest = StUsdcLite(stakeUpContracts[3].stUsdcLite);

        _performSendAndVerify(3, alice, sendParam, stUsdcDest);

        _assertBalancesAfterBridge(alice, initialBalanceA, tokensToSend, totalUSDValueA, stUsdcDest);
    }

    function testGlobalShares() public {
        StUsdcLite stUsdc2 = StUsdcLite(stakeUpContracts[2].stUsdcLite);

        uint256 amount = 10000e6;
        _depositAsset(alice, amount);

        assertEq(stUsdc.globalShares(), 10000e18);

        _bridgeToChain2(alice, stUsdc2);

        skip(1 days);
        stUsdc.poke();

        assertEq(stUsdc.globalShares(), 10000e18);
    }

    // function testYieldDistribution() public {
    //     uint256 amount = 10000e6;
    //     usdc.mint(address(this), amount * 2);
    //     usdc.approve(address(stUsdc), amount);

    //     stUsdc.depositUnderlying(amount);

    //     skip(3 days);
    //     /// Bridge 50% to chain B
    //     bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
    //     SendParam memory sendParam = SendParam(
    //         bEid, // Destination ID
    //         addressToBytes32(address(this)),
    //         5000e18,
    //         5000e18,
    //         options,
    //         "",
    //         ""
    //     );
    //     MessagingFee memory fee = stUsdc.quoteSend(sendParam, false);

    //     stUsdc.send{value: fee.nativeFee}(sendParam, fee, payable(address(this)));
    //     verifyPackets(bEid, addressToBytes32(address(stTBYB)));

    //     /// Update rates to simulate adding yield to the system
    //     pool.mint(address(stUsdc), 10000e6);

    //     swap.setRate(1.1e18);
    //     registry.setExchangeRate(address(pool), 1.1e18);
    //     bpsFeed.updateRate(1.1e4);

    //     uint256 expectedYieldPerShare = uint256(1e17).divWadUp(stUsdc.globalShares());
    //     console2.log("Expected yield per share: %d", expectedYieldPerShare);
    //     skip(1 days);
    //     stUsdc.poke();
    //     verifyPackets(1, addressToBytes32(address(stUsdc)));

    //     yieldRelayerB.updateYield(expectedYieldPerShare);
    //     assertEq(stUsdc.getTotalUsd(), 5500e18);
    //     assertEq(stTBYB.getTotalUsd(), 5500e18);
    //     assertEq(stUsdc.getTotalUsd() + stTBYB.getTotalUsd(), 11000e18);
    // }

    function testWstTBYBridge() public {
        WstUsdcBridge wstUsdcBridge2 = WstUsdcBridge(stakeUpContracts[2].wstUsdcBridge);
        WstUsdcLite wstUsdc2 = WstUsdcLite(stakeUpContracts[2].wstUsdcLite);
        StUsdcLite stUsdc2 = StUsdcLite(stakeUpContracts[2].stUsdcLite);

        uint256 amount = 10000e6;
        uint256 stUsdcAmount = _depositAsset(alice, amount);

        uint256 wrapAmount = _wrapStUsdc(alice, stUsdcAmount);
        uint256 transferAmount = wrapAmount / 2;

        (ILayerZeroSettings.LzBridgeReceipt memory receipt, bytes memory msgOptions) =
            _bridgeWstUsdc(alice, transferAmount, 2);

        _verifyAndComposeMessage(1, 2, stUsdc2, wstUsdcBridge2, receipt, msgOptions);

        assertEq(wstUsdc.balanceOf(alice), transferAmount);
        assertEq(wstUsdc2.balanceOf(alice), transferAmount);

        skip(1 days);
        stUsdc.poke();
    }

    // Helper functions
    function _createSendParam(uint32 dstChainId, address recipient, uint256 amount, bytes memory options)
        internal
        pure
        returns (SendParam memory)
    {
        return SendParam(dstChainId, addressToBytes32(recipient), amount, amount, options, "", "");
    }

    function _performSendAndVerify(uint32 dstEid, address sender, SendParam memory sendParam, StUsdcLite stUsdcDest)
        internal
    {
        vm.startPrank(sender);
        MessagingFee memory fee = stUsdc.quoteSend(sendParam, false);
        deal(sender, fee.nativeFee);
        stUsdc.send{value: fee.nativeFee}(sendParam, fee, payable(sender));
        verifyPackets(dstEid, addressToBytes32(address(stUsdcDest)));
        vm.stopPrank();
    }

    function _assertBalancesAfterBridge(
        address user,
        uint256 initialBalance,
        uint256 sentAmount,
        uint256 initialTotalUSD,
        StUsdcLite stUsdcDest
    ) internal {
        assertEq(stUsdc.balanceOf(user), initialBalance - sentAmount);
        assertEq(stUsdc.totalUsd(), initialTotalUSD - sentAmount);
        assertEq(stUsdcDest.balanceOf(user), sentAmount);
        assertEq(stUsdcDest.totalUsd(), sentAmount);
    }

    function _bridgeToChain2(address user, StUsdcLite stUsdc2) internal {
        vm.startPrank(user);
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam = _createSendParam(2, user, 2500e18, options);
        MessagingFee memory fee = stUsdc.quoteSend(sendParam, false);
        deal(user, fee.nativeFee);
        stUsdc.send{value: fee.nativeFee}(sendParam, fee, payable(user));
        verifyPackets(2, addressToBytes32(address(stUsdc2)));
        vm.stopPrank();
    }

    function _wrapStUsdc(address user, uint256 amount) internal returns (uint256) {
        vm.startPrank(user);
        stUsdc.approve(address(wstUsdc), amount);
        uint256 wrapAmount = wstUsdc.wrap(amount);
        vm.stopPrank();
        return wrapAmount;
    }

    function _bridgeWstUsdc(address user, uint256 amount, uint32 dstChainId)
        internal
        returns (ILayerZeroSettings.LzBridgeReceipt memory receipt, bytes memory msgOptions)
    {
        vm.startPrank(user);

        msgOptions =
            OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0).addExecutorLzComposeOption(0, 200000, 0);

        MessagingFee memory fee = wstUsdcBridge.quoteBridgeWstUsdc(dstChainId, user, amount, msgOptions);
        ILayerZeroSettings.LzSettings memory settings = ILayerZeroSettings.LzSettings({
            options: msgOptions,
            fee: MessagingFee({nativeFee: fee.nativeFee, lzTokenFee: 0}),
            refundRecipient: user
        });

        wstUsdc.approve(address(wstUsdcBridge), amount);
        deal(user, settings.fee.nativeFee);
        receipt = wstUsdcBridge.bridgeWstUsdc{value: settings.fee.nativeFee}(user, amount, dstChainId, settings);
        vm.stopPrank();
    }

    function _verifyAndComposeMessage(
        uint32 srcChainId,
        uint32 dstChainId,
        StUsdcLite stUsdcDest,
        WstUsdcBridge wstUsdcBridgeDest,
        ILayerZeroSettings.LzBridgeReceipt memory receipt,
        bytes memory msgOptions
    ) internal {
        verifyPackets(dstChainId, addressToBytes32(address(stUsdcDest)));
        verifyPackets(dstChainId, addressToBytes32(address(wstUsdcBridgeDest)));

        bytes memory composerMsg = OFTComposeMsgCodec.encode(
            receipt.msgReceipt.nonce,
            srcChainId,
            receipt.oftReceipt.amountReceivedLD,
            abi.encodePacked(
                addressToBytes32(address(wstUsdcBridge)), abi.encode(alice, receipt.oftReceipt.amountReceivedLD)
            )
        );

        this.lzCompose(
            dstChainId,
            address(stUsdcDest),
            msgOptions,
            receipt.msgReceipt.guid,
            address(wstUsdcBridgeDest),
            composerMsg
        );
    }
}
