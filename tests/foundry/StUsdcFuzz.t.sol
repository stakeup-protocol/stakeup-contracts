// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

import {StakeUpErrors as Errors} from "src/helpers/StakeUpErrors.sol";
import {StUsdcSetup} from "./StUsdcSetup.t.sol";

contract StUsdcTest is StUsdcSetup {
    function setUp() public override {
        super.setUp();
    }

    function testFuzzDepositAsset(uint256 amount) public {
        amount = bound(amount, 1, 100e18);

        vm.prank(alice);
        // Mint and approve stableToken
        stableToken.mint(alice, amount);
        stableToken.approve(address(stUsdc), amount);

        // Deposit asset into stUsdc
        uint256 amountReceived = stUsdc.depositAsset(amount);
        uint256 expectedAmountReceived = amount * SCALER;

        // Validate invariants
        assertEq(amountReceived, expectedAmountReceived);
        assertEq(stUsdc.balanceOf(alice), expectedAmountReceived);
        assertEq(stUsdc.totalSupply(), expectedAmountReceived);
        assertEq(stUsdc.totalUsd(), expectedAmountReceived);
        assertEq(stUsdc.totalShares(), 1e18);
        assertEq(stUsdc.globalShares(), stUsdc.totalShares());
    }
}