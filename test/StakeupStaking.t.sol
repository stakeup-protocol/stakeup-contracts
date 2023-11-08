// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";

import {StakeupStaking, IStakeupStaking} from "src/staking/StakeupStaking.sol";
import {MockERC20} from "./mock/MockERC20.sol";
import {MockSUPVesting} from "./mock/MockSUPVesting.sol";

contract StakeupTokenTest is Test {

    StakeupStaking public stakeupStaking;
    MockERC20 public mockStakeupToken;
    MockSUPVesting public mockSUPVesting;
    MockERC20 public mockStUSD;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    event StakeupStaked(address indexed user, uint256 amount);
    event StakeupUnstaked(address indexed user, uint256 amount);

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


    function _stake(address user, uint256 amount) internal {
        vm.startPrank(user);
        mockStakeupToken.approve(address(stakeupStaking), amount);
        stakeupStaking.stake(amount);
        vm.stopPrank();
    }
}