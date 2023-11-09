// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {SUPVesting, ISUPVesting} from "src/token/SUPVesting.sol";
import {IStakeupToken} from "src/interfaces/IStakeupToken.sol";
import {MockERC20} from "./mock/MockERC20.sol";

contract SUPVestingTest is Test {
    SUPVesting public supVesting;
    MockERC20 public mockSUP;

    uint256 public vestAmount = 1_000_000e18;
    address public alice = makeAddr("alice");

    uint256 constant VESTING_DURATION = 3 * 365 days;

    function setUp() public {
        mockSUP = new MockERC20(18);
        supVesting = new SUPVesting((address(mockSUP)));

        mockSUP.mint(address(supVesting), vestAmount);
    }

    function test_GetSUPAddress() public {
        assertEq(supVesting.getSUPToken(), address(mockSUP));
    }
    
    function test_InvalidCaller() public {
        vm.expectRevert(ISUPVesting.CallerNotSUP.selector);
        supVesting.vestTokens(address(this), vestAmount);
    }

    function test_FullFlow() public {
        uint256 elapsedTime = 0;

        vm.startPrank(address(mockSUP));
        supVesting.vestTokens(alice, vestAmount);
        vm.stopPrank();

        assertEq(mockSUP.balanceOf(address(supVesting)), vestAmount);
        assertEq(mockSUP.balanceOf(alice), 0);

        // Check initial view functions
        uint256 firstAliceBalance = supVesting.getCurrentBalance(alice);
        assertEq(firstAliceBalance, vestAmount);
        assertEq(supVesting.getAvailableTokens(alice), 0);

        // Add additional tokens to vesting contract
        uint256 addonAmount = 100e18;
        mockSUP.mint(address(supVesting), addonAmount);
        vm.startPrank(address(mockSUP));
        supVesting.vestTokens(alice, addonAmount);
        vm.stopPrank();

        uint256 newAliceBalance = supVesting.getCurrentBalance(alice);

        assertEq(mockSUP.balanceOf(address(supVesting)), vestAmount + addonAmount);
        assertEq(mockSUP.balanceOf(alice), 0);
        assertEq(newAliceBalance, vestAmount + addonAmount);

        // Fast Forward 30 days and check if available tokens are correct
        skip(30 days); 
        elapsedTime += 30 days;
        assertEq(supVesting.getAvailableTokens(alice), 0);

        // Skip to the end of the cliff and check if available tokens are correct
        skip(335 days);
        elapsedTime += 335 days;
        uint256 expectedCliffBalance = (vestAmount + addonAmount) / 3;
        assertEq(supVesting.getAvailableTokens(alice), expectedCliffBalance);

        // Skip to somewhere in the middle of the vesting period and check if available tokens are correct
        skip(100 days);
        elapsedTime += 100 days;

        uint256 expectedVestingBalance = (vestAmount + addonAmount) * elapsedTime / VESTING_DURATION;
        assertEq(supVesting.getAvailableTokens(alice), expectedVestingBalance);

        // skip to past the end of the vesting period and check if available tokens are correct
        skip(2 * 365 days);
        assertEq(supVesting.getAvailableTokens(alice), vestAmount + addonAmount);
    }
}
