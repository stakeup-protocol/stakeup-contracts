// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {StakeupStaking, IStakeupStaking} from "src/staking/StakeupStaking.sol";
import {MockERC20} from "./mock/MockERC20.sol";
import {MockSUPVesting} from "./mock/MockSUPVesting.sol";
import {MockRewardManager} from "./mock/MockRewardManager.sol";

contract StakeupStakingTest is Test {
    using FixedPointMathLib for uint256;

    StakeupStaking public stakeupStaking;
    MockERC20 public mockStakeupToken;
    MockSUPVesting public mockSUPVesting;
    MockERC20 public mockStUSD;
    MockRewardManager public rewardManager;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    event StakeupStaked(address indexed user, uint256 amount);
    event StakeupUnstaked(address indexed user, uint256 amount);
    event RewardsHarvested(address indexed user, uint256 shares);

    function setUp() public {
        mockStakeupToken = new MockERC20(18);
        vm.label(address(mockStakeupToken), "mockStakeupToken");

        mockSUPVesting = new MockSUPVesting();
        vm.label(address(mockSUPVesting), "mockSUPVesting");

        mockStUSD = new MockERC20(18);
        vm.label(address(mockStUSD), "mockStUSD");

        stakeupStaking = new StakeupStaking(
           address(mockStakeupToken),
           address(mockSUPVesting),
           address(rewardManager),
           address(mockStUSD)
        );
        vm.label(address(stakeupStaking), "stakeupStaking");
    }

    // function test_ViewFunctions() public {
    //     assertEq(stakeupStaking.REWARD_DURATION(), 1 weeks);
    //     assertEq(stakeupStaking.totalStakeUpStaked(), 0);
    // }

    function test_Stake() public {
        mockStakeupToken.mint(alice, 1000 ether);

        // Successfully Stake SUP
        vm.startPrank(alice);
        mockStakeupToken.approve(address(stakeupStaking), 1000 ether);
        vm.expectEmit(true, true, true, true);
        emit StakeupStaked(alice, 1000 ether);
        stakeupStaking.stake(1000 ether);
        vm.stopPrank();

        assertEq(stakeupStaking.totalStakeUpStaked(), 1000 ether);
        assertEq(mockStakeupToken.balanceOf(address(stakeupStaking)), 1000 ether);
        // no claimable rewards because no time has passed and no fees have been processed
        assertEq(stakeupStaking.claimableRewards(alice), 0);

        // Reverts if stake amount is 0
        vm.startPrank(alice);
        mockStakeupToken.approve(address(stakeupStaking), 0);
        vm.expectRevert(IStakeupStaking.ZeroTokensStaked.selector);
        stakeupStaking.stake(0);
        vm.stopPrank();
    }

    function test_Unstake() public {
        mockStakeupToken.mint(alice, 1000 ether);

        // Reverts if stake amount is 0
        vm.startPrank(alice);
        vm.expectRevert(IStakeupStaking.UserHasNoStaked.selector);
        stakeupStaking.unstake(1000 ether, 0);
        vm.stopPrank();

        _stake(alice, 1000 ether);

        vm.startPrank(alice);
        // Successful unstake but no harvest
        vm.expectEmit(true, true, true, true);
        emit StakeupUnstaked(alice, 1000 ether);
        stakeupStaking.unstake(1000 ether, 0);

        assertEq(stakeupStaking.totalStakeUpStaked(), 0);
        assertEq(mockStakeupToken.balanceOf(address(stakeupStaking)), 0);
        assertEq(mockStakeupToken.balanceOf(alice), 1000 ether);
        vm.stopPrank();

        // unstakes the remaining stake if stake amount is greater than a users stake
        _stake(alice, 1000 ether);

        vm.startPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit StakeupUnstaked(alice, 1000 ether);
        stakeupStaking.unstake(2000 ether, 0);
        vm.stopPrank();

        assertEq(stakeupStaking.totalStakeUpStaked(), 0);
        assertEq(mockStakeupToken.balanceOf(address(stakeupStaking)), 0);
        assertEq(mockStakeupToken.balanceOf(alice), 1000 ether);
    }

    function test_ProcessFees() public {
        mockStUSD.mint(address(stakeupStaking), 2000 ether);
        
        // Reverts if someone other than stUSD calls this function
        vm.startPrank(alice);
        vm.expectRevert(IStakeupStaking.OnlyRewardToken.selector);
        stakeupStaking.processFees(1000 ether);
        vm.stopPrank();

        // Reverts if no fees are registered
        vm.startPrank(address(mockStUSD));
        vm.expectRevert(IStakeupStaking.NoFeesToProcess.selector);
        stakeupStaking.processFees(0);
        vm.stopPrank();

        // Updates PendingRewards successfully
        _processFees(1000 ether);

        {
            IStakeupStaking.RewardData memory rewardData = stakeupStaking.getRewardData();
            uint256 availableRewards = rewardData.availableRewards;
            uint256 pendingRewards = rewardData.pendingRewards;

            assertEq(availableRewards, 0);
            assertEq(pendingRewards, 1000 ether);
        }



        // If we are after the end of the reward period, then the pending rewards are added to available rewards
        skip(2 weeks);
        _processFees(1000 ether);
        
        {
            IStakeupStaking.RewardData memory rewards = stakeupStaking.getRewardData();
            uint256 periodFinished = rewards.periodFinished;
            uint256 rewardsAvailable = rewards.availableRewards;
            uint256 rewardsPending = rewards.pendingRewards;

            assertEq(periodFinished, block.timestamp + 1 weeks);
            assertEq(rewardsAvailable, 2000 ether);
            assertEq(rewardsPending, 0);
        }
    }

    function test_Harvest() public {
        uint256 rewardSupply = 20 ether;
        uint256 aliceStake = 1000 ether;
        uint256 bobStake = 1000 ether;

        mockStakeupToken.mint(alice, aliceStake);
        mockStakeupToken.mint(bob, bobStake);
        mockStUSD.mint(address(stakeupStaking), rewardSupply);

        _processFees(rewardSupply / 2);

        _stake(alice, aliceStake);
        _stake(bob, bobStake);

        // Reverts if no rewards are available
        vm.startPrank(alice);
        vm.expectRevert(IStakeupStaking.NoRewardsToClaim.selector);
        stakeupStaking.harvest();
        vm.stopPrank();

        // Successfully harvests rewards
        skip(1 weeks);
        _processFees(rewardSupply / 2);

        {
            IStakeupStaking.RewardData memory rewardData = stakeupStaking.getRewardData();
            uint256 rewardRate = rewardData.rewardRate;
            uint96 rewardPerTokenStaked = rewardData.rewardPerTokenStaked;
            uint256 availableRewards = rewardData.availableRewards;

            assertEq(availableRewards, rewardSupply);
            assertEq(rewardRate, rewardSupply.divWad(1 weeks));
            assertEq(rewardPerTokenStaked, 0);
        }

        skip(3 days);
        mockStUSD.mint(address(stakeupStaking), 10 ether);
        _processFees(10 ether);

        uint256 aliceClaimableRewards = stakeupStaking.claimableRewards(alice);

        // Alice and BOB harvest equal rewards
        vm.startPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit RewardsHarvested(alice, aliceClaimableRewards);
        stakeupStaking.harvest();
        vm.stopPrank();

        assertEq(mockStUSD.balanceOf(alice), aliceClaimableRewards);
        assertEq(stakeupStaking.claimableRewards(alice), 0);

        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit RewardsHarvested(bob, aliceClaimableRewards);
        stakeupStaking.harvest();
        vm.stopPrank();

        assertEq(mockStUSD.balanceOf(alice), aliceClaimableRewards);
        assertEq(stakeupStaking.claimableRewards(alice), 0);

        // Skip to the end of the reward period and allow alice to claim the rest of her rewards
        skip(1 weeks);
        uint256 alice2Claim = stakeupStaking.claimableRewards(alice);

        vm.startPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit RewardsHarvested(alice, alice2Claim);
        stakeupStaking.harvest();
        vm.stopPrank();

        // Dust will be left over due to percision loss
        assertApproxEqRel(mockStUSD.balanceOf(alice), rewardSupply / 2, .99e18);
        assertEq(stakeupStaking.claimableRewards(alice), 0);

        // Bob claims his rewards
        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit RewardsHarvested(bob, alice2Claim);
        stakeupStaking.harvest();
        vm.stopPrank();
                
                
        // Dust will be left over due to percision loss
        assertApproxEqRel(mockStUSD.balanceOf(address(stakeupStaking)), 10 ether, .99e18);
        // Dont allow alice to claim more than she has been allocated
        skip(1 days);
        vm.startPrank(alice);
        vm.expectRevert(IStakeupStaking.NoRewardsToClaim.selector);
        stakeupStaking.harvest();
        vm.stopPrank();
    }

    function test_partialHarvest() public {
        uint256 rewardSupply = 20 ether;
        uint256 aliceStake = 1000 ether;

        mockStakeupToken.mint(alice, aliceStake);
        mockStUSD.mint(address(stakeupStaking), rewardSupply);
        
        skip(1 weeks);
        _processFees(rewardSupply);

        _stake(alice, aliceStake);

        skip(3 days);
        mockStUSD.mint(address(stakeupStaking), 10 ether);
        _processFees(10 ether);

        uint256 aliceRewards = stakeupStaking.claimableRewards(alice);

        // Alice claims half of her rewards
        vm.startPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit RewardsHarvested(alice, aliceRewards / 2);
        stakeupStaking.harvest(aliceRewards / 2);

        // Alice claims second half of rewards
        stakeupStaking.harvest(aliceRewards / 2);

    }

    function _stake(address user, uint256 amount) internal {
        vm.startPrank(user);
        mockStakeupToken.approve(address(stakeupStaking), amount);
        stakeupStaking.stake(amount);
        vm.stopPrank();
    }

    function _processFees(uint256 amount) internal {
        vm.startPrank(address(mockStUSD));
        stakeupStaking.processFees(amount);
        vm.stopPrank();
    }
}