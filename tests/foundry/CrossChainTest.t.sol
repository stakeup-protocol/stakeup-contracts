// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {Test} from "forge-std/Test.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {LibRLP} from "solady/utils/LibRLP.sol";
import {OptionsBuilder} from "@LayerZero/oapp/libs/OptionsBuilder.sol";
import {OFTComposeMsgCodec} from "@LayerZero/oft/libs/OFTComposeMsgCodec.sol";
import {TestHelper} from "@LayerZeroTesting/TestHelper.sol";
import {MessagingFee, SendParam, MessagingReceipt} from "@LayerZero/oft/interfaces/IOFT.sol";

import {MockBloomPool} from "../mocks/MockBloomPool.sol";
import {MockBloomFactory} from "../mocks/MockBloomFactory.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockRegistry} from "../mocks/MockRegistry.sol";
import {MockSwapFacility} from "../mocks/MockSwapFacility.sol";
import {MessagingHelpers} from "./MessagingHelpers.t.sol";

import {StakeUpMessenger} from "src/messaging/StakeUpMessenger.sol";
import {StakeupStaking, IStakeupStaking} from "src/staking/StakeupStaking.sol";
import {StakeupStakingL2} from "src/staking/StakeupStakingL2.sol";
import {StTBY} from "src/token/StTBY.sol";
import {StakeupToken} from "src/token/StakeupToken.sol";
import {WstTBY} from "src/token/WstTBY.sol";
import {WstTBYBridge} from "src/messaging/WstTBYBridge.sol";

import {ILayerZeroSettings} from "src/interfaces/ILayerZeroSettings.sol";
import {IBloomPool} from "src/interfaces/bloom/IBloomPool.sol";

