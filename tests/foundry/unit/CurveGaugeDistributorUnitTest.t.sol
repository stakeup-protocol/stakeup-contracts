// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {StUsdcSetup} from "../StUsdcSetup.t.sol";
import {ICurveGaugeDistributor} from "src/rewards/CurveGaugeDistributor.sol";
import {ICurvePoolFactory} from "src/interfaces/curve/ICurvePoolFactory.sol";
import {IChildLiquidityGaugeFactory} from "src/interfaces/curve/IChildLiquidityGaugeFactory.sol";

contract CurveGaugeDistributorUnitTest is StUsdcSetup {
    ICurvePoolFactory public constant BASE_CURVE_FACTORY = ICurvePoolFactory(0xd2002373543Ce3527023C75e7518C274A51ce712);
    IChildLiquidityGaugeFactory public constant BASE_CURVE_GAUGE_FACTORY =
        IChildLiquidityGaugeFactory(0xabC000d88f23Bb45525E447528DBF656A9D55bf5);

    ICurveGaugeDistributor.CurvePoolData[] public curvePools;
    address public stUsdcStablePool;
    address public stUsdcStableGauge;
    uint256 public initializationTimestamp;

    function setUp() public override {
        string memory rpcUrl = vm.envString("BASE_RPC_URL");
        vm.createSelectFork(rpcUrl);
        super.setUp();
        assertEq(block.chainid, 8453);

        stUsdcStablePool = _deployCurvePool("stUSDC/USDC Pool", "stUsdc-Lp", address(stUsdc), address(stableToken));

        curvePools.push(
            ICurveGaugeDistributor.CurvePoolData({
                curvePool: stUsdcStablePool,
                curveGauge: address(0),
                gaugeFactory: address(BASE_CURVE_GAUGE_FACTORY),
                rewardsRemaining: 350_000_000e18,
                maxRewards: 350_000_000e18
            })
        );

        vm.startPrank(owner);
        initializationTimestamp = block.timestamp;
        curveGaugeDistributor.initialize(curvePools, address(supToken));
        vm.stopPrank();
    }

    function testGaugeDeployment() public {
        address curveGauge = curveGaugeDistributor.curvePoolData()[0].curveGauge;
        assertTrue(curveGauge != address(0));
    }

    function test_SeedGauges() public {
        // Skip some time
        skip(1 weeks);

        // Seed the gauges
        curveGaugeDistributor.seedGauges();

        // Check the results
        ICurveGaugeDistributor.CurvePoolData[] memory updatedPools = curveGaugeDistributor.curvePoolData();

        for (uint256 i = 0; i < updatedPools.length; ++i) {
            uint256 yearOneRewards = updatedPools[i].maxRewards / 2;

            uint256 timeElapsed = block.timestamp - initializationTimestamp;
            uint256 expectedReward = ((timeElapsed) * yearOneRewards) / 52 weeks;

            assertEq(updatedPools[i].rewardsRemaining, updatedPools[i].maxRewards - expectedReward);
            assertEq(supToken.balanceOf(updatedPools[i].curveGauge), expectedReward);
        }
    }

    function _deployCurvePool(string memory _name, string memory _symbol, address _stUsdc, address _stableToken)
        internal
        returns (address)
    {
        address[] memory coins = new address[](2);
        coins[0] = _stUsdc; // asset type 2 b/c of rebasing
        coins[1] = _stableToken; // asset type 0

        uint8[] memory assetTypes = new uint8[](2);
        assetTypes[0] = 2;
        assetTypes[1] = 0;

        bytes4[] memory methodIds = new bytes4[](2);
        methodIds[0] = bytes4(0);
        methodIds[1] = bytes4(0);

        address[] memory oracles = new address[](2);
        oracles[0] = address(0);
        oracles[1] = address(0);

        return BASE_CURVE_FACTORY.deploy_plain_pool(
            _name,
            _symbol,
            coins,
            100, // Amplification coefficient
            10000000, // Fee 0.04%
            2, // Off-peg fee multiplier
            866, // ma_ex_time
            0, // impl
            assetTypes,
            methodIds,
            oracles
        );
    }

    // Arbitrum/any L2s must use the Curve.fi ChildLiquidityGaugeFactory to deploy gauges. Mainnet can use the pool factory directly.
    function _deployCurveGauge(address _pool) internal returns (address) {
        return BASE_CURVE_GAUGE_FACTORY.deploy_gauge(_pool, bytes32("StakeUp | Global Savings"));
    }
}
