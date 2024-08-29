// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";
import {LibRLP} from "solady/utils/LibRLP.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

import {StakeUpErrors as Errors} from "src/helpers/StakeUpErrors.sol";

import {StTBY} from "src/token/StTBY.sol";
import {WstTBY} from "src/token/WstTBY.sol";
import {StakeUpStaking} from "src/staking/StakeUpStaking.sol";

import {IStTBY} from "src/interfaces/IStTBY.sol";
import {ILayerZeroSettings} from "src/interfaces/ILayerZeroSettings.sol";

import {StTBYSetup} from "./StTBYSetup.t.sol";
import {MockEndpoint} from "../mocks/MockEndpoint.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockSwapFacility} from "../mocks/MockSwapFacility.sol";
import {MockBloomPool, IBloomPool} from "../mocks/MockBloomPool.sol";
import {MockBloomFactory} from "../mocks/MockBloomFactory.sol";
import {MockEmergencyHandler} from "../mocks/MockEmergencyHandler.sol";
import {MockRegistry} from "../mocks/MockRegistry.sol";

contract WstTBYTest is StTBYSetup {
    function setUp() public override {
        super.setUp();
    }

    function test_wrapAndUnwrap() public {
        uint256 stableAmount = 100e6;
        vm.startPrank(alice);

        /// Mint stTBY
        stableToken.mint(alice, stableAmount);
        stableToken.approve(address(stTBY), stableAmount);
        uint256 stTBYAmount = stTBY.depositUnderlying(stableAmount);

        // Wrap
        stTBY.approve(address(wstTBY), stTBYAmount);
        wstTBY.wrap(stTBYAmount);
        assertEq(wstTBY.balanceOf(alice), stTBY.getSharesByUsd(stTBYAmount));

        // Unwrap
        wstTBY.unwrap(wstTBY.balanceOf(alice));
        assertEq(wstTBY.balanceOf(alice), 0);
        assertEq(stTBY.balanceOf(alice), stTBYAmount);
    }

    function test_mintWstTBY() public {
        uint256 depositAmount = 50e6;
        uint256 expectedMintAmount = depositAmount * 1e12;

        /// Mint Stable and pool tokens
        stableToken.mint(alice, depositAmount);
        pool.mint(bob, depositAmount);
        pool.setCommitPhaseEnd(block.timestamp + 25 hours);
        registry.setTokenInfos(true);
        registry.setExchangeRate(address(pool), 1e18);
        bpsFeed.updateRate(1e4);

        // Mint wstTBY using stable token
        vm.startPrank(alice);
        stableToken.approve(address(wstTBY), depositAmount);
        wstTBY.depositUnderlying(depositAmount);

        assertEq(stTBY.balanceOf(alice), 0);
        assertEq(wstTBY.balanceOf(alice), stTBY.getSharesByUsd(expectedMintAmount));

        vm.stopPrank();

        pool.setState(IBloomPool.State.ReadyPreHoldSwap);

        // Mint wstTBY using pool token
        vm.startPrank(bob);
        pool.approve(address(wstTBY), depositAmount);
        wstTBY.depositTby(address(pool), depositAmount);

        assertEq(stTBY.balanceOf(bob), 0);
        assertEq(wstTBY.balanceOf(bob), stTBY.getSharesByUsd(expectedMintAmount));
    }
}
