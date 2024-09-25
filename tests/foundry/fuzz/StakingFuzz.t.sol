// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {Test} from "forge-std/Test.sol";
import {FixedPointMathLib as FpMath} from "solady/utils/FixedPointMathLib.sol";

import {StakeUpErrors as Errors} from "src/helpers/StakeUpErrors.sol";
import {StakeUpConstants as Constants} from "src/helpers/StakeUpConstants.sol";

import {IStakeUpStaking} from "src/interfaces/IStakeUpStaking.sol";
import {StUsdcSetup} from "../StUsdcSetup.t.sol";

contract StakingFuzzTest is StUsdcSetup {
    using FpMath for uint256;

    function setUp() public override {
        super.setUp();
    }

    function test_Stake(uint256 amount) public {
        vm.assume(amount > 0 && amount < Constants.MAX_SUPPLY);
        _mintSup(alice, amount);

        vm.roll(block.number + 1);

        vm.startPrank(alice);
        supToken.approve(address(staking), amount);
        staking.stake(amount);

        IStakeUpStaking.StakingData memory stakingData = staking.userStakingData(alice);
        assertEq(stakingData.amountStaked, amount);
        assertEq(stakingData.rewardsAccrued, 0);
        assertEq(stakingData.index, 1);

        IStakeUpStaking.RewardData memory rewardData = staking.rewardData();
        assertEq(rewardData.index, 1);
        assertEq(rewardData.lastShares, 0);

        // validate balances
        assertEq(supToken.balanceOf(address(staking)), amount);
        assertEq(supToken.balanceOf(alice), 0);
    }

    function test_Unstake(uint256 amount) public {
        vm.assume(amount > 0 && amount < Constants.MAX_SUPPLY);
        _mintSup(alice, amount);

        vm.roll(block.number + 1);

        vm.startPrank(alice);
        supToken.approve(address(staking), amount);
        staking.stake(amount);

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1 days);
        staking.unstake(amount, true);

        IStakeUpStaking.StakingData memory stakingData = staking.userStakingData(alice);
        assertEq(stakingData.amountStaked, 0);
        assertEq(stakingData.rewardsAccrued, 0);
        assertEq(stakingData.index, 1);

        IStakeUpStaking.RewardData memory rewardData = staking.rewardData();
        assertEq(rewardData.index, 1);
        assertEq(rewardData.lastShares, 0);

        // validate balances
        assertEq(supToken.balanceOf(address(staking)), 0);
        assertEq(supToken.balanceOf(alice), amount);
    }

    function testFuzzProcessFees(uint256 rewardAmount, uint256 stakeAmount) public {
        rewardAmount = bound(rewardAmount, 1e18, 250_000_000e18);
        stakeAmount = bound(stakeAmount, 1e18, 300_000_000e18);

        _depositAsset(rando, rewardAmount);

        _mintSup(alice, stakeAmount);
        _stake(alice, stakeAmount);

        // send stUsdc to stakeUp to mimic fees
        vm.startPrank(rando);
        stUsdc.transfer(address(staking), rewardAmount);
        vm.stopPrank();

        uint256 rewardShares = stUsdc.sharesOf(address(staking));

        vm.roll(block.number + 1);
        vm.prank(address(stUsdc));
        staking.processFees();

        assertEq(staking.lastRewardBlock(), block.number);

        IStakeUpStaking.RewardData memory rewardData = staking.rewardData();
        assertEq(rewardData.index, rewardShares.divWad(stakeAmount) + 1);
        assertEq(rewardData.lastShares, rewardShares);
        assertEq(staking.lastRewardBlock(), block.number);

        // Check alices staking data and balances earned
        IStakeUpStaking.StakingData memory userStakingData = staking.userStakingData(alice);
        assertEq(userStakingData.amountStaked, stakeAmount);
        assertEq(userStakingData.index, 0);
        assertApproxEqRel(staking.claimableRewards(alice), rewardShares, 0.000000001e18);

        vm.roll(block.number + 50);
        // Have rando deposit stake and validate that it doesn't affect alices rewards
        _mintSup(rando, stakeAmount);
        _stake(rando, stakeAmount);

        assertEq(staking.userStakingData(alice).amountStaked, stakeAmount);
        assertApproxEqRel(staking.claimableRewards(alice), rewardShares, 0.000000001e18);

        // Validate that the rando does not have any rewards accrued
        IStakeUpStaking.StakingData memory randoStakingData = staking.userStakingData(rando);
        assertEq(randoStakingData.amountStaked, stakeAmount);
        assertEq(staking.claimableRewards(rando), 0);
    }

    function testFuzzHarvest(uint256 rewardAmount, uint256 stakeAmount) public {
        rewardAmount = bound(rewardAmount, 1e18, 250_000_000e18);
        stakeAmount = bound(stakeAmount, 1e18, 300_000_000e18);

        _depositAsset(rando, rewardAmount);

        _mintSup(alice, stakeAmount);
        _stake(alice, stakeAmount);

        // send stUsdc to stakeUp to mimic fees
        vm.startPrank(rando);
        stUsdc.transfer(address(staking), rewardAmount);
        vm.stopPrank();

        vm.roll(block.number + 2);
        vm.prank(address(stUsdc));
        staking.processFees();

        uint256 currentShares = stUsdc.sharesOf(address(staking));
        uint256 expectedRewards = staking.claimableRewards(alice);

        vm.roll(block.number + 2);
        vm.warp(block.timestamp + 1 days);
        vm.startPrank(alice);
        staking.harvest();

        staking.unstake(stakeAmount, true);

        assertEq(stUsdc.sharesOf(alice), expectedRewards);
        assertEq(stUsdc.sharesOf(address(staking)), currentShares - expectedRewards);
        assertEq(staking.claimableRewards(alice), 0);
    }

    function _mintSup(address user, uint256 amount) internal {
        vm.prank(owner);
        supToken.mint(user, amount);
    }

    function _mintAndVestSup(address user, uint256 amount) internal {
        vm.prank(owner);
        supToken.mintAndStartVest(user, amount);
    }

    function _stake(address user, uint256 amount) internal {
        vm.startPrank(user);
        supToken.approve(address(staking), amount);
        staking.stake(amount);
        vm.stopPrank();
    }
}
