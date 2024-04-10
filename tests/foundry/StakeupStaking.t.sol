// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {Test} from "forge-std/Test.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {StakeupStaking, IStakeupStaking} from "src/staking/StakeupStaking.sol";
import {ILzBridgeConfig} from "src/interfaces/ILzBridgeConfig.sol";

import {ISUPVesting} from "src/interfaces/ISUPVesting.sol";
import {IStakeupStakingBase} from "src/interfaces/IStakeupStakingBase.sol";

import {MockERC20} from "../mocks/MockERC20.sol";

contract StakeupStakingTest is Test {
    using FixedPointMathLib for uint256;

    StakeupStaking public stakeupStaking;
    MockERC20 public mockStakeupToken;
    MockERC20 public mockStTBY;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 public vestAmount = 1_000_000e18;
    uint256 constant VESTING_DURATION = 3 * 52 weeks;

    event StakeupStaked(address indexed user, uint256 amount);
    event StakeupUnstaked(address indexed user, uint256 amount);
    event RewardsHarvested(address indexed user, uint256 shares);

    function setUp() public {
        mockStakeupToken = new MockERC20(18);
        vm.label(address(mockStakeupToken), "mockStakeupToken");

        mockStTBY = new MockERC20(18);
        vm.label(address(mockStTBY), "mockStTBY");

        stakeupStaking = new StakeupStaking(
           address(mockStakeupToken),
           address(mockStTBY),
           address(1111)
        );
        vm.label(address(stakeupStaking), "stakeupStaking");
    }

    function test_Stake() public {
        mockStakeupToken.mint(alice, 1000 ether);
        vm.roll(100);
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
        stakeupStaking.unstake(1000 ether, false);
        vm.stopPrank();

        _stake(alice, 1000 ether);

        vm.startPrank(alice);
        // Successful unstake but no harvest
        vm.expectEmit(true, true, true, true);
        emit StakeupUnstaked(alice, 1000 ether);
        stakeupStaking.unstake(1000 ether, false);

        assertEq(stakeupStaking.totalStakeUpStaked(), 0);
        assertEq(mockStakeupToken.balanceOf(address(stakeupStaking)), 0);
        assertEq(mockStakeupToken.balanceOf(alice), 1000 ether);
        vm.stopPrank();

        // unstakes the remaining stake if stake amount is greater than a users stake
        _stake(alice, 1000 ether);

        vm.startPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit StakeupUnstaked(alice, 1000 ether);
        stakeupStaking.unstake(2000 ether, false);
        vm.stopPrank();

        assertEq(stakeupStaking.totalStakeUpStaked(), 0);
        assertEq(mockStakeupToken.balanceOf(address(stakeupStaking)), 0);
        assertEq(mockStakeupToken.balanceOf(alice), 1000 ether);
    }

    function test_ProcessFees() public {
        uint256 rewardAmount = 2000 ether;
        mockStTBY.mint(address(stakeupStaking), rewardAmount);

        // Initial state of the contract
        assertEq(stakeupStaking.getLastRewardBlock(), block.number);
        assertEq(stakeupStaking.getRewardData().lastBalance, 0);
        assertEq(stakeupStaking.getRewardData().index, 0);      
        
        // Reverts if someone other than stTBY calls this function
        vm.startPrank(alice);
        vm.expectRevert(IStakeupStakingBase.UnauthorizedCaller.selector);
        ILzBridgeConfig.LZBridgeSettings memory settings;
        stakeupStaking.processFees(address(0), settings);
        vm.stopPrank();

        /// There must be some staked tokens in the contract to process fees
        uint256 aliceStake = 1000 ether;
        mockStakeupToken.mint(alice, aliceStake);
        _stake(alice, aliceStake);

        // Proper reward balance after fees are processed
        vm.roll(100);
        _processFees();
        assertEq(stakeupStaking.getLastRewardBlock(), block.number);
        assertEq(stakeupStaking.getRewardData().lastBalance, rewardAmount);
        assertEq(stakeupStaking.getRewardData().index, rewardAmount.divWad(aliceStake) + 1);
    }

    function test_Harvest() public {
        uint256 rewardSupply = 20 ether;
        uint256 aliceStake = 1000 ether;
        uint256 bobStake = 1000 ether;

        uint256 blockNumber = 100;

        mockStakeupToken.mint(alice, aliceStake);
        mockStakeupToken.mint(bob, bobStake);

        _stake(alice, aliceStake);
        _stake(bob, bobStake);

        vm.roll(blockNumber++);
        mockStTBY.mint(address(stakeupStaking), rewardSupply);
        _processFees();

        uint256 aliceClaimableRewards = stakeupStaking.claimableRewards(alice);
        
        // Alice and BOB harvest equal rewards
        vm.startPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit RewardsHarvested(alice, aliceClaimableRewards);
        stakeupStaking.harvest();
        vm.stopPrank();

        assertEq(mockStTBY.balanceOf(alice), aliceClaimableRewards);
        assertEq(stakeupStaking.claimableRewards(alice), 0);

        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit RewardsHarvested(bob, aliceClaimableRewards);
        stakeupStaking.harvest();
        vm.stopPrank();

        assertEq(mockStTBY.balanceOf(alice), aliceClaimableRewards);
        assertEq(stakeupStaking.claimableRewards(alice), 0);

        // No rewards left in the contract
        assertEq(mockStTBY.balanceOf(address(stakeupStaking)), 0 ether);

        // Dont allow alice to claim more than she has been allocated
        vm.roll(blockNumber++);
        vm.startPrank(alice);
        vm.expectRevert(IStakeupStaking.NoRewardsToClaim.selector);
        stakeupStaking.harvest();
        vm.stopPrank();

        // Unstake Bob and Alice
        _unstake(alice, aliceStake, true);
        _unstake(bob, bobStake, true);

        // Allow users who have tokens in the vesting contract to claim rewards
        address vestedUser = makeAddr("vestedUser");
        mockStakeupToken.mint(address(stakeupStaking), 1000 ether);
        vm.prank(address(mockStakeupToken));
        stakeupStaking.vestTokens(vestedUser, 1000 ether);
        vm.stopPrank();

        vm.roll(blockNumber++);
        mockStTBY.mint(address(stakeupStaking), rewardSupply);
        _processFees();

        // Since vestedUser is the only stake holder, they should be able to claim all the rewards
        uint256 vestedUser2Claim = stakeupStaking.claimableRewards(vestedUser);
        vm.startPrank(vestedUser);
        vm.expectEmit(true, true, true, true);
        emit RewardsHarvested(vestedUser, vestedUser2Claim);
        stakeupStaking.harvest();
        vm.stopPrank();

        assertEq(mockStTBY.balanceOf(address(vestedUser)), rewardSupply);
        assertEq(stakeupStaking.claimableRewards(vestedUser), 0);
    }
    
    function test_InvalidCaller() public {
        mockStakeupToken.mint(address(stakeupStaking), vestAmount); 
        vm.expectRevert(ISUPVesting.CallerNotSUP.selector);
        stakeupStaking.vestTokens(address(this), vestAmount);
    }

    function test_FullVestingFlow() public {
        uint256 elapsedTime = 0;
        mockStakeupToken.mint(address(stakeupStaking), vestAmount); 

        vm.startPrank(address(mockStakeupToken));
        stakeupStaking.vestTokens(alice, vestAmount);
        vm.stopPrank();

        assertEq(mockStakeupToken.balanceOf(address(stakeupStaking)), vestAmount);
        assertEq(mockStakeupToken.balanceOf(alice), 0);

        // Check initial view functions
        uint256 firstAliceBalance = stakeupStaking.getCurrentBalance(alice);
        assertEq(firstAliceBalance, vestAmount);
        assertEq(stakeupStaking.getAvailableTokens(alice), 0);

        // Add additional tokens to vesting contract
        uint256 addonAmount = 100e18;
        mockStakeupToken.mint(address(stakeupStaking), addonAmount);
        vm.startPrank(address(mockStakeupToken));
        stakeupStaking.vestTokens(alice, addonAmount);
        vm.stopPrank();

        uint256 newAliceBalance = stakeupStaking.getCurrentBalance(alice);

        assertEq(mockStakeupToken.balanceOf(address(stakeupStaking)), vestAmount + addonAmount);
        assertEq(mockStakeupToken.balanceOf(alice), 0);
        assertEq(newAliceBalance, vestAmount + addonAmount);

        // Fast Forward 30 days and check if available tokens are correct
        skip(4 weeks); 
        elapsedTime += 4 weeks;
        assertEq(stakeupStaking.getAvailableTokens(alice), 0);

        // Skip to the end of the cliff and check if available tokens are correct
        skip(48 weeks);
        elapsedTime += 48 weeks;
        uint256 expectedCliffBalance = (vestAmount + addonAmount) / 3;
        assertEq(stakeupStaking.getAvailableTokens(alice), expectedCliffBalance);

        // Skip to somewhere in the middle of the vesting period and check if available tokens are correct
        skip(100 days);
        elapsedTime += 100 days;

        uint256 expectedVestingBalance = (vestAmount + addonAmount) * elapsedTime / VESTING_DURATION;
        assertEq(stakeupStaking.getAvailableTokens(alice), expectedVestingBalance);

        // skip to past the end of the vesting period and check if available tokens are correct
        skip(2 * 52 weeks);
        assertEq(stakeupStaking.getAvailableTokens(alice), vestAmount + addonAmount);
    }

    function test_harvestAfterClaimingTokens() public {
        uint256 rewardSupply = 20 ether;
        uint256 blockNumber = 100;

        vm.roll(blockNumber++);
        skip(1 weeks);
        mockStTBY.mint(address(stakeupStaking), rewardSupply);
        _processFees();

        mockStakeupToken.mint(address(stakeupStaking), vestAmount); 

        vm.startPrank(address(mockStakeupToken));
        stakeupStaking.vestTokens(alice, vestAmount);
        vm.stopPrank();

        skip(104 weeks); // Skip 2 years. 2/3 of tokens should be available
        uint256 availableTokens = stakeupStaking.getAvailableTokens(alice);
        uint256 claimableRewards = stakeupStaking.claimableRewards(alice);

        // Remove tokens from vesting contract
        vm.startPrank(alice);
        stakeupStaking.claimAvailableTokens();

        assertEq(mockStakeupToken.balanceOf(address(alice)), availableTokens);
        assertEq(mockStTBY.balanceOf(address(alice)), claimableRewards);
    }

    function test_PersistentRewards(uint256 stakeAmount) public {
        vm.assume(stakeAmount > 1 ether);
        vm.assume(stakeAmount < 1000 ether);

        uint256 rewardSupply = 20 ether;
        uint256 aliceStake = stakeAmount;
        uint256 bobStake = stakeAmount;
        uint256 blockNumber = 100;

        mockStakeupToken.mint(alice, aliceStake);
        mockStakeupToken.mint(bob, bobStake);

        _stake(alice, aliceStake);
        _stake(bob, bobStake);

        mockStTBY.mint(address(stakeupStaking), rewardSupply);

        vm.roll(blockNumber++);
        _processFees();

        uint256 aliceRewards = stakeupStaking.claimableRewards(alice);
        uint256 bobRewards = stakeupStaking.claimableRewards(bob);

        assertEq(aliceRewards, bobRewards);

        assertEq(stakeupStaking.getRewardData().lastBalance, rewardSupply);

        // Alice claims her rewards
        vm.startPrank(alice);
        emit RewardsHarvested(alice, aliceRewards);
        stakeupStaking.harvest();

        // Ensure the rewardRate is properly adjusted after next fees are processed
        vm.roll(blockNumber++);
        mockStTBY.mint(address(stakeupStaking), rewardSupply);
        _processFees();

        uint256 aliceRewards2 = stakeupStaking.claimableRewards(alice);
        uint256 bobRewards2 = stakeupStaking.claimableRewards(bob);

        /* Delta is derived from alice having 1/2 of the first epoch
        and 1/4 of the second, vice versa */
        uint256 rewardDelta = (23 ether + 1 ether / 3) / (12 ether - 1 ether / 3);

        assertApproxEqAbs(rewardDelta * 1e18, (bobRewards2 * 1e18 / aliceRewards2), 100);
    }

    function test_RewardMultipleBlocks() public {
        uint256 rewardSupply = 20 ether;
        uint256 aliceStake = 1000 ether;
        uint256 bobStake = 1000 ether;
        uint256 startingBlock = 100;
        mockStakeupToken.mint(alice, aliceStake);
        mockStakeupToken.mint(bob, bobStake);

        _stake(alice, aliceStake);
        _stake(bob, bobStake);

        // Process 200 worth of rewards into the contract
        for (uint256 i = 0; i < 10; i++) {
            vm.roll(startingBlock += 100);
            mockStTBY.mint(address(stakeupStaking), rewardSupply);
            _processFees();
        }
    
        // Assert that 200 worth of rewards are available
        IStakeupStaking.RewardData memory rewards = stakeupStaking.getRewardData();
        assertEq(rewards.lastBalance , 200 ether);

        // Alice and Bob harvest equal rewards and that their combined rewards are equal to the available rewards
        uint256 aliceRewards = stakeupStaking.claimableRewards(alice);
        uint256 bobRewards = stakeupStaking.claimableRewards(bob);
        
        assertEq(aliceRewards + bobRewards, 200 ether);

        vm.startPrank(alice);
        stakeupStaking.harvest();

        vm.startPrank(bob);
        stakeupStaking.harvest();

        assertEq(mockStTBY.balanceOf(alice) + mockStTBY.balanceOf(bob), 200 ether);

    }

    function _stake(address user, uint256 amount) internal {
        vm.startPrank(user);
        mockStakeupToken.approve(address(stakeupStaking), amount);
        stakeupStaking.stake(amount);
        vm.stopPrank();
    }

    function _unstake(address user, uint256 amount, bool harvest) internal {
        vm.startPrank(user);
        stakeupStaking.unstake(amount, harvest);
        vm.stopPrank();
    }

    function _processFees() internal {
        vm.startPrank(address(mockStTBY));
        ILzBridgeConfig.LZBridgeSettings memory settings;
        stakeupStaking.processFees(address(0), settings);
        vm.stopPrank();
    }
}