// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {Test} from "forge-std/Test.sol";
import {FixedPointMathLib as FpMath} from "solady/utils/FixedPointMathLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {StakeUpErrors as Errors} from "src/helpers/StakeUpErrors.sol";
import {StakeUpConstants as Constants} from "src/helpers/StakeUpConstants.sol";

import {IStakeUpStaking} from "src/interfaces/IStakeUpStaking.sol";
import {StakeUpStaking} from "src/staking/StakeUpStaking.sol";

import {StUsdcSetup} from "../StUsdcSetup.t.sol";

contract StakingUnitTest is StUsdcSetup {
    using FpMath for uint256;

    function setUp() public override {
        super.setUp();
    }

    function test_depositTimelock() public {
        /// Mint SUP to alice
        vm.prank(owner);
        supToken.mint(alice, 100e18);

        // Have alice stake SUP
        vm.startPrank(alice);
        supToken.approve(address(staking), 100e18);
        staking.stake(100e18);
        vm.stopPrank();

        // Increment block number and send fees to StakeUp
        _depositAsset(rando, 50e18);
        vm.startPrank(rando);
        stUsdc.transfer(address(staking), 50e18);
        vm.stopPrank();

        vm.roll(block.number + 1);
        vm.prank(address(stUsdc));
        staking.processFees();

        // Fast forward to 23 hours after alice's deposit
        skip(23 hours);

        // Expect unstaking to fail
        vm.startPrank(alice);
        vm.expectRevert(Errors.Locked.selector);
        staking.unstake(100e18, false);

        // Fast forward to 25 hours after alice's deposit
        skip(2 hours);

        // Expect unstaking to succeed
        staking.unstake(100e18, true);

        // Expect alice's SUP to be unlocked
        assertEq(supToken.balanceOf(alice), 100e18);
        assertEq(stUsdc.balanceOf(alice), 50e18);
    }
}
