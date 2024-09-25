// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {Test} from "forge-std/Test.sol";
import {FixedPointMathLib as FpMath} from "solady/utils/FixedPointMathLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {StakeUpErrors as Errors} from "src/helpers/StakeUpErrors.sol";
import {StakeUpConstants as Constants} from "src/helpers/StakeUpConstants.sol";

import {IStUsdc} from "src/interfaces/IStUsdc.sol";
import {IStUsdcLite} from "src/interfaces/IStUsdcLite.sol";

import {StUsdc} from "src/token/StUsdc.sol";
import {StUsdcSetup} from "../StUsdcSetup.t.sol";

contract StUsdcUnitTest is StUsdcSetup {
    using FpMath for uint256;

    function setUp() public override {
        super.setUp();
    }

    function test_deploymentState() public {
        assertEq(address(stUsdc.asset()), address(stableToken));
        assertEq(address(stUsdc.bloomPool()), address(bloomPool));
        assertEq(address(stUsdc.stakeUpStaking()), address(staking));
        assertEq(address(stUsdc.wstUsdc()), address(wstUsdc));
        assertEq(address(stUsdc.owner()), address(owner));
        assertEq(address(stUsdc.stakeUpToken()), address(supToken));
        assertEq(stUsdc.performanceBps(), Constants.PERFORMANCE_BPS);
    }

    function test_deployWithInvalidAsset() public {
        vm.expectRevert(Errors.ZeroAddress.selector);
        new StUsdc(address(0), address(bloomPool), address(staking), address(wstUsdc), endpoints[1], address(owner));
    }

    function test_depositOfAlreadyRedeemedTby() public {
        // Go through whole bloom flow
        uint256 amount = 100e6;
        _depositAsset(alice, amount);
        uint256 totalCollateral = _matchBloomOrder(address(stUsdc), amount);

        vm.startPrank(alice);
        stableToken.mint(alice, amount);
        stableToken.approve(address(bloomPool), amount);
        bloomPool.lendOrder(amount);
        bloomLenders.push(alice);

        // Start new TBY
        uint256 id = _bloomStartNewTby(totalCollateral);
        // Fast Forward to end of TBY maturity
        uint256 endPrice = uint256(110e8).mulWad(1.025e18);
        _skipAndUpdatePrice(180 days, endPrice, 2);
        // Market Maker makes the final swap
        _bloomEndTby(id, (totalCollateral * endPrice).mulWad(SCALER));

        // Update rate and harvest the matured TBY
        stUsdc.poke();

        // try to deposit the same TBY that was redeemed
        vm.expectRevert(Errors.RedeemableTbyNotAllowed.selector);
        stUsdc.depositTby(id, amount);
    }

    function test_mintRewardMechanics() public {
        // Set spread to 1e18 & price to 100e8 to validate math easily
        vm.prank(owner);
        bloomPool.setSpread(1e18);

        _skipAndUpdatePrice(1 days, 100e8, 2);

        // lend into the bloom pool
        vm.startPrank(alice);
        stableToken.mint(alice, 100e6);
        stableToken.approve(address(bloomPool), 100e6);
        bloomPool.lendOrder(100e6);
        bloomLenders.push(alice);

        uint256 totalCollateral = 100e6;
        totalCollateral += _matchBloomOrder(alice, 100e6);
        // start a new TBY
        uint256 id = _bloomStartNewTby(totalCollateral);

        vm.startPrank(alice);
        tby.setApprovalForAll(address(stUsdc), true);

        // Deposit 25% of the TBY immediately & validate receiveing 100% of deposit mint rewards
        stUsdc.depositTby(id, 25e6);
        assertEq(supToken.balanceOf(alice), 25e18);

        // Deposit 25% of TBYs halfway through its maturity
        _skipAndUpdatePrice(90 days, 105e8, 2);

        uint256 expectedHalfWayBalance = 25e18 + ((25e18 * 1.05e18) / 2e18);
        vm.prank(alice);
        stUsdc.depositTby(id, 25e6);
        assertEq(supToken.balanceOf(alice), expectedHalfWayBalance);

        // Deposit 50% of TBYs at maturity & receive 0 mint rewards
        _skipAndUpdatePrice(180 days, 115e8, 3);
        vm.prank(alice);
        stUsdc.depositTby(id, 50e6);
        assertEq(supToken.balanceOf(alice), expectedHalfWayBalance);
    }

    /// StUsdcLite Unit Tests
    function test_setUsdPerShareNonRelayer() public {
        vm.startPrank(rando);
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        stUsdc.setUsdPerShare(1e18);
    }

    function test_transfer() public {
        _depositAsset(alice, 100e6);

        // Rando cannot transfer alice's tokens
        vm.startPrank(rando);
        vm.expectRevert();
        stUsdc.transferFrom(alice, bob, 100e6);

        // Alice can transfer her tokens to Bob
        vm.startPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(alice, bob, 50e18);
        stUsdc.transfer(bob, 50e18);

        assertEq(stUsdc.balanceOf(bob), 50e18);
        assertEq(stUsdc.balanceOf(alice), 50e18);
    }

    function test_transferShares() public {
        _depositAsset(alice, 100e6);

        // Rando cannot transfer alice's tokens
        vm.startPrank(rando);
        vm.expectRevert();
        stUsdc.transferSharesFrom(alice, bob, 50e18);

        // Alice can transfer her tokens to Bob
        vm.startPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit IStUsdcLite.TransferShares(alice, bob, 50e18);
        stUsdc.transferShares(bob, 50e18);

        assertEq(stUsdc.sharesOf(bob), 50e18);
        assertEq(stUsdc.sharesOf(alice), 50e18);
    }
}
