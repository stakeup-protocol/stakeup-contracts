// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {Test} from "forge-std/Test.sol";
import {LibRLP} from "solady/utils/LibRLP.sol";

import {RewardManager, IRewardManager} from "src/rewards/RewardManager.sol";
import {ICurveGaugeDistributor} from "src/interfaces/ICurveGaugeDistributor.sol";

import {MockERC20} from "./mock/MockERC20.sol";
import {MockSUPVesting} from "./mock/MockSUPVesting.sol";
import {MockCurveFactory} from "./mock/Curve/MockCurveFactory.sol";

import {StakeupStaking} from "src/staking/StakeupStaking.sol";

contract RewardManagerTest is Test {
    RewardManager public rewardManager;
    MockERC20 public mockStUSD;
    MockERC20 public mockStakeupToken;
    MockSUPVesting public mockSUPVesting;
    MockCurveFactory public mockCurveFactory;
    StakeupStaking public stakeupStaking;

    uint256 constant MAX_POKE_REWARDS = 1_000_000_000e18 * 1e16 / 1e18;
    uint256 constant MAX_POOL_REWARDS = 1_000_000_000e18 * 2e17 / 1e18;
    uint256 constant MAX_MINT_REWARDS = 1_000_000_000e18 * 1e17 / 1e18;
    // Amount of stUSD that is eligible for minting rewards
    uint256 internal constant STUSD_MINT_THREASHOLD = 200_000_000e18;

    function setUp() public {
        mockStUSD = new MockERC20(18);
        mockStakeupToken = new MockERC20(18);
        mockSUPVesting = new MockSUPVesting();
        uint256 lpRewardsOne = MAX_POOL_REWARDS * 5e17 / 1e18;
        uint256 lpRewardsTwo = MAX_POOL_REWARDS * 25e16 / 1e18;
        uint256 lpRewardsThree = MAX_POOL_REWARDS * 25e16 / 1e18;
        ICurveGaugeDistributor.CurvePoolData[] memory curvePools = new ICurveGaugeDistributor.CurvePoolData[](3);

        mockCurveFactory = new MockCurveFactory();

        curvePools[0] = ICurveGaugeDistributor.CurvePoolData({
            curvePool: makeAddr("LP1"),
            curveGauge: address(0),
            curveFactory: address(mockCurveFactory),
            rewardsRemaining: lpRewardsOne,
            maxRewards: lpRewardsOne
        });

        curvePools[1] = ICurveGaugeDistributor.CurvePoolData({
            curvePool: makeAddr("LP2"),
            curveGauge: address(0),
            curveFactory: address(mockCurveFactory),
            rewardsRemaining: lpRewardsTwo,
            maxRewards: lpRewardsTwo
        });

        curvePools[2] = ICurveGaugeDistributor.CurvePoolData({
            curvePool: makeAddr("LP3"),
            curveGauge: address(0),
            curveFactory: address(mockCurveFactory),
            rewardsRemaining: lpRewardsThree,
            maxRewards: lpRewardsThree
        });

        stakeupStaking = new StakeupStaking(
            address(mockStakeupToken),
            address(mockSUPVesting),
            LibRLP.computeAddress(address(this), vm.getNonce(address(this)) + 1),
            address(mockStUSD)
        );

        rewardManager = new RewardManager(
            address(mockStUSD),
            address(mockStakeupToken),
            address(stakeupStaking),
            curvePools
        );
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
        uint256 year = 1;
        uint256 yearOneRewards = MAX_POKE_REWARDS * (1 - (1 / 2**year));

        uint256 expectedReward = 3 days * yearOneRewards / 365 days;
        
        // distribution succeeds if called by SUP
        vm.startPrank(address(mockStUSD));
        rewardManager.distributePokeRewards(address(this));
        vm.stopPrank();

        assertEq(mockStakeupToken.balanceOf(address(stakeupStaking)), expectedReward);
        
        uint256 amountStaked = stakeupStaking.getUserStakingData(address(this)).amountStaked;
        assertEq(amountStaked, expectedReward);
    }

    function test_SeedGauges() public {
        // Initialize the contract to deploy the gauges
        vm.startPrank(address(mockStakeupToken));
        rewardManager.initialize();
        vm.stopPrank();

        // Seed the gauges
        rewardManager.seedGauges();

        ICurveGaugeDistributor.CurvePoolData[] memory data =  rewardManager.getCurvePoolData();

        for (uint256 i = 0; i < data.length; i++) {
            uint256 week = 1 weeks;
            uint256 year = 1;
            uint256 yearOneRewards = data[i].maxRewards * (1 - (1 / 2**year));

            uint256 expectedReward = week * yearOneRewards / 365 days;

            assertEq(data[i].rewardsRemaining, data[i].maxRewards - expectedReward);
            assertEq(mockStakeupToken.balanceOf(data[i].curveGauge), expectedReward);
        }

        // Fail to seed the gauges if called too early
        skip(3 days);
        vm.expectRevert(ICurveGaugeDistributor.TooEarlyToSeed.selector);
        rewardManager.seedGauges();

        // Seed the gauges if called at the right time
        skip(4 days);
        // Seed the gauges
        rewardManager.seedGauges();
    }

    function test_DistributeMintRewards() public {
        // Initialize the contract to deploy the gauges
        vm.startPrank(address(mockStakeupToken));
        rewardManager.initialize();
        vm.stopPrank();

        // Fail to distribute rewards if not called by stUSD
        vm.expectRevert(IRewardManager.CallerNotStUsd.selector);
        rewardManager.distributeMintRewards(address(this), 1000e18);

        // Distribute rewards if called by stUSD
        vm.startPrank(address(mockStUSD));
        rewardManager.distributeMintRewards(address(this), 1000e18);
        vm.stopPrank();
        
        uint256 percentOfMax = 1000e18 * 1e18 / STUSD_MINT_THREASHOLD;

        uint256 expectedReward = MAX_MINT_REWARDS * percentOfMax / 1e18;

        assertEq(mockStakeupToken.balanceOf(address(stakeupStaking)), expectedReward);
        
        uint256 amountStaked = stakeupStaking.getUserStakingData(address(this)).amountStaked;
        assertEq(amountStaked, expectedReward);
    }
}