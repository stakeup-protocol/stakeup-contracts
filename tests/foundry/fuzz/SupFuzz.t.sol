// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";

import {StakeUpErrors as Errors} from "src/helpers/StakeUpErrors.sol";
import {StakeUpConstants as Constants} from "src/helpers/StakeUpConstants.sol";

import {StUsdcSetup} from "../StUsdcSetup.t.sol";

contract SupFuzzTest is StUsdcSetup {
    function setUp() public override {
        super.setUp();
    }

    function testFuzz_Mint(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(amount > 0 && amount <= Constants.MAX_SUPPLY);

        uint256 initialSupply = supToken.globalSupply();
        vm.prank(owner);
        supToken.mint(to, amount);

        assertEq(supToken.balanceOf(to), amount);
        assertEq(supToken.globalSupply(), initialSupply + amount);
    }

    function testFuzz_MintRevert(uint256 amount) public {
        vm.assume(amount > Constants.MAX_SUPPLY);

        vm.prank(owner);
        vm.expectRevert(Errors.ExceedsMaxSupply.selector);
        supToken.mint(address(this), amount);
    }

    function testFuzz_MintRewards(address recipient, uint256 amount) public {
        vm.assume(recipient != address(0));
        vm.assume(amount > 0 && amount <= Constants.MAX_SUPPLY);

        uint256 initialSupply = supToken.globalSupply();
        vm.prank(address(staking));
        supToken.mintRewards(recipient, amount);

        assertEq(supToken.balanceOf(recipient), amount);
        assertEq(supToken.globalSupply(), initialSupply + amount);
    }

    function testFuzz_MintAndStartVest(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(amount > 0 && amount <= Constants.MAX_SUPPLY);

        uint256 initialSupply = supToken.globalSupply();
        uint256 initialStakingBalance = supToken.balanceOf(address(staking));

        vm.prank(owner);
        supToken.mintAndStartVest(to, amount);

        // Check that the tokens were minted to the staking contract
        assertEq(supToken.balanceOf(address(staking)), initialStakingBalance + amount);

        // Check that the global supply increased
        assertEq(supToken.globalSupply(), initialSupply + amount);

        // Check that the vesting was started in the staking contract
        uint256 amountVesting = staking.currentBalance(to);
        assertEq(amountVesting, amount);
    }

    function testFuzz_MintAndStartVestRevert(uint256 amount) public {
        vm.assume(amount > Constants.MAX_SUPPLY);

        vm.prank(owner);
        vm.expectRevert(Errors.ExceedsMaxSupply.selector);
        supToken.mintAndStartVest(address(this), amount);
    }

    function testFuzz_MintRewardsUnauthorized(address caller, address recipient, uint256 amount) public {
        vm.assume(caller != address(staking) && caller != address(stUsdc));
        vm.assume(recipient != address(0));
        vm.assume(amount > 0);

        vm.prank(caller);
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        supToken.mintRewards(recipient, amount);
    }

    function testFuzz_GlobalSupply(uint256 mintAmount) public {
        vm.assume(mintAmount > 0 && mintAmount <= Constants.MAX_SUPPLY);

        uint256 initialSupply = supToken.globalSupply();
        vm.prank(owner);
        supToken.mint(address(this), mintAmount);

        assertEq(supToken.globalSupply(), initialSupply + mintAmount);
    }
}
