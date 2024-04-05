// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {Test} from "forge-std/Test.sol";
import {LibRLP} from "solady/utils/LibRLP.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

import {StTBY} from "src/token/StTBY.sol";
import {WstTBY} from "src/token/WstTBY.sol";
import {StakeupStaking} from "src/staking/StakeupStaking.sol";

import {IStTBY} from "src/interfaces/IStTBY.sol";

import {MockERC20} from "../mocks/MockERC20.sol";
import {MockSwapFacility} from "../mocks/MockSwapFacility.sol";
import {MockBloomPool, IBloomPool} from "../mocks/MockBloomPool.sol";
import {MockBloomFactory} from "../mocks/MockBloomFactory.sol";
import {MockEmergencyHandler} from "../mocks/MockEmergencyHandler.sol";
import {MockRegistry} from "../mocks/MockRegistry.sol";

contract StTBYTest is Test {

    StTBY internal stTBY;
    WstTBY internal wstTBY;

    MockERC20 internal stableToken;
    MockERC20 internal billyToken;
    MockERC20 internal supToken;
    MockSwapFacility internal swap;
    MockBloomPool internal pool;
    MockBloomFactory internal factory;
    MockRegistry internal registry;
    StakeupStaking internal staking;
    MockEmergencyHandler internal emergencyHandler;

    address internal owner = makeAddr("owner");
    address internal layerZeroEndpoint = makeAddr("layerZeroEndpoint");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    
    // Fees
    uint16 internal mintBps = 50;
    uint16 internal redeemBps = 50;
    uint16 internal performanceFeeBps = 1000;

    uint16 internal constant BPS = 10000;

    bytes internal constant NOT_OWNER_ERROR = bytes("Ownable: caller is not the owner");

    // ============== Redefined Events ===============
    event Deposit(address indexed account, address tby, uint256 amount, uint256 shares);
    event Redeemed(address indexed account, uint256 shares, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);
    event TBYAutoMinted(address indexed account, uint256 amount);
    event RemainingBalanceAdjusted(uint256 amount);

    function setUp() public {
        stableToken = new MockERC20(6);
        vm.label(address(stableToken), "StableToken");
        billyToken = new MockERC20(18);
        vm.label(address(billyToken), "BillyToken");
        supToken = new MockERC20(18);
        vm.label(address(supToken), "SupToken");
        
        swap = new MockSwapFacility(stableToken, billyToken);
        vm.label(address(swap), "MockSwapFacility");
        
        pool = new MockBloomPool(
            address(stableToken),
            address(billyToken),
            address(swap),
            6
        );
        vm.label(address(pool), "MockBloomPool");
        
        emergencyHandler = new MockEmergencyHandler();
        vm.label(address(emergencyHandler), "MockEmergencyHandler");

        pool.setEmergencyHandler(address(emergencyHandler));

        vm.startPrank(owner);

        factory = new MockBloomFactory();
        vm.label(address(factory), "MockBloomFactory");
        factory.setLastCreatedPool(address(pool));

        registry = new MockRegistry(address(pool));

        address expectedStakingAddress = LibRLP.computeAddress(owner, vm.getNonce(owner) + 1);

        staking = new StakeupStaking(
            address(supToken),
            expectedStakingAddress
        );
        
        address expectedWrapperAddress = LibRLP.computeAddress(owner, vm.getNonce(owner) + 1);

        stTBY = new StTBY(
            address(stableToken),
            address(staking),
            address(factory),
            address(registry),
            mintBps,
            redeemBps,
            performanceFeeBps,
            expectedWrapperAddress,
            true,
            layerZeroEndpoint
        );
        vm.label(address(stTBY), "StTBY");

        assertEq(stTBY.owner(), owner);
        assertEq(address(stTBY.getUnderlyingToken()), address(stableToken));
        assertEq(stTBY.getMintBps(), mintBps);
        assertEq(stTBY.getRedeemBps(), redeemBps);
        assertEq(stTBY.getPerformanceBps(), performanceFeeBps);

        wstTBY = new WstTBY(address(stTBY));
        vm.label(address(wstTBY), "WstTBY");

        assertEq(address(wstTBY), expectedWrapperAddress);
        assertEq(address(wstTBY.getStTBY()), address(stTBY));

        vm.stopPrank();
    }

    function test_deposit_fail_with_TBYNotActive() public {
        registry.setTokenInfos(false);
        vm.expectRevert(IStTBY.TBYNotActive.selector);
        vm.prank(alice);
        stTBY.depositTby(address(pool), 1 ether);
    }

    function test_deposit_fail_with_InsufficientBalance() public {
        pool.mint(alice, 0.5 ether);
        registry.setTokenInfos(true);

        vm.startPrank(alice);
        pool.approve(address(stTBY), 1 ether);
        vm.expectRevert(bytes("ERC20: transfer amount exceeds balance"));
        stTBY.depositTby(address(pool), 1 ether);
        vm.stopPrank();
    }

    function test_deposit_fail_with_InsufficientAllowance() public {
        pool.mint(alice, 1 ether);
        registry.setTokenInfos(true);

        vm.startPrank(alice);
        pool.approve(address(stTBY), 0.5 ether);
        vm.expectRevert(bytes("ERC20: insufficient allowance"));
        stTBY.depositTby(address(pool), 1 ether);
        vm.stopPrank();
    }

    function test_depositTBY_success() public {
        uint256 amountTBY = 1.1e6;
        uint256 amountStTBY = 1.1e18;
        uint256 fee = 0.0055e18; // 0.5% of mint
        pool.mint(alice, amountTBY);
        registry.setTokenInfos(true);
        registry.setExchangeRate(address(pool), 1e18);

        vm.startPrank(alice);
        pool.approve(address(stTBY), amountTBY);
        vm.expectEmit(true, true, true, true);
        emit Deposit(alice, address(pool), amountTBY, amountStTBY - fee);
        stTBY.depositTby(address(pool), amountTBY);
        vm.stopPrank();

        assertEq(stTBY.balanceOf(alice), amountStTBY - fee);
        assertEq(stTBY.balanceOf(address(staking)), fee);
    }

    function test_depositUnderlying_success() public {
        uint256 amount = 1.1e6;
        uint256 amountStTBY = 1.1e18;
        uint256 fee = 0.0055e18; // 0.5% of mint
        stableToken.mint(address(alice), amount);
        registry.setTokenInfos(true);

        // Deposit when a BloomPool is not in the commit stage
        vm.startPrank(alice);
        stableToken.approve(address(stTBY), amount);
        vm.expectEmit(true, true, true, true);
        emit Deposit(alice, address(stableToken), amount, amountStTBY - fee);
        stTBY.depositUnderlying(amount);
        vm.stopPrank();

        assertEq(stTBY.balanceOf(alice), amountStTBY - fee);

        // Deposit when a BloomPool is in the commit stage
        stableToken.mint(bob, amount);
        pool.setState(IBloomPool.State.Commit);

        vm.startPrank(bob);
        stableToken.approve(address(stTBY), amount);
        vm.expectEmit(true, true, true, true);
        emit Deposit(bob, address(stableToken), amount, amountStTBY - fee);
        stTBY.depositUnderlying(amount);
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
        stTBY.depositTby(address(pool), amount);
        vm.stopPrank();

        // Verify that the alice received the rewards
        assertEq(supToken.balanceOf(alice), amount_scaled);

        // Fail to mint rewards for the next mint of stTBY
        pool.mint(bob, 100e6);
        vm.startPrank(bob);
        pool.approve(address(stTBY), 100e6);
        stTBY.depositTby(address(pool), 100e6);
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
        stTBY.redeemStTBY(burnAmount);
        vm.stopPrank();

        // Verify that the total TBY in stTBY is now below 200M
        assertTrue(stTBY.getTotalUsd() < 200_000_000e18);

        uint256 aliceBalancePreMint = stTBY.balanceOf(alice);
        // Fail to mint rewards for the next mint of stTBY but do not revert
        pool.mint(alice, 100e6);
        vm.startPrank(alice);
        pool.approve(address(stTBY), 100e6);
        stTBY.depositTby(address(pool), 100e6);
        vm.stopPrank();

        // Verify alice did not receive any additional rewards
        assertEq(supToken.balanceOf(alice), amount_scaled);
        // Verify that alice still received her stTBY
        assertTrue(stTBY.balanceOf(alice) > aliceBalancePreMint);
    }

    function testAutoMint() public {
        uint256 amount = 100e6;
        uint256 startingTBYAliceBalance = 1e6;
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
        pool.mint(alice, startingTBYAliceBalance);
        pool.setCommitPhaseEnd(block.timestamp + 25 hours);
        pool.setState(IBloomPool.State.Commit);

        // Initial deposit to give alice some stTBY
        vm.startPrank(alice);
        pool.approve(address(stTBY), amount);
        stTBY.depositTby(address(pool), startingTBYAliceBalance);
        vm.stopPrank();

        // Donate to stTBY
        stableToken.mint(address(stTBY), amount);

        // Expect nothing to happen if the pool is not in the last 24 hours   
        stTBY.poke();
        assertEq(stTBY.getTotalUsd(), startingTBYAliceBalance * 1e12);
        assertEq(stableToken.balanceOf(address(stTBY)), amount);
        
        // fast forward to 1 hour before the end of the commit phase
        // AutoMint should successfully happen
        skip(pool.COMMIT_PHASE_END() - 1 hours);
        vm.expectEmit(true, true, true, true);
        emit TBYAutoMinted(address(pool), amount);
        stTBY.poke();

        assertEq(stableToken.balanceOf(address(stTBY)), 0);
        assertEq(stableToken.balanceOf(address(pool)), amount);
        assertEq(stTBY.sharesOf(alice), expectedEndSharesAlice);

        // fast forward to 1 day after the end of the commit phase
        // if some of the deposit does not get matched, remaining balance
        // should be adjusted
        skip(1 days);
        uint256 unmatchedAmount = 10e6;
        uint256 tbyReturned = amount - unmatchedAmount;

        // Send some TBYs & underlying to stTBY to simulate a partial match
        stableToken.mint(address(stTBY), unmatchedAmount);
        pool.mint(address(stTBY), tbyReturned);

        uint256 startingRemainingBalance = stTBY.getRemainingBalance();
        uint256 expectedRemainingBalanceEnd = startingRemainingBalance + unmatchedAmount;

        // Rate will also be adjusted
        registry.setExchangeRate(address(pool), exchangeRate);

        pool.setState(IBloomPool.State.Holding);
        vm.expectEmit(true, true, true, true);
        emit RemainingBalanceAdjusted(unmatchedAmount);
        stTBY.poke();
        
        uint256 underlyingScaledBalance = stableToken.balanceOf(address(stTBY)) * 1e12;
        uint256 tbyScaledBalance = pool.balanceOf(address(stTBY)) * 1e12;
        
        assertEq(stTBY.getTotalUsd(), tbyScaledBalance * exchangeRate / 1e18 + underlyingScaledBalance);
        assertEq(pool.balanceOf(address(stTBY)), tbyReturned + startingTBYAliceBalance);
        assertEq(stableToken.balanceOf(address(stTBY)), expectedRemainingBalanceEnd);
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
        stTBY.depositTby(address(pool), amount);
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
        stTBY.depositTby(address(newPool), amount);
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

        uint256 expectedUSDPreEmergency = (amount * 1e12 * 1.04e18 / 1e18) + (amount * 1e12 * 1.02e18 / 1e18); 
        uint256 expectedUSDPostEmergency = (amount * 1e12 * 1.04e18 / 1e18) + amount * 1e12;
        
        stTBY.poke();
        assertEq(stTBY.getTotalUsd(), expectedUSDPreEmergency);

        stableToken.mint(address(emergencyHandler), amount);
        
        vm.startPrank(alice);
        emergencyHandler.setNumTokensToRedeem(amount);
        stTBY.redeemUnderlying(address(newPool));

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
        uint256 aliceMintedShares = .995e18;
        uint256 bobMintedShares = 1.99e18;
        uint256 mintedStakeupStakingShares = .015e18; // 0.5% of total minted shares
        uint256 aliceRedeemFees = (aliceMintedShares * redeemBps) / BPS;
        uint256 bobRedeemFees = (bobMintedShares * redeemBps) / BPS;
        uint256 expectedPerformanceFee = 3e16; // 10% of yield
        // ###########################################


        /// ########## Deposit Functionality ##########
        vm.startPrank(alice);
        pool.approve(address(stTBY), aliceAmount);
        vm.expectEmit(true, true, true, true);
        emit Deposit(alice, address(pool), aliceAmount, aliceMintedShares);
        stTBY.depositTby(address(pool), aliceAmount);
        vm.stopPrank();

        vm.startPrank(bob);
        pool.approve(address(stTBY), bobAmount);
        vm.expectEmit(true, true, true, true);
        emit Deposit(bob, address(pool), bobAmount, bobMintedShares);
        stTBY.depositTby(address(pool), bobAmount);
        stTBY.approve(address(wstTBY), bobMintedShares);
        wstTBY.wrap(bobMintedShares);
        vm.stopPrank();

        // Verify state after deposits
        assertEq(stTBY.balanceOf(alice), aliceMintedShares);
        assertEq(wstTBY.balanceOf(bob), bobMintedShares);
        assertEq(stTBY.balanceOf(address(staking)), mintedStakeupStakingShares);
        assertEq(stTBY.totalSupply(), 3e18);
        assertEq(stTBY.getTotalShares(), 3e18);

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
        uint256 performanceFeeInShares = stTBY.getSharesByUsd(expectedPerformanceFee);
        stTBY.poke();
        stTBY.redeemUnderlying(address(pool));

        uint256 sharesPerUsd = stTBY.getTotalShares() * 1e18 / stTBY.getTotalUsd();
        uint256 usdPerShares = stTBY.getTotalUsd() * 1e18 / stTBY.getTotalShares() + 1; // Add 1 to round up

        assertEq(wstTBY.stTBYPerToken(), usdPerShares);
        assertEq(wstTBY.tokensPerStTBY(), sharesPerUsd);  
        // ###############################################

        // ####### Redeem state Tests ####################
        uint256 aliceShares = stTBY.sharesOf(alice);
        uint256 aliceBalance1 = stTBY.balanceOf(alice);
        uint256 bobWrappedAmount = wstTBY.balanceOf(bob);

        uint256 scaler = 10 ** (18 + (18 - stableToken.decimals()));
        uint256 aliceExpectedStableBalance = aliceBalance1 * .995e18 / scaler;
        uint256 bobExpectedStableBalance = wstTBY.getStTBYByWstTBY(bobWrappedAmount) * .995e18 / scaler;

        vm.startPrank(alice);
        stTBY.approve(address(stTBY), UINT256_MAX);
        vm.expectEmit(true, true, true, true);
        emit Redeemed(alice, aliceShares - aliceRedeemFees, aliceExpectedStableBalance);
        stTBY.redeemStTBY(aliceBalance1);
        vm.stopPrank();

        vm.startPrank(bob);
        wstTBY.approve(address(stTBY), UINT256_MAX);
        vm.expectEmit(true, true, true, true);
        emit Redeemed(bob, bobWrappedAmount - bobRedeemFees, bobExpectedStableBalance);
        stTBY.redeemWstTBY(bobWrappedAmount);
        vm.stopPrank();

        assertEq(stTBY.balanceOf(alice), 0);
        assertEq(stableToken.balanceOf(alice), aliceExpectedStableBalance);

        assertEq(stTBY.sharesOf(bob), 0);
        assertEq(stableToken.balanceOf(bob), bobExpectedStableBalance);

        assertEq(stTBY.sharesOf(address(staking)), stakeupStakingShares + performanceFeeInShares + aliceRedeemFees + bobRedeemFees);
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
        uint256 yearOneRewards = MAX_POKE_REWARDS * (FixedPointMathLib.WAD - (FixedPointMathLib.WAD / 2**year)) / FixedPointMathLib.WAD;

        uint256 expectedReward = 3 days * yearOneRewards / 52 weeks;
        
        vm.startPrank(alice);
        stTBY.poke();
        vm.stopPrank();

        assertEq(supToken.balanceOf(alice), expectedReward);        
    }
}
