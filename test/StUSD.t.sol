// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {LibRLP} from "solady/utils/LibRLP.sol";

import {StUSD} from "src/token/StUSD.sol";
import {WstUSD} from "src/token/WstUSD.sol";

import {IStUSD} from "src/interfaces/IStUSD.sol";

import {MockERC20} from "./mock/MockERC20.sol";
import {MockSwapFacility} from "./mock/MockSwapFacility.sol";
import {MockBloomPool, IBloomPool} from "./mock/MockBloomPool.sol";
import {MockBloomFactory} from "./mock/MockBloomFactory.sol";
import {MockRegistry} from "./mock/MockRegistry.sol";
import {MockStakeupStaking} from "./mock/MockStakeupStaking.sol";

contract StUSDTest is Test {

    StUSD internal stUSD;
    WstUSD internal wstUSD;

    MockERC20 internal stableToken;
    MockERC20 internal billyToken;
    MockSwapFacility internal swap;
    MockBloomPool internal pool;
    MockBloomFactory internal factory;
    MockRegistry internal registry;
    MockStakeupStaking internal staking;

    address internal owner = makeAddr("owner");
    address internal layerZeroEndpoint = makeAddr("layerZeroEndpoint");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    
    // Fees
    uint16 internal mintBps = 50;
    uint16 internal redeemBps = 50;
    uint16 internal performanceFeeBps = 1000;

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
        swap = new MockSwapFacility(stableToken, billyToken);
        vm.label(address(swap), "MockSwapFacility");

        pool = new MockBloomPool(
            address(stableToken),
            address(billyToken),
            address(swap),
            6
        );
        vm.label(address(pool), "MockBloomPool");

        vm.startPrank(owner);

        factory = new MockBloomFactory();
        vm.label(address(factory), "MockBloomFactory");
        factory.setLastCreatedPool(address(pool));

        registry = new MockRegistry(address(pool));

        staking = new MockStakeupStaking();
        address expectedWrapperAddress = LibRLP.computeAddress(owner, vm.getNonce(owner) + 1);

        stUSD = new StUSD(
            address(stableToken),
            address(staking),
            address(factory),
            address(registry),
            mintBps,
            redeemBps,
            performanceFeeBps,
            layerZeroEndpoint,
            expectedWrapperAddress
        );
        vm.label(address(stUSD), "StUSD");

        assertEq(stUSD.owner(), owner);
        assertEq(address(stUSD.underlyingToken()), address(stableToken));
        assertEq(stUSD.mintBps(), mintBps);
        assertEq(stUSD.redeemBps(), redeemBps);
        assertEq(stUSD.performanceBps(), performanceFeeBps);

        wstUSD = new WstUSD(address(stUSD));
        vm.label(address(wstUSD), "WstUSD");

        assertEq(address(wstUSD), expectedWrapperAddress);
        assertEq(address(wstUSD.stUSD()), address(stUSD));

        vm.stopPrank();
    }

    function test_deposit_fail_with_TBYNotActive() public {
        registry.setTokenInfos(false);
        vm.expectRevert(IStUSD.TBYNotActive.selector);
        vm.prank(alice);
        stUSD.depositTby(address(pool), 1 ether);
    }

    function test_deposit_fail_with_InsufficientBalance() public {
        pool.mint(alice, 0.5 ether);
        registry.setTokenInfos(true);

        vm.startPrank(alice);
        pool.approve(address(stUSD), 1 ether);
        vm.expectRevert(bytes("ERC20: transfer amount exceeds balance"));
        stUSD.depositTby(address(pool), 1 ether);
        vm.stopPrank();
    }

    function test_deposit_fail_with_InsufficientAllowance() public {
        pool.mint(alice, 1 ether);
        registry.setTokenInfos(true);

        vm.startPrank(alice);
        pool.approve(address(stUSD), 0.5 ether);
        vm.expectRevert(bytes("ERC20: insufficient allowance"));
        stUSD.depositTby(address(pool), 1 ether);
        vm.stopPrank();
    }

    function test_depositTBY_success() public {
        uint256 amountTBY = 1.1e6;
        uint256 amountStUSD = 1.1e18;
        uint256 fee = 0.0055e18; // 0.5% of mint
        pool.mint(alice, amountTBY);
        registry.setTokenInfos(true);

        vm.startPrank(alice);
        pool.approve(address(stUSD), amountTBY);
        vm.expectEmit(true, true, true, true);
        emit Deposit(alice, address(pool), amountTBY, amountStUSD - fee);
        stUSD.depositTby(address(pool), amountTBY);
        vm.stopPrank();

        assertEq(stUSD.balanceOf(alice), amountStUSD - fee);
        assertEq(stUSD.balanceOf(address(staking)), fee);
    }

    function test_depositUnderlying_success() public {
        uint256 amount = 1.1e6;
        uint256 amountStUSD = 1.1e18;
        uint256 fee = 0.0055e18; // 0.5% of mint
        stableToken.mint(address(alice), amount);
        registry.setTokenInfos(true);

        // Deposit when a BloomPool is not in the commit stage
        vm.startPrank(alice);
        stableToken.approve(address(stUSD), amount);
        vm.expectEmit(true, true, true, true);
        emit Deposit(alice, address(stableToken), amount, amountStUSD - fee);
        stUSD.depostUnderlying(amount);
        vm.stopPrank();

        assertEq(stUSD.balanceOf(alice), amountStUSD - fee);

        // Deposit when a BloomPool is in the commit stage
        stableToken.mint(bob, amount);
        pool.setState(IBloomPool.State.Commit);

        vm.startPrank(bob);
        stableToken.approve(address(stUSD), amount);
        vm.expectEmit(true, true, true, true);
        emit Deposit(bob, address(stableToken), amount, amountStUSD - fee);
        stUSD.depostUnderlying(amount);
        vm.stopPrank();

        assertEq(stUSD.balanceOf(bob), amountStUSD - fee);

        assertEq(stUSD.balanceOf(address(staking)), fee * 2);
    }

    function testAutoMint() public {
        uint256 amount = 100e6;
        uint256 startingTBYAliceBalance = 1e6;
        uint256 stUSDMintAmount = 1e18;
        uint256 aliceDepositFee = (stUSDMintAmount * stUSD.mintBps()) / stUSD.BPS();
        uint256 expectedEndSharesAlice = stUSDMintAmount - aliceDepositFee;
        
        // Setup pool and stUSD
        registry.setTokenInfos(true);
        pool.mint(alice, startingTBYAliceBalance);
        pool.setCommitPhaseEnd(block.timestamp + 25 hours);
        pool.setState(IBloomPool.State.Commit);

        // Initial deposit to give alice some stUSD
        vm.startPrank(alice);
        pool.approve(address(stUSD), amount);
        stUSD.depositTby(address(pool), startingTBYAliceBalance);
        vm.stopPrank();

        // Donate to stUSD
        stableToken.mint(address(stUSD), amount);

        // Expect nothing to happen if the pool is not in the last 24 hours        
        stUSD.poke();
        assertEq(stableToken.balanceOf(address(stUSD)), amount);
        
        // fast forward to 1 hour before the end of the commit phase
        // AutoMint should successfully happen
        skip(pool.COMMIT_PHASE_END() - 1 hours);
        vm.expectEmit(true, true, true, true);
        emit TBYAutoMinted(address(pool), amount);
        stUSD.poke();

        assertEq(stableToken.balanceOf(address(stUSD)), 0);
        assertEq(stableToken.balanceOf(address(pool)), amount);
        assertEq(stUSD.sharesOf(alice), expectedEndSharesAlice);

        // fast forward to 1 hour after the end of the commit phase
        // if some of the deposit does not get matched, remaining balance
        // should be adjusted
        skip(2 hours);
        uint256 unmatchedAmount = 10e6;
        uint256 tbyReturned = amount - unmatchedAmount;

        // Send some TBYs & underlying to stUSD to simulate a partial match
        stableToken.mint(address(stUSD), unmatchedAmount);
        pool.mint(address(stUSD), tbyReturned);

        uint256 startingRemainingBalance = stUSD.getRemainingBalance();
        uint256 expectedRemainingBalanceEnd = startingRemainingBalance + unmatchedAmount;

        pool.setState(IBloomPool.State.Holding);
        vm.expectEmit(true, true, true, true);
        emit RemainingBalanceAdjusted(unmatchedAmount);
        stUSD.poke();

        assertEq(pool.balanceOf(address(stUSD)), tbyReturned + startingTBYAliceBalance);
        assertEq(stableToken.balanceOf(address(stUSD)), expectedRemainingBalanceEnd);
        assertEq(stUSD.sharesOf(alice), expectedEndSharesAlice);
    }

    function testFullFlow() public {
        uint256 aliceAmount = 1e6;
        uint256 bobAmount = 2e6;
        pool.mint(alice, 1e6);
        pool.mint(bob, 2e6);
        registry.setTokenInfos(true);

        /// ########## High Level Initial Share Math ##########
        uint256 aliceMintedShares = .995e18;
        uint256 bobMintedShares = 1.99e18;
        uint256 mintedTreasuryShares = .015e18; // 0.5% of total minted shares
        uint256 totalMintedShares = 3e18;
        uint256 totalTBY = 3e6;

        uint256 expectedPerformanceFee = 3e16; // 10% of yield
        // ###########################################


        /// ########## Deposit Functionality ##########
        vm.startPrank(alice);
        pool.approve(address(stUSD), aliceAmount);
        vm.expectEmit(true, true, true, true);
        emit Deposit(alice, address(pool), aliceAmount, aliceMintedShares);
        stUSD.depositTby(address(pool), aliceAmount);
        vm.stopPrank();

        vm.startPrank(bob);
        pool.approve(address(stUSD), bobAmount);
        vm.expectEmit(true, true, true, true);
        emit Deposit(bob, address(pool), bobAmount, bobMintedShares);
        stUSD.depositTby(address(pool), bobAmount);
        stUSD.approve(address(wstUSD), bobMintedShares);
        wstUSD.wrap(bobMintedShares);
        vm.stopPrank();

        // Verify state after deposits
        assertEq(stUSD.balanceOf(alice), aliceMintedShares);
        assertEq(wstUSD.balanceOf(bob), bobMintedShares);
        assertEq(stUSD.balanceOf(address(staking)), mintedTreasuryShares);
        assertEq(stUSD.totalSupply(), totalMintedShares);
        assertEq(stUSD.getTotalShares(), totalMintedShares);

        assertEq(wstUSD.getWstUSDByStUSD(1 ether), 1 ether);
        assertEq(wstUSD.getStUSDByWstUSD(1 ether), 1 ether);
        assertEq(wstUSD.stUsdPerToken(), 1 ether);
        assertEq(wstUSD.tokensPerStUsd(), 1 ether);
        /// ##############################################


        // ####### Set the stUSD up for a 10% yield #######
        stableToken.mint(address(pool), 3_300000);
        swap.setRate(1e18);
        pool.initiatePreHoldSwap();
        swap.completeNextSwap();

        swap.setRate(1.1e18);
        pool.initiatePostHoldSwap();
        swap.completeNextSwap();
        // ###############################################

        // ####### Redeem state Tests ####################
        uint256 aliceShares = stUSD.sharesOf(alice);
        uint256 aliceAmountReceived = stUSD.getUsdByShares(aliceShares) * .995e18 / 1e18;
        
        vm.startPrank(alice);
        stUSD.approve(address(stUSD), UINT256_MAX);
        vm.expectEmit(true, true, true, true);
        emit Redeemed(alice, aliceShares, aliceAmountReceived);
        stUSD.redeemStUSD(aliceMintedShares);
        vm.stopPrank();

        uint256 bobWrappedAmount = wstUSD.balanceOf(bob);
        uint256 bobAmountReceived = wstUSD.getStUSDByWstUSD(bobWrappedAmount) * .995e18 / 1e18;
        vm.startPrank(bob);
        wstUSD.approve(address(stUSD), UINT256_MAX);
        vm.expectEmit(true, true, true, true);
        emit Redeemed(bob, bobMintedShares, bobAmountReceived);
        stUSD.redeemWstUSD(bobMintedShares);
        vm.stopPrank();

        // ###############################################

        // ####### Verify performance fee #################
        uint256 treasuryShares = stUSD.sharesOf(address(staking));
        uint256 performanceFeeInShares = stUSD.getSharesByUsd(expectedPerformanceFee);

        stUSD.redeemUnderlying(address(pool), totalTBY);

        uint256 sharesPerUsd = stUSD.getTotalShares() * 1e18 / stUSD.getTotalUsd();
        uint256 usdPerShares = stUSD.getTotalUsd() * 1e18 / stUSD.getTotalShares();

        assertEq(wstUSD.stUsdPerToken(), usdPerShares);
        assertEq(wstUSD.tokensPerStUsd(), sharesPerUsd);  
        // ###############################################

        // ############ Withdraw to underlying ############
        vm.startPrank(alice);
        stUSD.withdraw();
        assertEq(stUSD.sharesOf(alice), 0);
        assertEq(stableToken.balanceOf(alice), aliceAmountReceived / 1e12);
        vm.stopPrank();

        vm.startPrank(bob);
        stUSD.withdraw();
        assertEq(stUSD.sharesOf(bob), 0);
        assertEq(stableToken.balanceOf(bob), bobAmountReceived / 1e12);
        vm.stopPrank();

        assertEq(stUSD.sharesOf(address(staking)), treasuryShares + performanceFeeInShares);
        // ###############################################
    }
}
