// // SPDX-License-Identifier: BUSL-1.1
// pragma solidity 0.8.26;

// import {Test} from "forge-std/Test.sol";
// import {LibRLP} from "solady/utils/LibRLP.sol";

// import {CurveGaugeDistributor, ICurveGaugeDistributor} from "src/rewards/CurveGaugeDistributor.sol";
// import {StakeUpErrors as Errors} from "src/helpers/StakeUpErrors.sol";

// import {MockERC20} from "../mocks/MockERC20.sol";
// import {MockCurveFactory} from "../mocks/Curve/MockCurveFactory.sol";

// import {StakeUpStaking} from "src/staking/StakeUpStaking.sol";

// contract CurveGaugeDistributorTest is Test {
//     CurveGaugeDistributor public curveGaugeDistributor;
//     MockERC20 public mockStTBY;
//     MockERC20 public mockStakeUpToken;
//     MockCurveFactory public mockCurveFactory;
//     StakeUpStaking public stakeupStaking;
//     uint256 public intializationTimestamp;
//     ICurveGaugeDistributor.CurvePoolData[] public curvePools;

//     uint256 internal constant DECIMAL_SCALING = 1e18;
//     uint256 constant MAX_POOL_REWARDS = 350_000_000e18;

//     function setUp() public {
//         mockStTBY = new MockERC20(18);
//         mockStakeUpToken = new MockERC20(18);
//         uint256 lpRewardsOne = (MAX_POOL_REWARDS * 2) / 4;
//         uint256 lpRewardsTwo = MAX_POOL_REWARDS / 4;
//         uint256 lpRewardsThree = MAX_POOL_REWARDS / 4;
//         mockCurveFactory = new MockCurveFactory();

//         curvePools.push(
//             ICurveGaugeDistributor.CurvePoolData({
//                 curvePool: makeAddr("LP1"),
//                 curveGauge: address(0),
//                 curveFactory: address(mockCurveFactory),
//                 rewardsRemaining: lpRewardsOne,
//                 maxRewards: lpRewardsOne
//             })
//         );

//         curvePools.push(
//             ICurveGaugeDistributor.CurvePoolData({
//                 curvePool: makeAddr("LP2"),
//                 curveGauge: address(0),
//                 curveFactory: address(mockCurveFactory),
//                 rewardsRemaining: lpRewardsTwo,
//                 maxRewards: lpRewardsTwo
//             })
//         );

//         curvePools.push(
//             ICurveGaugeDistributor.CurvePoolData({
//                 curvePool: makeAddr("LP3"),
//                 curveGauge: address(0),
//                 curveFactory: address(mockCurveFactory),
//                 rewardsRemaining: lpRewardsThree,
//                 maxRewards: lpRewardsThree
//             })
//         );

//         stakeupStaking = new StakeUpStaking(address(mockStakeUpToken), address(mockStTBY));

//         curveGaugeDistributor = new CurveGaugeDistributor(address(this));
//     }

//     function test_SeedGauges() public {
//         /// Fail to seed the gauges if the contract is not initialized
//         vm.expectRevert(Errors.NotInitialized.selector);
//         curveGaugeDistributor.seedGauges();

//         // Successfully initialize and seed the gauges
//         curveGaugeDistributor.initialize(curvePools, address(mockStakeUpToken));
//         intializationTimestamp = block.timestamp;
//         curveGaugeDistributor.seedGauges();

//         ICurveGaugeDistributor.CurvePoolData[] memory data = curveGaugeDistributor.getCurvePoolData();

//         for (uint256 i = 0; i < data.length; ++i) {
//             uint256 yearOneRewards = data[i].maxRewards / 2;

//             uint256 timeElapsed = block.timestamp - intializationTimestamp;
//             uint256 expectedReward = ((1 weeks + timeElapsed) * yearOneRewards) / 52 weeks;

//             assertEq(data[i].rewardsRemaining, data[i].maxRewards - expectedReward);
//             assertEq(mockStakeUpToken.balanceOf(data[i].curveGauge), expectedReward);
//         }

//         // Fail to seed the gauges if called too early
//         skip(3 days);
//         vm.expectRevert(Errors.TooEarlyToSeed.selector);
//         curveGaugeDistributor.seedGauges();

//         // Seed the gauges if called at the right time
//         skip(4 days);
//         // Seed the gauges
//         curveGaugeDistributor.seedGauges();
//     }
// }
