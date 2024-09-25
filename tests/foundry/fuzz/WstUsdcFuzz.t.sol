// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {Test} from "forge-std/Test.sol";

import {StUsdcSetup} from "../StUsdcSetup.t.sol";

contract WstUsdcFuzzTest is StUsdcSetup {
    function setUp() public override {
        super.setUp();
    }

    function testFuzzDepositAsset(uint256 amount) public {
        amount = bound(amount, 1, 100_000_000_000e6);

        vm.startPrank(alice);
        stableToken.mint(alice, amount);
        stableToken.approve(address(wstUsdc), amount);
        wstUsdc.depositAsset(amount);

        uint256 scaledAmount = amount * SCALER;
        assertEq(stUsdc.balanceOf(address(wstUsdc)), scaledAmount);
        assertEq(wstUsdc.balanceOf(alice), stUsdc.sharesOf(address(wstUsdc)));
    }

    function testFuzzDepositTby(uint256 amount) public {
        amount = bound(amount, 1, 100_000_000_000e6);

        vm.startPrank(alice);
        stableToken.mint(alice, amount);
        stableToken.approve(address(bloomPool), amount);
        bloomPool.lendOrder(amount);
        bloomLenders[0] = alice;

        uint256 totalCollateral = _matchBloomOrder(alice, amount);
        uint256 id = _bloomStartNewTby(totalCollateral);

        vm.startPrank(alice);
        tby.setApprovalForAll(address(wstUsdc), true);
        wstUsdc.depositTby(id, amount);

        uint256 scaledAmount = amount * SCALER;

        assertEq(stUsdc.balanceOf(address(wstUsdc)), scaledAmount);
        assertEq(wstUsdc.balanceOf(alice), stUsdc.sharesOf(address(wstUsdc)));
    }

    function testFuzzWrap(uint256 amount) public {
        amount = bound(amount, 1, 100_000_000_000e6);

        vm.startPrank(alice);
        stableToken.mint(alice, amount);
        stableToken.approve(address(stUsdc), amount);
        stUsdc.depositAsset(amount);

        uint256 scaledAmount = amount * SCALER;

        stUsdc.approve(address(wstUsdc), scaledAmount);
        wstUsdc.wrap(scaledAmount);

        uint256 expectedBalance = stUsdc.sharesByUsd(scaledAmount);

        assertEq(stUsdc.balanceOf(address(wstUsdc)), scaledAmount);
        assertEq(wstUsdc.balanceOf(alice), stUsdc.sharesOf(address(wstUsdc)));
        assertEq(wstUsdc.balanceOf(alice), expectedBalance);
    }

    function testFuzzUnwrap(uint256 amount) public {
        amount = bound(amount, 1, 100_000_000_000e6);

        vm.startPrank(alice);
        stableToken.mint(alice, amount);
        stableToken.approve(address(stUsdc), amount);

        stUsdc.depositAsset(amount);

        uint256 scaledAmount = amount * SCALER;

        stUsdc.approve(address(wstUsdc), scaledAmount);
        wstUsdc.wrap(scaledAmount);
        wstUsdc.unwrap(scaledAmount);

        assertEq(stUsdc.balanceOf(address(wstUsdc)), 0);
        assertEq(wstUsdc.balanceOf(alice), 0);
        assertEq(stUsdc.balanceOf(alice), scaledAmount);
    }

    function testFuzzRedeem(uint256 amount) public {
        amount = bound(amount, 1, 100_000_000_000e6);

        vm.startPrank(alice);
        stableToken.mint(alice, amount);
        stableToken.approve(address(wstUsdc), amount);
        wstUsdc.depositAsset(amount);

        uint256 wstUsdcBalance = wstUsdc.balanceOf(alice);
        wstUsdc.redeemWstUsdc(wstUsdcBalance);

        assertEq(stUsdc.balanceOf(address(wstUsdc)), 0);
        assertEq(wstUsdc.balanceOf(alice), 0);
        assertEq(stableToken.balanceOf(alice), amount);
    }
}
