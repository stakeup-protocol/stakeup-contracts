// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {Test} from "forge-std/Test.sol";
import {LibRLP} from "solady/utils/LibRLP.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

import {MessagingHelpers} from "./MessagingHelpers.t.sol";
import {StakeUpMessenger} from "src/messaging/StakeUpMessenger.sol";
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

contract StTBYTest is StTBYSetup {
    // ============== Redefined Events ===============
    event Deposit(
        address indexed account,
        address tby,
        uint256 amount,
        uint256 shares
    );
    event Redeemed(address indexed account, uint256 shares, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);
    event TBYAutoMinted(address indexed account, uint256 amount);
    event RemainingBalanceAdjusted(uint256 amount);

    function setUp() public override {
        super.setUp();
    }

    function test_deposit_fail_with_TBYNotActive() public {
        ILayerZeroSettings.LzSettings memory settings = _generateSettings(
            messenger,
            Operation.Deposit
        );
        registry.setTokenInfos(false);
        vm.expectRevert(Errors.TBYNotActive.selector);
        vm.prank(alice);
        stTBY.depositTby(address(pool), 1 ether, settings);
    }

    function test_deposit_fail_with_InsufficientBalance() public {
        pool.mint(alice, 0.5 ether);
        registry.setTokenInfos(true);
        ILayerZeroSettings.LzSettings memory settings = _generateSettings(
            messenger,
            Operation.Deposit
        );

        vm.startPrank(alice);
        pool.approve(address(stTBY), 1 ether);
        vm.expectRevert(bytes("ERC20: transfer amount exceeds balance"));
        stTBY.depositTby(address(pool), 1 ether, settings);
        vm.stopPrank();
    }

    function test_deposit_fail_with_InsufficientAllowance() public {
        pool.mint(alice, 1 ether);
        registry.setTokenInfos(true);
        ILayerZeroSettings.LzSettings memory settings = _generateSettings(
            messenger,
            Operation.Deposit
        );

        vm.startPrank(alice);
        pool.approve(address(stTBY), 0.5 ether);
        vm.expectRevert(bytes("ERC20: insufficient allowance"));
        stTBY.depositTby(address(pool), 1 ether, settings);
        vm.stopPrank();
    }

    function test_depositTBY_success() public {
        uint256 amountTBY = 1.1e6;
        uint256 amountStTBY = 1.1e18;
        uint256 fee = (amountStTBY * mintBps) / BPS;
        pool.mint(alice, amountTBY);
        registry.setTokenInfos(true);
        registry.setExchangeRate(address(pool), 1e18);

        vm.startPrank(alice);
        pool.approve(address(stTBY), amountTBY);
        vm.expectEmit(true, true, true, true);
        emit Deposit(alice, address(pool), amountTBY, amountStTBY - fee);
        ILayerZeroSettings.LzSettings memory settings = _generateSettings(
            messenger,
            Operation.Deposit
        );
        stTBY.depositTby(address(pool), amountTBY, settings);
        vm.stopPrank();

        assertEq(stTBY.balanceOf(alice), amountStTBY - fee);
        assertEq(stTBY.balanceOf(address(staking)), fee);
    }

    function test_depositUnderlying_success() public {
        uint256 amount = 1.1e6;
        uint256 amountStTBY = 1.1e18;
        uint256 fee = (amountStTBY * mintBps) / BPS;
        stableToken.mint(address(alice), amount);
        registry.setTokenInfos(true);

        // Deposit when a BloomPool is not in the commit stage
        vm.startPrank(alice);
        stableToken.approve(address(stTBY), amount);
        vm.expectEmit(true, true, true, true);
        emit Deposit(alice, address(stableToken), amount, amountStTBY - fee);
        ILayerZeroSettings.LzSettings memory settings = _generateSettings(
            messenger,
            Operation.Deposit
        );
        stTBY.depositUnderlying(amount, settings);
        vm.stopPrank();

        assertEq(stTBY.balanceOf(alice), amountStTBY - fee);

        // Deposit when a BloomPool is in the commit stage
        stableToken.mint(bob, amount);
        pool.setState(IBloomPool.State.Commit);

        vm.startPrank(bob);
        stableToken.approve(address(stTBY), amount);
        vm.expectEmit(true, true, true, true);
        emit Deposit(bob, address(stableToken), amount, amountStTBY - fee);
        ILayerZeroSettings.LzSettings memory settings2 = _generateSettings(
            messenger,
            Operation.Deposit
        );
        stTBY.depositUnderlying(amount, settings2);
        vm.stopPrank();

        assertEq(stTBY.balanceOf(bob), amountStTBY - fee);

        assertEq(stTBY.balanceOf(address(staking)), fee * 2);
    }

    function testMintRewards() public {
        // Properly mint rewards for the first 200M stTBY
        uint256 amount = 200_000_000e6;
        uint256 amount_scaled = amount * 1e12;
        pool.mint(alice, amount);
        registry.setTokenInfos(true);
        registry.setExchangeRate(address(pool), 1e18);

        vm.startPrank(alice);
        pool.approve(address(stTBY), amount);
        ILayerZeroSettings.LzSettings memory settings = _generateSettings(
            messenger,
            Operation.Deposit
        );
        stTBY.depositTby(address(pool), amount, settings);
        vm.stopPrank();

        // Verify that the alice received the rewards
        assertEq(supToken.balanceOf(alice), amount_scaled);

        // Fail to mint rewards for the next mint of stTBY
        pool.mint(bob, 100e6);
        vm.startPrank(bob);
        pool.approve(address(stTBY), 100e6);

        stTBY.depositTby(address(pool), 100e6, settings);
        vm.stopPrank();

        // Verify that bob did not receive any rewards
        assertEq(supToken.balanceOf(bob), 0);
        // Verify that bob still received his stTBY
        assertTrue(stTBY.balanceOf(bob) > 0);

        // Burn some stTBY to decrease the total supply below 200M and try to mint rewards again
        uint256 burnAmount = 100_000_000e18;
        stableToken.mint(address(stTBY), 100_000_000e6);
        vm.startPrank(alice);
        stTBY.approve(address(stTBY), UINT256_MAX);
        stTBY.redeemStTBY(burnAmount, settings);
        vm.stopPrank();

        // Verify that the total TBY in stTBY is now below 200M
        assertTrue(stTBY.getTotalUsd() < 200_000_000e18);

        uint256 aliceBalancePreMint = stTBY.balanceOf(alice);
        // Fail to mint rewards for the next mint of stTBY but do not revert
        pool.mint(alice, 100e6);
        vm.startPrank(alice);
        pool.approve(address(stTBY), 100e6);
        stTBY.depositTby(address(pool), 100e6, settings);
        vm.stopPrank();

        // Verify alice did not receive any additional rewards
        assertEq(supToken.balanceOf(alice), amount_scaled);
        // Verify that alice still received her stTBY
        assertTrue(stTBY.balanceOf(alice) > aliceBalancePreMint);
    }

    function testAutoMint() public {
        uint256 donationAmount = 100e6;
        uint256 startingUSDCAliceBalance = 1e6;
        uint256 stTBYMintAmount = 1e18;
        uint256 aliceDepositFee = (stTBYMintAmount * stTBY.getMintBps()) / BPS;
        uint256 expectedEndSharesAlice = stTBYMintAmount - aliceDepositFee;
        uint256 exchangeRate = 1.04e18;

        address[] memory activeTokens = new address[](1);
        activeTokens[0] = address(pool);

        registry.setActiveTokens(activeTokens);
        registry.setExchangeRate(address(pool), 1e18);

        // Setup pool and stTBY
        registry.setTokenInfos(true);
        pool.setCommitPhaseEnd(block.timestamp + 25 hours);
        pool.setState(IBloomPool.State.Commit);

        // Initial deposit to give alice some stTBY
        vm.startPrank(alice);
        stableToken.approve(address(stTBY), donationAmount);
        stableToken.mint(alice, startingUSDCAliceBalance);
        ILayerZeroSettings.LzSettings memory settings = _generateSettings(
            messenger,
            Operation.Deposit
        );
        stTBY.depositUnderlying(startingUSDCAliceBalance, settings);
        vm.stopPrank();

        // Donate to stTBY
        stableToken.mint(address(stTBY), donationAmount);

        // Expect nothing to happen if the pool is not in the last 24 hours
        stTBY.poke(settings);
        assertEq(stTBY.getTotalUsd(), startingUSDCAliceBalance * 1e12);
        assertEq(stableToken.balanceOf(address(stTBY)), donationAmount);

        // fast forward to 1 hour before the end of the commit phase
        // AutoMint should successfully happen
        skip(pool.COMMIT_PHASE_END() - 1 hours);
        vm.expectEmit(true, true, true, true);
        emit TBYAutoMinted(address(pool), donationAmount);
        stTBY.poke(settings);

        assertEq(stableToken.balanceOf(address(stTBY)), 0);
        assertEq(
            stableToken.balanceOf(address(pool)),
            donationAmount + startingUSDCAliceBalance
        );
        assertEq(stTBY.sharesOf(alice), expectedEndSharesAlice);

        // fast forward to 1 day after the end of the commit phase
        // if some of the deposit does not get matched, remaining balance
        // should be adjusted
        skip(1 days);
        uint256 unmatchedAmount = 10e6;
        uint256 tbyReturned = donationAmount -
            unmatchedAmount +
            startingUSDCAliceBalance;

        // Send some TBYs & underlying to stTBY to simulate a partial match
        stableToken.mint(address(stTBY), unmatchedAmount);
        pool.mint(address(stTBY), tbyReturned);

        uint256 startingRemainingBalance = stTBY.getRemainingBalance();
        uint256 expectedRemainingBalanceEnd = startingRemainingBalance +
            unmatchedAmount;

        // Rate will also be adjusted
        registry.setExchangeRate(address(pool), exchangeRate);

        pool.setState(IBloomPool.State.Holding);
        vm.expectEmit(true, true, true, true);
        emit RemainingBalanceAdjusted(unmatchedAmount);
        stTBY.poke(settings);

        uint256 underlyingScaledBalance = stableToken.balanceOf(
            address(stTBY)
        ) * 1e12;
        uint256 tbyScaledBalance = pool.balanceOf(address(stTBY)) * 1e12;

        assertEq(
            stTBY.getTotalUsd(),
            (tbyScaledBalance * exchangeRate) / 1e18 + underlyingScaledBalance
        );
        assertEq(pool.balanceOf(address(stTBY)), tbyReturned);
        assertEq(
            stableToken.balanceOf(address(stTBY)),
            expectedRemainingBalanceEnd
        );
        assertEq(stTBY.sharesOf(alice), expectedEndSharesAlice);
    }

    function testEmergencyHandlerWithdraw() public {
        uint256 amount = 100e6;
        registry.setTokenInfos(true);
        registry.setExchangeRate(address(pool), 1e18);

        pool.setState(IBloomPool.State.Commit);
        pool.setCommitPhaseEnd(2 days);

        pool.mint(alice, amount);
        vm.startPrank(alice);
        pool.approve(address(stTBY), amount);
        ILayerZeroSettings.LzSettings memory settings = _generateSettings(
            messenger,
            Operation.Deposit
        );
        stTBY.depositTby(address(pool), amount, settings);
        vm.stopPrank();

        registry.setExchangeRate(address(pool), 1.04e18);

        skip(2 days);
        pool.setState(IBloomPool.State.Holding);

        MockBloomPool newPool = new MockBloomPool(
            address(stableToken),
            address(billyToken),
            address(swap),
            6
        );
        factory.setLastCreatedPool(address(newPool));
        registry.setExchangeRate(address(newPool), 1e18);

        newPool.mint(alice, amount);
        vm.startPrank(alice);
        newPool.approve(address(stTBY), amount);
        stTBY.depositTby(address(newPool), amount, settings);
        newPool.setEmergencyHandler(address(emergencyHandler));

        newPool.setCommitPhaseEnd(1 days);
        skip(5 days);

        newPool.setState(IBloomPool.State.EmergencyExit);
        // This is a delayed rate that has accrued value after
        // tokens were sent to emergency handler. This is to simulate
        // a pool that has been in emergency exit for a while
        // and tokens being withdraw after the rate freeze in the handler.
        // For these tests we will assume the frozen rate is 1e18 and the
        // preceived rate from the registry is 1.02e18
        registry.setExchangeRate(address(newPool), 1.02e18);
        address[] memory activeTokens = new address[](2);
        activeTokens[0] = address(pool);
        activeTokens[1] = address(newPool);
        registry.setActiveTokens(activeTokens);

        uint256 expectedUSDPreEmergency = ((amount * 1e12 * 1.04e18) / 1e18) +
            ((amount * 1e12 * 1.02e18) / 1e18);
        uint256 expectedUSDPostEmergency = ((amount * 1e12 * 1.04e18) / 1e18) +
            amount *
            1e12;

        stTBY.poke(settings);
        assertEq(stTBY.getTotalUsd(), expectedUSDPreEmergency);

        stableToken.mint(address(emergencyHandler), amount);

        vm.startPrank(alice);
        emergencyHandler.setNumTokensToRedeem(amount);
        stTBY.redeemUnderlying(address(newPool), settings);

        assertEq(stableToken.balanceOf(address(emergencyHandler)), 0);
        assertEq(stableToken.balanceOf(address(stTBY)), amount);
        assertEq(stTBY.getTotalUsd(), expectedUSDPostEmergency);
    }

    function testFullFlow() public {
        uint256 aliceAmount = 1e6;
        uint256 bobAmount = 2e6;
        pool.mint(alice, 1e6);
        pool.mint(bob, 2e6);
        registry.setTokenInfos(true);
        pool.setCommitPhaseEnd(block.timestamp + 25 hours);
        registry.setExchangeRate(address(pool), 1e18);
        /// ########## High Level Initial Share Math ##########
        uint256 aliceMintedShares = (aliceAmount -
            ((aliceAmount * mintBps) / BPS)) * 1e12;
        uint256 bobMintedShares = (bobAmount - ((bobAmount * mintBps) / BPS)) *
            1e12;
        uint256 mintedStakeUpStakingShares = 3e18 -
            (aliceMintedShares + bobMintedShares);
        uint256 aliceRedeemFees = (aliceMintedShares * redeemBps) / BPS;
        uint256 bobRedeemFees = (bobMintedShares * redeemBps) / BPS;
        uint256 expectedPerformanceFee = 3e16; // 10% of yield
        // ###########################################

        ILayerZeroSettings.LzSettings memory settings = _generateSettings(
            messenger,
            Operation.Deposit
        );

        /// ########## Deposit Functionality ##########
        vm.startPrank(alice);
        pool.approve(address(stTBY), aliceAmount);
        vm.expectEmit(true, true, true, true);
        emit Deposit(alice, address(pool), aliceAmount, aliceMintedShares);
        stTBY.depositTby(address(pool), aliceAmount, settings);
        vm.stopPrank();

        vm.startPrank(bob);
        pool.approve(address(stTBY), bobAmount);
        vm.expectEmit(true, true, true, true);
        emit Deposit(bob, address(pool), bobAmount, bobMintedShares);
        stTBY.depositTby(address(pool), bobAmount, settings);
        stTBY.approve(address(wstTBY), bobMintedShares);
        wstTBY.wrap(bobMintedShares);
        vm.stopPrank();

        // Verify state after deposits
        assertEq(stTBY.balanceOf(alice), aliceMintedShares);
        assertEq(wstTBY.balanceOf(bob), bobMintedShares);
        assertEq(stTBY.balanceOf(address(staking)), mintedStakeUpStakingShares);
        assertEq(stTBY.totalSupply(), 3e18);
        assertEq(stTBY.getTotalShares(), 3e18);
        assertEq(stTBY.getTotalUsd(), 3e18);

        assertEq(wstTBY.getWstTBYByStTBY(1 ether), 1 ether);
        assertEq(wstTBY.getStTBYByWstTBY(1 ether), 1 ether);
        assertEq(wstTBY.stTBYPerToken(), 1 ether);
        assertEq(wstTBY.tokensPerStTBY(), 1 ether);
        /// ##############################################

        // ####### Set the stTBY up for a 10% yield #######
        stableToken.mint(address(pool), 3_300000);
        swap.setRate(1e18);
        pool.initiatePreHoldSwap();
        swap.completeNextSwap();

        swap.setRate(1.1e18);
        pool.initiatePostHoldSwap();
        swap.completeNextSwap();
        // ###############################################

        // ####### Verify performance fee #################
        uint256 stakeupStakingShares = stTBY.sharesOf(address(staking));
        uint256 performanceFeeInShares = stTBY.getSharesByUsd(
            expectedPerformanceFee
        );
        ILayerZeroSettings.LzSettings memory pokeSettings = _generateSettings(
            messenger,
            Operation.Poke
        );
        stTBY.poke(pokeSettings);
        ILayerZeroSettings.LzSettings memory redeemSettings = _generateSettings(
            messenger,
            Operation.Redeem
        );
        stTBY.redeemUnderlying(address(pool), redeemSettings);

        uint256 sharesPerUsd = (stTBY.getTotalShares() * 1e18) /
            stTBY.getTotalUsd();
        uint256 usdPerShares = (stTBY.getTotalUsd() * 1e18) /
            stTBY.getTotalShares() +
            1; // Add 1 to round up

        assertEq(wstTBY.stTBYPerToken(), usdPerShares);
        assertEq(wstTBY.tokensPerStTBY(), sharesPerUsd);
        // ###############################################

        // ####### Redeem state Tests ####################
        uint256 aliceShares = stTBY.sharesOf(alice);
        uint256 aliceBalance1 = stTBY.balanceOf(alice);
        uint256 bobWrappedAmount = wstTBY.balanceOf(bob);

        uint256 scaler = 10 ** (18 + (18 - stableToken.decimals()));
        uint256 aliceExpectedStableBalance = (aliceBalance1 * .995e18) / scaler;
        uint256 bobExpectedStableBalance = (stTBY.getUsdByShares(
            bobWrappedAmount
        ) * .995e18) / scaler;

        vm.startPrank(alice);
        stTBY.approve(address(stTBY), UINT256_MAX);
        vm.expectEmit(true, true, true, true);
        emit Redeemed(
            alice,
            aliceShares - aliceRedeemFees,
            aliceExpectedStableBalance
        );
        ILayerZeroSettings.LzSettings
            memory withdrawSettings = _generateSettings(
                messenger,
                Operation.Withdraw
            );
        stTBY.redeemStTBY(stTBY.balanceOf(alice), withdrawSettings);
        vm.stopPrank();

        vm.startPrank(bob);
        wstTBY.approve(address(stTBY), UINT256_MAX);
        vm.expectEmit(true, true, true, true);
        emit Redeemed(
            bob,
            bobWrappedAmount - bobRedeemFees,
            bobExpectedStableBalance
        );
        stTBY.redeemWstTBY(bobWrappedAmount, withdrawSettings);
        vm.stopPrank();

        assertEq(stTBY.balanceOf(alice), 0);
        assertEq(stableToken.balanceOf(alice), aliceExpectedStableBalance);

        assertEq(stTBY.sharesOf(bob), 0);
        assertEq(stableToken.balanceOf(bob), bobExpectedStableBalance);

        assertEq(
            stTBY.sharesOf(address(staking)),
            stakeupStakingShares +
                performanceFeeInShares +
                aliceRedeemFees +
                bobRedeemFees
        );
        // ###############################################
    }

    function test_DistributePokeRewards() public {
        uint256 MAX_POKE_REWARDS = 10_000_000e18;

        // Setup pool and stTBY
        registry.setTokenInfos(true);
        pool.setCommitPhaseEnd(block.timestamp + 1 hours + 3 days);
        pool.setState(IBloomPool.State.Commit);

        skip(3 days);
        uint256 year = 1;
        uint256 yearOneRewards = (MAX_POKE_REWARDS *
            (FixedPointMathLib.WAD - (FixedPointMathLib.WAD / 2 ** year))) /
            FixedPointMathLib.WAD;

        uint256 expectedReward = (3 days * yearOneRewards) / 52 weeks;

        ILayerZeroSettings.LzSettings memory settings = _generateSettings(
            messenger,
            Operation.Poke
        );

        vm.startPrank(alice);
        stTBY.poke(settings);
        vm.stopPrank();

        assertEq(supToken.balanceOf(alice), expectedReward);
    }
}