contract CrossChainTest is TestHelper, MessagingHelpers {
    using FixedPointMathLib for uint256;
    using OFTComposeMsgCodec for address;
    using OptionsBuilder for bytes;

    MockERC20 internal usdc;

    StTBY internal stTBYA;
    StTBY internal stTBYB;

    StakeupToken internal supA;
    StakeupToken internal supB;

    StakeupStaking internal stakeupStaking;
    StakeupStakingL2 internal stakeupStakingL2;

    WstTBY internal wstTBYA;
    WstTBYBridge internal wstTBYBridgeA;
    WstTBY internal wstTBYB;
    WstTBYBridge internal wstTBYBridgeB;

    StakeUpMessenger internal messengerA;
    StakeUpMessenger internal messengerB;

    MockRegistry internal registry;
    MockBloomPool internal pool;
    MockSwapFacility internal swap;
    MockBloomFactory internal bloomFactory;

    uint32 aEid = 1;
    uint32 bEid = 2;

    function setUp() public virtual override {
        usdc = new MockERC20(6);
        MockERC20 bill = new MockERC20(18);

        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        swap = new MockSwapFacility(usdc, bill);

        pool = new MockBloomPool(
            address(usdc),
            address(bill),
            address(swap),
            6
        );
        {
            registry = new MockRegistry(address(pool));
            bloomFactory = new MockBloomFactory();

            bloomFactory.setLastCreatedPool(address(pool));

            address expectedSupAAddress = LibRLP.computeAddress(
                address(this),
                vm.getNonce(address(this)) + 1
            );
            address expectedstTBYAddress = LibRLP.computeAddress(
                address(this),
                vm.getNonce(address(this)) + 2
            );
            address expectedMessengerAAddress = LibRLP.computeAddress(
                address(this),
                vm.getNonce(address(this)) + 3
            );
            address expectedWstTBYAAddress = LibRLP.computeAddress(
                address(this),
                vm.getNonce(address(this)) + 4
            );

            stakeupStaking = new StakeupStaking(
                address(expectedSupAAddress),
                address(expectedstTBYAddress),
                endpoints[aEid]
            );

            supA = new StakeupToken(
                address(stakeupStaking),
                address(0),
                address(this),
                address(endpoints[aEid]),
                address(this)
            );

            stTBYA = new StTBY(
                address(usdc),
                address(stakeupStaking),
                address(bloomFactory),
                address(registry),
                expectedWstTBYAAddress,
                expectedMessengerAAddress,
                false,
                address(endpoints[aEid]),
                address(this)
            );

            messengerA = new StakeUpMessenger(
                address(stTBYA),
                endpoints[aEid],
                address(this)
            );

            wstTBYA = new WstTBY(address(stTBYA));
            wstTBYBridgeA = new WstTBYBridge(
                address(wstTBYA),
                endpoints[aEid],
                address(this)
            );
        }

        {
            address expectedSupBAddress = LibRLP.computeAddress(
                address(this),
                vm.getNonce(address(this)) + 1
            );
            address expectedstTBYBAddress = LibRLP.computeAddress(
                address(this),
                vm.getNonce(address(this)) + 2
            );
            address expectedMessengerAddress = LibRLP.computeAddress(
                address(this),
                vm.getNonce(address(this)) + 3
            );
            address expectedWstTBYBAddress = LibRLP.computeAddress(
                address(this),
                vm.getNonce(address(this)) + 4
            );

            stakeupStakingL2 = new StakeupStakingL2(
                address(expectedSupBAddress),
                address(expectedstTBYBAddress),
                address(stakeupStaking),
                aEid,
                address(endpoints[bEid]),
                address(this)
            );

            supB = new StakeupToken(
                address(stakeupStakingL2),
                address(0),
                address(this),
                address(endpoints[bEid]),
                address(this)
            );

            stTBYB = new StTBY(
                address(usdc),
                address(stakeupStakingL2),
                address(bloomFactory),
                address(registry),
                expectedWstTBYBAddress,
                expectedMessengerAddress,
                false,
                address(endpoints[bEid]),
                address(this)
            );

            messengerB = new StakeUpMessenger(
                address(stTBYB),
                endpoints[bEid],
                address(this)
            );

            wstTBYB = new WstTBY(address(stTBYB));
            wstTBYBridgeB = new WstTBYBridge(
                address(wstTBYB),
                endpoints[bEid],
                address(this)
            );
        }
        pool.setCommitPhaseEnd(block.timestamp + 25 hours);
        pool.setState(IBloomPool.State.Commit);
        registry.setTokenInfos(true);
        address[] memory tokens = new address[](1);
        tokens[0] = address(address(pool));
        registry.setActiveTokens(tokens);
        {
            // config and wire the oapps
            address[] memory stTBYs = new address[](2);
            stTBYs[0] = address(stTBYA);
            stTBYs[1] = address(stTBYB);
            this.wireOApps(stTBYs);

            address[] memory sups = new address[](2);
            sups[0] = address(supA);
            sups[1] = address(supA);
            this.wireOApps(sups);

            address[] memory messengers = new address[](2);
            messengers[0] = stTBYA.getMessenger();
            messengers[1] = stTBYB.getMessenger();
            this.wireOApps(messengers);

            address[] memory wstTBYBridges = new address[](2);
            wstTBYBridges[0] = address(wstTBYBridgeA);
            wstTBYBridges[1] = address(wstTBYBridgeB);
            this.wireOApps(wstTBYBridges);

            wstTBYBridgeA.setWstTBYBridge(bEid, address(wstTBYBridgeB));
            wstTBYBridgeB.setWstTBYBridge(aEid, address(wstTBYBridgeA));
        }
    }

    function testBridge() public {
        uint256 amount = 10000e6;
        usdc.mint(address(this), amount * 2);
        usdc.approve(address(stTBYA), amount);

        ILayerZeroSettings.LzSettings memory settings = _generateSettings(
            messengerB,
            Operation.Deposit,
            l2BridgeEmpty
        );

        uint256 depositValue = settings.bridgeSettings.fee.nativeFee +
            settings.messageSettings.fee.nativeFee;
        stTBYA.depositUnderlying{value: depositValue}(amount, settings);

        uint256 initialBalanceA = stTBYA.balanceOf(address(this));
        uint256 tokensToSend = 1 ether;

        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam = SendParam(
            bEid, // Destination ID
            addressToBytes32(address(this)),
            tokensToSend,
            tokensToSend,
            options,
            "",
            ""
        );
        MessagingFee memory fee = stTBYA.quoteSend(sendParam, false);

        assertEq(stTBYA.balanceOf(address(this)), initialBalanceA);
        assertEq(stTBYB.balanceOf(address(this)), 0);

        uint256 totalUSDValueA = stTBYA.getTotalUsd();

        stTBYA.send{value: fee.nativeFee}(
            sendParam,
            fee,
            payable(address(this))
        );
        verifyPackets(bEid, addressToBytes32(address(stTBYB)));

        assertEq(
            stTBYA.balanceOf(address(this)),
            initialBalanceA - tokensToSend
        );
        assertEq(stTBYA.getTotalUsd(), totalUSDValueA - tokensToSend);

        assertEq(stTBYB.balanceOf(address(this)), tokensToSend);
        assertEq(stTBYB.getTotalUsd(), tokensToSend);
    }

    function testProcessFees() public {
        uint256 amount = 10000e6;
        usdc.mint(address(this), amount * 2);

        usdc.approve(address(stTBYA), amount);
        usdc.approve(address(stTBYB), amount);

        uint256 initialRewardBlock = stakeupStaking.getLastRewardBlock();
        vm.roll(10);

        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(20000000, 0)
            .addExecutorLzComposeOption(0, 50000000, 0);

        SendParam memory sendParam = SendParam({
            dstEid: aEid,
            to: address(stakeupStaking).addressToBytes32(),
            amountLD: 1000000000000000000, // Expected Fee amount
            minAmountLD: 1000000000000000000, // Expected Fee amount
            extraOptions: options,
            composeMsg: stakeupStakingL2.PROCESS_FEE_MSG(),
            oftCmd: ""
        });

        MessagingFee memory fee = stTBYB.quoteSend(sendParam, false);

        BridgeOptions memory l2Bridge = BridgeOptions({
            sendParam: sendParam,
            fee: fee
        });

        ILayerZeroSettings.LzSettings memory settings = _generateSettings(
            messengerB,
            Operation.Deposit,
            l2Bridge
        );
        uint256 depositValue = settings.bridgeSettings.fee.nativeFee +
            settings.messageSettings.fee.nativeFee;

        (, ILayerZeroSettings.LzBridgeReceipt memory receipt, ) = stTBYB
            .depositUnderlying{value: depositValue}(amount, settings);
        verifyPackets(aEid, addressToBytes32(address(stTBYA)));
        verifyPackets(aEid, addressToBytes32(address(messengerA)));

        uint32 dstEid_ = aEid;
        address from_ = address(stTBYA);
        bytes memory options_ = options;
        bytes32 guid_ = receipt.msgReceipt.guid;
        address to_ = address(stakeupStaking);
        bytes memory composerMsg_ = OFTComposeMsgCodec.encode(
            receipt.msgReceipt.nonce,
            bEid,
            receipt.oftReceipt.amountReceivedLD,
            abi.encodePacked(
                addressToBytes32(address(stakeupStakingL2)),
                stakeupStakingL2.PROCESS_FEE_MSG()
            )
        );

        vm.startPrank(endpoints[aEid]);
        this.lzCompose(dstEid_, from_, options_, guid_, to_, composerMsg_);

        assertGt(stTBYB.balanceOf(address(this)), 0);

        // When fees are processed on chain B they will be bridged to chain A and the reward state should update
        uint256 balance = stTBYA.balanceOf(address(stakeupStaking));
        assertGt(balance, 0);
        assertGt(stakeupStaking.getLastRewardBlock(), initialRewardBlock);
    }

    function testGlobalShares() public {
        uint256 amount = 10000e6;
        usdc.mint(address(this), amount * 2);
        usdc.approve(address(stTBYA), amount);

        ILayerZeroSettings.LzSettings memory settings = _generateSettings(
            messengerB,
            Operation.Deposit,
            l2BridgeEmpty
        );

        stTBYA.depositUnderlying{value: 1e18}(amount, settings);
        verifyPackets(aEid, addressToBytes32(address(stTBYA)));
        verifyPackets(bEid, addressToBytes32(address(messengerB)));

        assertEq(stTBYA.getGlobalShares(), 10000e18);
        assertEq(stTBYA.getGlobalShares(), stTBYB.getGlobalShares());
        assertEq(stTBYA.getSupplyIndex(), 1e18);
        assertEq(stTBYB.getSupplyIndex(), 0);
        {
            /// Bridge 25% to chain B
            bytes memory options = OptionsBuilder
                .newOptions()
                .addExecutorLzReceiveOption(200000, 0);
            SendParam memory sendParam = SendParam(
                bEid, // Destination ID
                addressToBytes32(address(this)),
                2500e18,
                2500e18,
                options,
                "",
                ""
            );
            MessagingFee memory fee = stTBYA.quoteSend(sendParam, false);

            stTBYA.send{value: fee.nativeFee}(
                sendParam,
                fee,
                payable(address(this))
            );
            verifyPackets(bEid, addressToBytes32(address(stTBYB)));
        }

        assertEq(stTBYA.getGlobalShares(), 10000e18);
        assertEq(stTBYB.getGlobalShares(), 10000e18);
        assertEq(stTBYA.getSupplyIndex(), 75e16);
        assertEq(stTBYB.getSupplyIndex(), 25e16);
    }

    function testYieldDistribution() public {
        uint256 amount = 10000e6;
        usdc.mint(address(this), amount * 2);
        usdc.approve(address(stTBYA), amount);

        ILayerZeroSettings.LzSettings memory settings = _generateSettings(
            messengerB,
            Operation.Deposit,
            l2BridgeEmpty
        );

        stTBYA.depositUnderlying{value: 1e18}(amount, settings);
        verifyPackets(aEid, addressToBytes32(address(stTBYA)));
        verifyPackets(bEid, addressToBytes32(address(messengerB)));

        skip(3 days);
        /// Bridge 50% to chain B
        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam = SendParam(
            bEid, // Destination ID
            addressToBytes32(address(this)),
            5000e18,
            5000e18,
            options,
            "",
            ""
        );
        MessagingFee memory fee = stTBYA.quoteSend(sendParam, false);

        stTBYA.send{value: fee.nativeFee}(
            sendParam,
            fee,
            payable(address(this))
        );
        verifyPackets(bEid, addressToBytes32(address(stTBYB)));

        /// Update rates to simulate adding yield to the system
        pool.mint(address(stTBYA), 10000e6);

        swap.setRate(1.1e18);
        registry.setExchangeRate(address(pool), 1.1e18);

        // Value should be accrued evenly throughout the system due to the rate change
        ILayerZeroSettings.LzSettings memory settings2 = _generateSettings(
            messengerB,
            Operation.Poke,
            l2BridgeEmpty
        );
        stTBYA.poke{value: 1e18}(settings2);
        verifyPackets(aEid, addressToBytes32(address(stTBYA)));
        verifyPackets(bEid, addressToBytes32(address(messengerB)));

        assertEq(stTBYA.getSupplyIndex(), 5e17); // Supply Index should be 50% and unchanged by yield
        assertEq(stTBYA.getSupplyIndex(), 5e17); // Supply Index should be 50% and unchanged by yield
        assertEq(stTBYA.getTotalUsd(), 5500e18);
        assertEq(stTBYB.getTotalUsd(), 5500e18);
        assertEq(stTBYA.getTotalUsd() + stTBYB.getTotalUsd(), 11000e18);
    }

    function testWstTBYBridge() public {
        uint256 amount = 10000e6;
        usdc.mint(address(this), amount * 2);
        usdc.approve(address(stTBYA), amount);

        ILayerZeroSettings.LzSettings memory settings = _generateSettings(
            messengerB,
            Operation.Deposit,
            l2BridgeEmpty
        );

        (uint256 stTBYAmount, , ) = stTBYA.depositUnderlying{value: 1e18}(
            amount,
            settings
        );
        verifyPackets(aEid, addressToBytes32(address(stTBYA)));
        verifyPackets(bEid, addressToBytes32(address(messengerB)));

        stTBYA.approve(address(wstTBYA), stTBYAmount);

        uint256 wrapAmount = wstTBYA.wrap(stTBYAmount);
        uint256 transferAmount = wrapAmount / 2;

        wstTBYA.approve(address(wstTBYBridgeA), wrapAmount);

        /// Bridge 50% to chain B
        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(20000000, 0)
            .addExecutorLzComposeOption(0, 50000000, 0);

        SendParam memory sendParam = SendParam(
            bEid, // Destination ID
            addressToBytes32(address(this)),
            transferAmount,
            transferAmount,
            options,
            abi.encode(address(this), transferAmount),
            ""
        );
        MessagingFee memory fee = stTBYA.quoteSend(sendParam, false);

        settings.bridgeSettings.fee.nativeFee = fee.nativeFee;

        BridgeOptions memory l2Bridge = BridgeOptions({
            sendParam: sendParam,
            fee: fee
        });

        settings = _generateSettings(messengerB, Operation.Deposit, l2Bridge);

        ILayerZeroSettings.LzBridgeReceipt memory receipt = wstTBYBridgeA
            .bridgeWstTBY{value: settings.bridgeSettings.fee.nativeFee}(
            address(this),
            transferAmount,
            bEid,
            settings
        );
        verifyPackets(bEid, addressToBytes32(address(stTBYB)));
        verifyPackets(bEid, addressToBytes32(address(wstTBYBridgeB)));

        uint32 dstEid_ = bEid;
        address from_ = address(stTBYB);
        bytes memory options_ = options;
        bytes32 guid_ = receipt.msgReceipt.guid;
        address to_ = address(wstTBYBridgeB);
        bytes memory composerMsg_ = OFTComposeMsgCodec.encode(
            receipt.msgReceipt.nonce,
            aEid,
            receipt.oftReceipt.amountReceivedLD,
            abi.encodePacked(
                addressToBytes32(address(wstTBYBridgeA)),
                abi.encode(address(this), transferAmount)
            )
        );

        vm.startPrank(endpoints[bEid]);
        this.lzCompose(dstEid_, from_, options_, guid_, to_, composerMsg_);

        assertEq(wstTBYA.balanceOf(address(this)), transferAmount);
        assertEq(wstTBYB.balanceOf(address(this)), transferAmount);

        /// Approx equal due to fees
        assertApproxEqRel(stTBYA.getSupplyIndex(), 5e17, 1e15);
        assertApproxEqRel(stTBYB.getSupplyIndex(), 5e17, 1e15);
    }
}
