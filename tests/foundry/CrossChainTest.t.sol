// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {Test} from "forge-std/Test.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {LibRLP} from "solady/utils/LibRLP.sol";
import {OptionsBuilder} from "@LayerZero/oapp/libs/OptionsBuilder.sol";
import {OFTComposeMsgCodec} from "@LayerZero/oft/libs/OFTComposeMsgCodec.sol";
import { TestHelper } from "@LayerZeroTesting/TestHelper.sol";
import { MessagingFee, SendParam } from "@LayerZero/oft/interfaces/IOFT.sol";

import {MockBloomPool} from "../mocks/MockBloomPool.sol";
import {MockBloomFactory} from "../mocks/MockBloomFactory.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

import {StakeupStaking, IStakeupStaking} from "src/staking/StakeupStaking.sol";
import {StakeupStakingL2} from "src/staking/StakeupStakingL2.sol";
import {StTBY} from "src/token/StTBY.sol";
import {StakeupToken} from "src/token/StakeupToken.sol";
import {ILzBridgeConfig} from "src/interfaces/ILzBridgeConfig.sol";

contract CrossChainTest is TestHelper {
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

    uint32 aEid = 1;
    uint32 bEid = 2;

    function setUp() public virtual override {
        usdc = new MockERC20(6);
        MockERC20 bill = new MockERC20(18);

        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        MockBloomFactory bloomFactory = new MockBloomFactory();
        address registry = makeAddr("registry");
        address wstTBY = makeAddr("wstTBY");
        address swap = makeAddr("swap");

        MockBloomPool pool = new MockBloomPool(
            address(usdc),
            address(bill),
            address(swap),
            6
        );

        bloomFactory.setLastCreatedPool(address(pool));

        address expectedSupAAddress = LibRLP.computeAddress(address(this), vm.getNonce(address(this)) + 1);
        address expectedstTBYAddress = LibRLP.computeAddress(address(this), vm.getNonce(address(this)) + 2);

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
            1,
            0,
            0,
            wstTBY,
            false,
            address(endpoints[aEid]),
            address(this)
        );

        address expectedSupBAddress = LibRLP.computeAddress(address(this), vm.getNonce(address(this)) + 1);
        address expectedstTBYBAddress = LibRLP.computeAddress(address(this), vm.getNonce(address(this)) + 2);

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
            1,
            0,
            0,
            wstTBY,
            false,
            address(endpoints[bEid]),
            address(this)
        );

        // config and wire the oapps
        address[] memory stTBYs = new address[](2);
        stTBYs[0] = address(stTBYA);
        stTBYs[1] = address(stTBYB);
        this.wireOApps(stTBYs);

        address[] memory sups = new address[](2);
        sups[0] = address(supA);
        sups[1] = address(supA);
        this.wireOApps(sups);
    }

    function testBridge() public {
        uint256 amount = 10000e6;
        usdc.mint(address(this), amount * 2);
        usdc.approve(address(stTBYA), amount);
        ILzBridgeConfig.LZBridgeSettings memory settings = ILzBridgeConfig.LZBridgeSettings({
            options: "",
            fee: MessagingFee({
                nativeFee: 0,
                lzTokenFee: 0
            })
        });
        stTBYA.depositUnderlying{value: 100000010526}(amount, settings);
        
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

        stTBYA.send{ value: fee.nativeFee }(sendParam, fee, payable(address(this)));
        verifyPackets(bEid, addressToBytes32(address(stTBYB)));

        assertEq(stTBYA.balanceOf(address(this)), initialBalanceA - tokensToSend);
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

        ILzBridgeConfig.LZBridgeSettings memory settings = ILzBridgeConfig.LZBridgeSettings({
            options: options,
            fee: MessagingFee({
                nativeFee: fee.nativeFee,
                lzTokenFee: fee.lzTokenFee
            })
        });

        (ILzBridgeConfig.LzBridgeReceipt memory receipt) = stTBYB.depositUnderlying{value: fee.nativeFee}(amount, settings);
        verifyPackets(aEid, addressToBytes32(address(stTBYA)));
        
        uint32 dstEid_ = aEid;
        address from_ = address(stTBYA);
        bytes memory options_ = options;
        bytes32 guid_ = receipt.msgReceipt.guid;
        address to_ = address(stakeupStaking);
        bytes memory composerMsg_ = OFTComposeMsgCodec.encode(
            receipt.msgReceipt.nonce,
            bEid,
            receipt.oftReceipt.amountReceivedLD,
            abi.encodePacked(addressToBytes32(address(stakeupStakingL2)), stakeupStakingL2.PROCESS_FEE_MSG())
        );

        vm.startPrank(endpoints[aEid]);
        this.lzCompose(dstEid_, from_, options_, guid_, to_, composerMsg_);

        assertGt(stTBYB.balanceOf(address(this)), 0);

        // When fees are processed on chain B they will be bridged to chain A and the reward state should update
        uint256 balance = stTBYA.balanceOf(address(stakeupStaking));
        assertGt(balance, 0);
        assertGt(stakeupStaking.getLastRewardBlock(), initialRewardBlock);
    }
}