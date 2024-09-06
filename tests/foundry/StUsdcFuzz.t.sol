// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {FixedPointMathLib as FpMath} from "solady/utils/FixedPointMathLib.sol";

import {StakeUpErrors as Errors} from "src/helpers/StakeUpErrors.sol";
import {StUsdcSetup} from "./StUsdcSetup.t.sol";
import {IStUsdc} from "src/interfaces/IStUsdc.sol";

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
        assertApproxEqRel(stUsdc.balanceOf(alice), accruedValue, .9999999e18);
        assertApproxEqRel(stUsdc.balanceOf(alice), stUsdc.totalUsd(), .9999999e18);
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

        // Poke the contract to rebase and accrue value
        stUsdc.poke();
        uint256 sharesFeeAmount = stUsdc.sharesByUsd(performanceFeeScaled);

        // Market maker should complete the swap
        _bloomEndTby(id, (totalCollateral * tbyRate).mulWad(SCALER));

        // Harvest the matured TBY
        vm.startPrank(marketMaker);
        stUsdc.harvest();

        // Validate that the performance fee was correctly captured.
        assertApproxEqRel(stUsdc.sharesOf(address(staking)), sharesFeeAmount, .9999999e18);
        assertApproxEqRel(stUsdc.totalUsd(), stableToken.balanceOf(address(stUsdc)) * SCALER, .9999999e18);
        assertGe(stUsdc.totalUsd(), stableToken.balanceOf(address(stUsdc)));
    }

    function _depositAsset(address user, uint256 amount) internal returns (uint256) {
        vm.startPrank(user);
        // Mint and approve stableToken
        stableToken.mint(user, amount);
        stableToken.approve(address(stUsdc), amount);

        // Deposit asset into stUsdc
        return stUsdc.depositAsset(amount);
    }

    function _matchBloomOrder(address user, uint256 amount) internal returns (uint256) {
        vm.startPrank(borrower);
        uint256 neededAmount = amount.divWad(bloomPool.leverage());
        stableToken.mint(borrower, neededAmount);
        stableToken.approve(address(bloomPool), neededAmount);
        bloomPool.fillOrder(user, amount);
        return amount + neededAmount;
    }

    function _bloomStartNewTby(uint256 stableAmount) internal returns (uint256 id) {
        (, int256 answer,,,) = priceFeed.latestRoundData();
        uint256 answerScaled = uint256(answer) * (10 ** (18 - priceFeed.decimals()));
        uint256 rwaAmount = (stableAmount * (10 ** (18 - stableToken.decimals()))).divWadUp(answerScaled);

        vm.startPrank(marketMaker);
        billToken.mint(marketMaker, rwaAmount);
        billToken.approve(address(bloomPool), rwaAmount);
        (id,) = bloomPool.swapIn(bloomLenders, stableAmount);
    }

    function _bloomEndTby(uint256 id, uint256 stableAmount) internal {
        (, int256 answer,,,) = priceFeed.latestRoundData();
        uint256 answerScaled = uint256(answer) * (10 ** (18 - priceFeed.decimals()));
        uint256 rwaAmount = (stableAmount * (10 ** (18 - stableToken.decimals()))).divWadUp(answerScaled);

        vm.startPrank(marketMaker);
        stableToken.mint(marketMaker, stableAmount);
        stableToken.approve(address(bloomPool), stableAmount);
        bloomPool.swapOut(id, rwaAmount);
    }

    function _redeemStUsdc(address user, uint256 amount) internal returns (uint256) {
        vm.startPrank(user);
        return stUsdc.redeemStUsdc(amount);
    }

    function _skipAndUpdatePrice(uint256 time, uint256 price, uint80 roundId) internal {
        vm.startPrank(owner);
        skip(time);
        priceFeed.setLatestRoundData(roundId, int256(price), block.timestamp, block.timestamp, roundId);
        vm.stopPrank();
    }
}
