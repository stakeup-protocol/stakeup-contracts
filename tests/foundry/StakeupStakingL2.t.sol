// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {Test} from "forge-std/Test.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {StakeupStaking, IStakeupStaking} from "src/staking/StakeupStaking.sol";
import {StakeupStakingL2} from "src/staking/StakeupStakingL2.sol";
import {LayerZeroEndpointV2Mock} from "../mocks/LayerZero/LayerZeroEndpointV2Mock.sol";
import {StTBY} from "src/token/StTBY.sol";
import {StakeupToken} from "src/token/StakeupToken.sol";
import {LibRLP} from "solady/utils/LibRLP.sol";
import {MockBloomPool, IBloomPool} from "../mocks/MockBloomPool.sol";
import {MockBloomFactory} from "../mocks/MockBloomFactory.sol";

import {ISUPVesting} from "src/interfaces/ISUPVesting.sol";
import {OFTComposeMsgCodec} from "@LayerZero/oft/libs/OFTComposeMsgCodec.sol";
import { TestHelper } from "@LayerZeroTesting/TestHelper.sol";

import {MockERC20} from "../mocks/MockERC20.sol";
import "forge-std/Console2.sol";
contract StakeupStakingL2Test is TestHelper {
    using FixedPointMathLib for uint256;
    using OFTComposeMsgCodec for address;
    MockERC20 internal usdc;

    StTBY internal stTBYA;
    StTBY internal stTBYB;

    StakeupToken internal supA;
    StakeupToken internal supB;

    StakeupStaking internal stakeupStaking;
    StakeupStakingL2 internal stakeupStakingL2;

    LayerZeroEndpointV2Mock internal layerZeroEndpointA;
    LayerZeroEndpointV2Mock internal layerZeroEndpointB;

    uint32 aEid = 1;
    uint32 bEid = 2;

    function setUp() public {
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
            address(expectedstTBYAddress)
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

        assertEq(address(supA), expectedSupAAddress);
        assertEq(address(stTBYA), expectedstTBYAddress);

        address expectedSupBAddress = LibRLP.computeAddress(address(this), vm.getNonce(address(this)) + 1);
        address expectedstTBYBAddress = LibRLP.computeAddress(address(this), vm.getNonce(address(this)) + 2);

        stakeupStakingL2 = new StakeupStakingL2(
            address(expectedSupBAddress),
            address(expectedstTBYBAddress),
            address(stakeupStaking),
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
        address[] memory oapps = new address[](5);
        oapps[0] = address(supA);
        oapps[1] = address(supB);
        oapps[2] = address(stTBYA);
        oapps[3] = address(stTBYB);
        oapps[4] = address(stakeupStakingL2);
        this.wireOApps(oapps);
    }

    function testProcessFees() public {
        uint256 amount = 10000e6;
        usdc.mint(address(this), amount * 2);

        usdc.approve(address(stTBYA), amount);
        usdc.approve(address(stTBYB), amount);
        
        uint256 initialRewardBlock = stakeupStaking.getLastRewardBlock();
        
        vm.roll(10);

        //stTBYA.depositUnderlying(amount);
        stTBYB.depositUnderlying(amount);

        assertGt(stTBYA.balanceOf(address(this)), 0);

        // When fees are processed on chain B they will be bridged to chain A and the reward state should update
        uint256 balance = stTBYA.balanceOf(address(stakeupStaking));
        assertGt(balance, 0);
        assertEq(stakeupStaking.getLastRewardBlock(), 10);
    }
}