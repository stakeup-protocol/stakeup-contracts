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
import {MockBPSFeed} from "../mocks/MockBPSFeed.sol";

import {StakeUpStaking, IStakeUpStaking} from "src/staking/StakeUpStaking.sol";
import {StTBY} from "src/token/StTBY.sol";
import {StTBYBase} from "src/token/StTBYBase.sol";
import {StakeUpToken} from "src/token/StakeUpToken.sol";
import {WstTBY} from "src/token/WstTBY.sol";
import {WstTBYBase} from "src/token/WstTBYBase.sol";
import {WstTBYBridge} from "src/messaging/WstTBYBridge.sol";

import {ILayerZeroSettings} from "src/interfaces/ILayerZeroSettings.sol";
import {IBloomPool} from "src/interfaces/bloom/IBloomPool.sol";

contract CrossChainTest is TestHelper {
    using FixedPointMathLib for uint256;
    using OFTComposeMsgCodec for address;
    using OptionsBuilder for bytes;

    MockERC20 internal usdc;

    StTBY internal stTBYA;
    StTBYBase internal stTBYB;

    StakeUpToken internal supA;

    StakeUpStaking internal stakeupStaking;

    WstTBY internal wstTBYA;
    WstTBYBridge internal wstTBYBridgeA;
    WstTBYBase internal wstTBYB;
    WstTBYBridge internal wstTBYBridgeB;

    MockRegistry internal registry;
    MockBloomPool internal pool;
    MockSwapFacility internal swap;
    MockBloomFactory internal bloomFactory;
    MockBPSFeed internal bpsFeed;

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

            stakeupStaking = new StakeUpStaking(
                address(expectedSupAAddress),
                address(expectedstTBYAddress)
            );

            supA = new StakeUpToken(
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
                address(bpsFeed),
                expectedWstTBYAAddress,
                address(endpoints[aEid]),
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
            address expectedMessengerAddress = LibRLP.computeAddress(
                address(this),
                vm.getNonce(address(this)) + 1
            );

            stTBYB = new StTBYBase(address(endpoints[bEid]), address(this));

            wstTBYB = new WstTBYBase(address(stTBYB));

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

        stTBYA.depositUnderlying(amount);

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

    function testGlobalShares() public {
        uint256 amount = 10000e6;
        usdc.mint(address(this), amount * 2);
        usdc.approve(address(stTBYA), amount);

        stTBYA.depositUnderlying(amount);

        assertEq(stTBYA.getGlobalShares(), 10000e18);
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

        skip(1 days);
        stTBYA.poke();

        assertEq(stTBYA.getGlobalShares(), 10000e18);
    }

    function testYieldDistribution() public {
        uint256 amount = 10000e6;
        usdc.mint(address(this), amount * 2);
        usdc.approve(address(stTBYA), amount);

        stTBYA.depositUnderlying(amount);

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

        skip(1 days);

        stTBYA.poke();
        verifyPackets(aEid, addressToBytes32(address(stTBYA)));

        assertEq(stTBYA.getTotalUsd(), 5500e18);
        assertEq(stTBYB.getTotalUsd(), 5500e18);
        assertEq(stTBYA.getTotalUsd() + stTBYB.getTotalUsd(), 11000e18);
    }

    function testWstTBYBridge() public {
        uint256 amount = 10000e6;
        usdc.mint(address(this), amount * 2);
        usdc.approve(address(stTBYA), amount);

        uint256 stTBYAmount = stTBYA.depositUnderlying(amount);

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

        bytes memory msgOptions = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(200000, 0);

        ILayerZeroSettings.LzSettings memory settings = ILayerZeroSettings
            .LzSettings({
                options: msgOptions,
                fee: MessagingFee({nativeFee: 300000, lzTokenFee: 0}),
                refundRecipient: msg.sender
            });

        ILayerZeroSettings.LzBridgeReceipt memory receipt = wstTBYBridgeA
            .bridgeWstTBY{value: settings.fee.nativeFee}(
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

        skip(1 days);
        stTBYA.poke();
    }
}
