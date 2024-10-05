// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {Test} from "forge-std/Test.sol";
import {FixedPointMathLib as FpMath} from "solady/utils/FixedPointMathLib.sol";

import {StakeUpErrors as Errors} from "src/helpers/StakeUpErrors.sol";
import {StakeUpConstants as Constants} from "src/helpers/StakeUpConstants.sol";

import {IStUsdc} from "src/interfaces/IStUsdc.sol";
import {StUsdcSetup} from "../StUsdcSetup.t.sol";

contract StUsdcFuzzTest is StUsdcSetup {
    using FpMath for uint256;

    function setUp() public override {
        super.setUp();
    }

    function testFuzzDepositAsset(uint256 amount) public {
        amount = bound(amount, 1, 100_000_000_000e6);

        vm.startPrank(alice);
        // Mint and approve stableToken
        stableToken.mint(alice, amount);
        stableToken.approve(address(stUsdc), amount);

        // Deposit asset into stUsdc
        vm.expectEmit(true, true, true, true);
        emit IStUsdc.AssetDeposited(alice, amount);
        uint256 amountReceived = stUsdc.depositAsset(amount);

        uint256 expectedAmountReceived = amount * SCALER;
        assertEq(amountReceived, expectedAmountReceived);

        // Validate invariants
        assertEq(stUsdc.balanceOf(alice), expectedAmountReceived);
        assertEq(stUsdc.totalSupply(), expectedAmountReceived);
        assertEq(stUsdc.totalUsd(), expectedAmountReceived);
        assertEq(stUsdc.totalShares(), expectedAmountReceived);
        assertEq(stUsdc.globalShares(), expectedAmountReceived);

        // Validate that the user received no mint rewards
        assertEq(supToken.balanceOf(alice), 0);

        // Validate that stUsdc created a lend order in the bloomPool
        assertEq(bloomPool.amountOpen(address(stUsdc)), amount);
    }

    function testFuzzDepositTby(uint256 amount) public {
        amount = bound(amount, 10e6, 100_000_000_000e6);
        vm.assume(amount % 2 == 0);

        vm.startPrank(alice);
        // Mint and approve stableToken
        stableToken.mint(alice, amount);
        stableToken.approve(address(bloomPool), amount);

        // Open a lend order directly in the bloomPool
        bloomPool.lendOrder(amount);

        // Run through the bloom lifecycle
        uint256 totalCollateral = _matchBloomOrder(alice, amount);

        // Market maker swap for alice's matched order
        (, int256 answer,,,) = priceFeed.latestRoundData();
        uint256 answerScaled = uint256(answer) * (10 ** (18 - priceFeed.decimals()));
        uint256 rwaAmount = (totalCollateral * (10 ** (18 - stableToken.decimals()))).divWadUp(answerScaled);

        vm.startPrank(marketMaker);
        billToken.mint(marketMaker, rwaAmount);
        billToken.approve(address(bloomPool), rwaAmount);

        // Edit the lenders array to only include alice
        bloomLenders[0] = alice;
        // mint TBY to alice
        (uint256 id,) = bloomPool.swapIn(bloomLenders, totalCollateral);
        // Skip to a new price
        _skipAndUpdatePrice(90 days, 115e8, 2);

        assertEq(tby.balanceOf(alice, id), amount);

        vm.startPrank(alice);
        tby.setApprovalForAll(address(stUsdc), true);
        // Use TBYs to mint stUsdc
        stUsdc.depositTby(id, amount);

        // The TBY has accrued value so the user should have received more stUSDC than their amount of TBYs
        uint256 adjustedRate =
            FpMath.WAD + ((bloomPool.getRate(id) - FpMath.WAD).mulWad(90 days - Constants.ONE_DAY).divWad(90 days));
        uint256 expectedStUsdc = amount.mulWad(adjustedRate) * SCALER;
        assertEq(stUsdc.balanceOf(alice), expectedStUsdc);

        // Validate that the user received mint rewards if they deposited 200M or less
        // Since 50% of the TBYs maturity has passed, the user should have received 50% of the mint rewards
        uint256 scaledAmount = amount * SCALER;
        uint256 expectedSup = ((scaledAmount / 2) < 200_000_000e18) ? (scaledAmount / 2) : 200_000_000e18;
        assertEq(supToken.balanceOf(alice), expectedSup);
    }

    function testFuzzRedeemOpenOrder(uint256 amount) public {
        amount = bound(amount, 1, 100_000_000_000e6);

        // Alice deposits some asset
        uint256 amountReceived = _depositAsset(alice, amount);

        vm.startPrank(alice);
        // Withdraw asset from stUsdc
        vm.expectEmit(true, true, true, true);
        emit IStUsdc.Redeemed(alice, amountReceived, amount);
        stUsdc.redeemStUsdc(amountReceived);

        // Validate invariants
        assertEq(stUsdc.balanceOf(alice), 0);
        assertEq(stUsdc.totalSupply(), 0);
        assertEq(stUsdc.totalUsd(), 0);
        assertEq(stUsdc.totalShares(), 0);
        assertEq(stUsdc.globalShares(), 0);

        // Validate that stUsdc created a lend order in the bloomPool
        assertEq(bloomPool.amountOpen(address(stUsdc)), 0);
    }

    function testFuzzRedeemBlendedOrder(uint256 amount) public {
        amount = bound(amount, 10e6, 100_000_000_000e6);

        // Alice deposits some asset
        uint256 amountReceived = _depositAsset(alice, amount);

        // borrower matches alice's (deposited as stUsdc) order
        _matchBloomOrder(address(stUsdc), amount);

        // Verify the state of our testing setup
        assertEq(bloomPool.amountMatched(address(stUsdc)), amount);

        // Alice withdraws her asset
        vm.startPrank(alice);
        // Withdraw asset from stUsdc
        vm.expectEmit(true, true, true, true);
        emit IStUsdc.Redeemed(alice, amountReceived, amount);
        stUsdc.redeemStUsdc(amountReceived);

        // Validate invariants
        assertEq(stUsdc.balanceOf(alice), 0);
        assertEq(stUsdc.totalSupply(), 0);
        assertEq(stUsdc.totalUsd(), 0);
        assertEq(stUsdc.totalShares(), 0);
        assertEq(stUsdc.globalShares(), 0);

        // Validate that stUsdc created a lend order in the bloomPool
        assertEq(bloomPool.amountOpen(address(stUsdc)), 0);
        assertEq(bloomPool.amountMatched(address(stUsdc)), 0);
    }

    function testFuzzRedeemMatchedOrder(uint256 amount) public {
        amount = bound(amount, 10e6, 100_000_000_000e6);

        // Alice deposits some asset
        uint256 amountReceived = _depositAsset(alice, amount);

        // borrower matches half of alice's (deposited as stUsdc) order
        uint256 halfAmount = amount.divWad(2e18);
        _matchBloomOrder(address(stUsdc), halfAmount);

        // Verify the state of our testing setup
        assertEq(bloomPool.amountOpen(address(stUsdc)), amount - halfAmount);
        assertEq(bloomPool.amountMatched(address(stUsdc)), halfAmount);

        // Alice withdraws her asset
        vm.startPrank(alice);
        // Withdraw asset from stUsdc
        vm.expectEmit(true, true, true, true);
        emit IStUsdc.Redeemed(alice, amountReceived, amount);
        stUsdc.redeemStUsdc(amountReceived);

        // Validate invariants
        assertEq(stUsdc.balanceOf(alice), 0);
        assertEq(stUsdc.totalSupply(), 0);
        assertEq(stUsdc.totalUsd(), 0);
        assertEq(stUsdc.totalShares(), 0);
        assertEq(stUsdc.globalShares(), 0);

        // Validate that stUsdc created a lend order in the bloomPool
        assertEq(bloomPool.amountOpen(address(stUsdc)), 0);
        assertEq(bloomPool.amountMatched(address(stUsdc)), 0);
    }

    function testYieldAccrual(uint256 amount) public {
        amount = bound(amount, 10e6, 100_000_000_000e6);
        amount = 100e6;
        _depositAsset(alice, amount);

        // Run through the bloom lifecycle
        uint256 totalCollateral = _matchBloomOrder(address(stUsdc), amount);
        uint256 id = _bloomStartNewTby(totalCollateral);

        // Skip to a new price
        _skipAndUpdatePrice(30 days, 111e8, 2);
        uint256 tbyRate = bloomPool.getRate(id);

        uint256 accruedValue = amount.mulWad(tbyRate) * SCALER;
        uint256 performanceFee = (accruedValue - (amount * SCALER)).mulWad(0.1e18);
        uint256 expectedAliceAmount = accruedValue - performanceFee;

        // Poke the contract to rebase and accrue value
        stUsdc.poke(_generateSettings(address(0)));

        // skip 24hours for all yield to accrue
        _skipAndUpdatePrice(24 hours, 111e8, 2);
        stUsdc.poke(_generateSettings(address(0)));

        assertEq(stUsdc.totalUsd(), accruedValue);

        // Validate that the accrued value is correct & that the performance fee was correctly captured.
        assertApproxEqRel(stUsdc.balanceOf(alice), expectedAliceAmount, 0.000000001e18);
        assertApproxEqRel(stUsdc.balanceOf(address(staking)), performanceFee, 0.000000001e18);
        assertApproxEqRel(
            stUsdc.balanceOf(alice) + stUsdc.balanceOf(address(staking)), stUsdc.totalUsd(), 0.000000001e18
        );

        // Validate that the last rate update state variable updated properly
        assertEq(stUsdc.lastRateUpdate(), block.timestamp);
        // Validate that the last redeemed TBY ID state variable is still max uint256 since no TBYs have been redeemed
        assertEq(stUsdc.lastRedeemedTbyId(), type(uint256).max);
    }

    function testHarvest(uint256 amount) public {
        amount = bound(amount, 10e6, 100_000_000_000e6);

        _depositAsset(alice, amount);

        // Run through the bloom lifecycle
        uint256 totalCollateral = _matchBloomOrder(address(stUsdc), amount);
        uint256 id = _bloomStartNewTby(totalCollateral);

        // Skip to a new price
        _skipAndUpdatePrice(180 days, 115e8, 2);

        uint256 tbyRate = bloomPool.getRate(id);

        // Market maker should complete the swap
        _bloomEndTby(id, (totalCollateral * tbyRate).mulWad(SCALER));

        // Poke the contract to rebase and accrue value & harvest the matured TBY
        stUsdc.poke(_generateSettings(address(0)));
        _skipAndUpdatePrice(1 days, 115e8, 2);
        // Poke again to update yield distribution fully (Notethis will deposit idle usdc back into the pool)
        stUsdc.poke(_generateSettings(address(0)));

        assertApproxEqRel(stUsdc.totalUsd(), bloomPool.amountOpen(address(stUsdc)) * SCALER, 0.0000001e18);
        // Validate that the last redeemed TBY ID state variable is updated
        assertEq(stUsdc.lastRedeemedTbyId(), id);
    }

    function testFullFlow(uint256 amount) public {
        amount = bound(amount, 10e6, 100_000_000_000e6);

        _depositAsset(alice, amount);

        // Run through the bloom lifecycle
        uint256 totalCollateral = _matchBloomOrder(address(stUsdc), amount);
        uint256 id = _bloomStartNewTby(totalCollateral);

        // Fast Forward to end of TBY maturity
        uint256 endPrice = uint256(110e8).mulWad(1.025e18);
        _skipAndUpdatePrice(180 days, endPrice, 2);

        // Market Maker makes the final swap
        _bloomEndTby(id, (totalCollateral * endPrice).mulWad(SCALER));

        // Update rate and harvest the matured TBY
        stUsdc.poke(_generateSettings(address(0)));

        // Withdraw USDC
        uint256 stUsdcAmount = stUsdc.balanceOf(alice);

        vm.startPrank(alice);
        stUsdc.redeemStUsdc(stUsdcAmount);

        assertTrue(_isEqualWithDust(stUsdc.balanceOf(alice), 0));
        assertEq(stableToken.balanceOf(alice), stUsdcAmount / SCALER);
    }

    function testFuzzAutoLend(uint256 amount) public {
        amount = bound(amount, 10e6, 100_000_000_000e6);

        _depositAsset(alice, 1e6);
        // Donate some USDC to the stUSDC contract
        stableToken.mint(address(stUsdc), amount);
        uint256 totalDeposits = amount + 1e6;

        // Fast forward to end of TBY maturity
        _skipAndUpdatePrice(2 days, 110e8, 2);

        // Poke the contract to trigger the auto-lend feature.
        stUsdc.poke(_generateSettings(address(0)));
        _skipAndUpdatePrice(1 days, 110e8, 2);
        stUsdc.poke(_generateSettings(address(0)));

        // Validate that the accrued value is correct
        assertEq(stableToken.balanceOf(address(stUsdc)), 0);
        assertEq(bloomPool.amountOpen(address(stUsdc)), totalDeposits);
        assertTrue(_isEqualWithDust(totalDeposits * SCALER, stUsdc.totalUsd()));

        // Validate that the last rate update state variable updated properly
        assertEq(stUsdc.lastRateUpdate(), block.timestamp);
    }
}
