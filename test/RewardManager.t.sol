// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {LibRLP} from "solady/utils/LibRLP.sol";

import {RewardManager, IRewardManager} from "src/rewards/RewardManager.sol";

import {MockERC20} from "./mock/MockERC20.sol";
import {MockSUPVesting} from "./mock/MockSUPVesting.sol";

import {StakeupStaking} from "src/staking/StakeupStaking.sol";

contract RewardManagerTest is Test {
    RewardManager public rewardManager;
    MockERC20 public mockStUSD;
    MockERC20 public mockStakeupToken;
    MockSUPVesting public mockSUPVesting;

    StakeupStaking public stakeupStaking;
 
    uint256 constant MAX_POKE_REWARDS = 1_000_000_000e18 * 1e16 / 1e18;

    function setUp() public {
        mockStUSD = new MockERC20(18);
        mockStakeupToken = new MockERC20(18);
        mockSUPVesting = new MockSUPVesting();

        stakeupStaking = new StakeupStaking(
            address(mockStakeupToken),
            address(mockSUPVesting),
            LibRLP.computeAddress(address(this), vm.getNonce(address(this)) + 1),
            address(mockStUSD)
        );

        rewardManager = new RewardManager(address(mockStUSD), address(mockStakeupToken), address(stakeupStaking));
    }

    function test_Initialize() public {
        // initialization fails if not called by SUP
        vm.expectRevert(IRewardManager.CallerNotSUP.selector);
        rewardManager.initialize();

        // initialization succeeds if called by SUP
        vm.startPrank(address(mockStakeupToken));
        rewardManager.initialize();
        vm.stopPrank();
    }

    function test_DistributePokeRewards() public {
        // Call fails if not initialized
        vm.expectRevert(IRewardManager.NotInitialized.selector);
        rewardManager.distributePokeRewards(address(this));

        vm.startPrank(address(mockStakeupToken));
        rewardManager.initialize();
        vm.stopPrank();

        // distribution fails if not called by stUSD
        vm.expectRevert(IRewardManager.CallerNotStUsd.selector);
        rewardManager.distributePokeRewards(address(this));

        skip(3 days);
        uint256 yearsElapsed = block.timestamp / 365 days;

        uint256 expectedReward = MAX_POKE_REWARDS / (2**yearsElapsed);
        
        // distribution succeeds if called by SUP
        vm.startPrank(address(mockStUSD));
        rewardManager.distributePokeRewards(address(this));
        vm.stopPrank();

        assertEq(mockStakeupToken.balanceOf(address(stakeupStaking)), expectedReward);
        
        (uint256 amountStaked,,) = stakeupStaking.stakingData(address(this));
        assertEq(amountStaked, expectedReward);
    }

    
}