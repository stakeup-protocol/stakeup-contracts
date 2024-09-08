// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {FixedPointMathLib as FpMath} from "solady/utils/FixedPointMathLib.sol";

import {StakeUpErrors as Errors} from "src/helpers/StakeUpErrors.sol";
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

        // Validate that the user received mint rewards if they deposited 200M or less
        uint256 expectedSup = (amount < 200_000_000e6) ? amount : 200_000_000e6;
        assertGt(supToken.balanceOf(alice), expectedSup);

        // Validate that stUsdc created a lend order in the bloomPool
        assertEq(bloomPool.amountOpen(address(stUsdc)), amount);
    }

    function testFuzzDepositTby(uint256 amount) public {
        amount = bound(amount, 10e6, 100_000_000_000e6);

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
        _skipAndUpdatePrice(30 days, 115e8, 2);

        assertEq(tby.balanceOf(alice, id), amount);

        vm.startPrank(alice);
        tby.setApprovalForAll(address(stUsdc), true);
        // Use TBYs to mint stUsdc
        stUsdc.depositTby(id, amount);

        // The TBY has accrued value so the user should have received more stUSDC than their amount of TBYs
        uint256 expectedStUsdc = amount.mulWad(bloomPool.getRate(id)) * SCALER;
        assertEq(stUsdc.balanceOf(alice), expectedStUsdc);

        // Validate that the user received mint rewards if they deposited 200M or less
        uint256 expectedSup = (expectedStUsdc < 200_000_000e18) ? expectedStUsdc : 200_000_000e18;
        assertEq(supToken.balanceOf(alice), expectedSup);
    }

    function testFuzzRedeemOpenOrder(uint256 amount) public {
        amount = bound(amount, 1, 100_000_000_000e6);

        // use up all mint rewards
        _depositAsset(rando, 200_000_000e6);
        _redeemStUsdc(rando, 200_000_000e18);

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

        // use up all mint rewards
        _depositAsset(rando, 200_000_000e6);
        _redeemStUsdc(rando, 200_000_000e18);

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

        // use up all mint rewards
        _depositAsset(rando, 200_000_000e6);
        _redeemStUsdc(rando, 200_000_000e18);

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

        _depositAsset(alice, amount);

        // Run through the bloom lifecycle
        uint256 totalCollateral = _matchBloomOrder(address(stUsdc), amount);
        uint256 id = _bloomStartNewTby(totalCollateral);

        // Skip to a new price
        _skipAndUpdatePrice(30 days, 111e8, 2);
        uint256 tbyRate = bloomPool.getRate(id);

        uint256 accruedValue = amount.mulWad(tbyRate) * SCALER;

        // Poke the contract to rebase and accrue value
        stUsdc.poke();

        // Validate that the accrued value is correct
        assertApproxEqRel(stUsdc.balanceOf(alice), accruedValue, 0.9999999e18);
        assertApproxEqRel(stUsdc.balanceOf(alice), stUsdc.totalUsd(), 0.9999999e18);

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
        uint256 accruedValue = amount.mulWad(tbyRate);
        uint256 yield = accruedValue - amount;
        uint256 performanceFee = yield.divWad(10e18);
        uint256 performanceFeeScaled = performanceFee * SCALER;

        // Market maker should complete the swap
        _bloomEndTby(id, (totalCollateral * tbyRate).mulWad(SCALER));

        // Poke the contract to rebase and accrue value & harvest the matured TBY
        stUsdc.poke();
        uint256 sharesFeeAmount = stUsdc.sharesByUsd(performanceFeeScaled);

        // Validate that the performance fee was correctly captured.
        assertApproxEqRel(stUsdc.sharesOf(address(staking)), sharesFeeAmount, 0.9999999e18);
        assertApproxEqRel(stUsdc.totalUsd(), stableToken.balanceOf(address(stUsdc)) * SCALER, 0.9999999e18);
        assertGe(stUsdc.totalUsd(), stableToken.balanceOf(address(stUsdc)));

        // Validate that the last redeemed TBY ID state variable is updated
        assertEq(stUsdc.lastRedeemedTbyId(), id);
    }

    function testFullFlow(uint256 amount) public {
        amount = bound(amount, 10e6, 100_000_000_000e6);

        _depositAsset(rando, 200_000_000e6);
        _redeemStUsdc(rando, 200_000_000e6);

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
        stUsdc.poke();

        // Withdraw USDC
        uint256 stUsdcAmount = stUsdc.balanceOf(alice);

        vm.startPrank(alice);
        stUsdc.redeemStUsdc(stUsdcAmount);

        assertEq(stUsdc.balanceOf(alice), 0);
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
        stUsdc.poke();

        // Validate that the accrued value is correct
        assertEq(stableToken.balanceOf(address(stUsdc)), 0);
        assertEq(bloomPool.amountOpen(address(stUsdc)), totalDeposits);
        assertEq(stUsdc.totalUsd(), totalDeposits * SCALER);

        // Validate that the last rate update state variable updated properly
        assertEq(stUsdc.lastRateUpdate(), block.timestamp);
    }
}
