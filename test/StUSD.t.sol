// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";

import {StUSD, IERC20} from "src/token/StUSD.sol";
import {WstUSD} from "src/token/WstUSD.sol";
import {MockERC20} from "./mock/MockERC20.sol";
import {MockSwapFacility} from "./mock/MockSwapFacility.sol";
import {MockBloomPool} from "./mock/MockBloomPool.sol";
import "forge-std/console.sol";

contract StUSDTest is Test {
    StUSD internal stUSD;
    WstUSD internal wstUSD;

    MockERC20 internal stableToken;
    MockERC20 internal billyToken;
    MockSwapFacility internal swap;
    MockBloomPool internal pool;

    address internal owner = makeAddr("owner");
    address internal nonOwner = makeAddr("nonOwner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    bytes internal constant NOT_OWNER_ERROR =
        bytes("Ownable: caller is not the owner");

    // ============== Redefined Events ===============
    event TBYWhitelisted(address tby, bool whitelist);
    event Deposit(
        address indexed account,
        address tby,
        uint256 amount,
        uint256 shares
    );
    event Redeemed(address indexed account, uint256 shares, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);

    function setUp() public {
        stableToken = new MockERC20(6);
        vm.label(address(stableToken), "StableToken");
        billyToken = new MockERC20(18);
        vm.label(address(billyToken), "BillyToken");
        swap = new MockSwapFacility(stableToken, billyToken);
        vm.label(address(swap), "MockSwapFacility");

        pool = new MockBloomPool(
            address(stableToken),
            address(billyToken),
            address(swap),
            18
        );
        vm.label(address(pool), "MockBloomPool");

        vm.startPrank(owner);
        stUSD = new StUSD(address(stableToken));
        vm.label(address(stUSD), "StUSD");

        assertEq(stUSD.owner(), owner);
        assertEq(address(stUSD.underlyingToken()), address(stableToken));

        wstUSD = new WstUSD(address(stUSD));

        assertEq(address(wstUSD.stUSD()), address(stUSD));

        stUSD.setWstUSD(address(wstUSD));

        vm.stopPrank();
    }

    function whitelistTBY(address tby, bool whitelist) public {
        vm.prank(owner);
        stUSD.whitelistTBY(tby, whitelist);
    }

    function test_init_fail_with_InvalidAddress() public {
        vm.expectRevert(StUSD.InvalidAddress.selector);
        new StUSD(address(0));
    }

    function test_whitelistTBY_fail_with_InvalidAddress() public {
        vm.expectRevert(StUSD.InvalidAddress.selector);
        vm.prank(owner);
        stUSD.whitelistTBY(address(0), true);
    }

    function test_whitelistTBY_fail_with_nonOwner() public {
        vm.expectRevert(NOT_OWNER_ERROR);
        vm.prank(nonOwner);
        stUSD.whitelistTBY(address(pool), true);
    }

    function test_whitelistTBY_success() public {
        vm.expectEmit(true, true, true, true);
        vm.prank(owner);
        emit TBYWhitelisted(address(pool), true);
        stUSD.whitelistTBY(address(pool), true);
    }

    function test_deposit_fail_with_TBYNotWhitelisted() public {
        vm.expectRevert(StUSD.TBYNotWhitelisted.selector);
        vm.prank(alice);
        stUSD.deposit(address(pool), 1 ether);
    }

    function test_deposit_fail_with_InsufficientBalance() public {
        pool.mint(alice, 0.5 ether);
        whitelistTBY(address(pool), true);

        vm.startPrank(alice);
        pool.approve(address(stUSD), 1 ether);
        vm.expectRevert(bytes("ERC20: transfer amount exceeds balance"));
        stUSD.deposit(address(pool), 1 ether);
        vm.stopPrank();
    }

    function test_deposit_fail_with_InsufficientAllowance() public {
        pool.mint(alice, 1 ether);
        whitelistTBY(address(pool), true);

        vm.startPrank(alice);
        pool.approve(address(stUSD), 0.5 ether);
        vm.expectRevert(bytes("ERC20: insufficient allowance"));
        stUSD.deposit(address(pool), 1 ether);
        vm.stopPrank();
    }

    function test_deposit_success() public {
        pool.mint(alice, 1 ether);
        whitelistTBY(address(pool), true);

        vm.startPrank(alice);
        pool.approve(address(stUSD), 1 ether);
        vm.expectEmit(true, true, true, true);
        emit Deposit(alice, address(pool), 1 ether, 1 ether);
        stUSD.deposit(address(pool), 1 ether);
        vm.stopPrank();
    }

    function testFullFlow() public {
        pool.mint(alice, 1 ether);
        pool.mint(bob, 2 ether);
        whitelistTBY(address(pool), true);

        vm.startPrank(alice);
        pool.approve(address(stUSD), 1 ether);
        vm.expectEmit(true, true, true, true);
        emit Deposit(alice, address(pool), 1 ether, 1 ether);
        stUSD.deposit(address(pool), 1 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        pool.approve(address(stUSD), 2 ether);
        vm.expectEmit(true, true, true, true);
        emit Deposit(bob, address(pool), 2 ether, 2 ether);
        stUSD.deposit(address(pool), 2 ether);
        stUSD.approve(address(wstUSD), 2 ether);
        wstUSD.wrap(2 ether);
        vm.stopPrank();

        stableToken.mint(address(pool), 3_000000);
        swap.setRate(1e18);
        pool.initiatePreHoldSwap();
        swap.completeNextSwap();

        swap.setRate(1.1e18);
        pool.initiatePostHoldSwap();
        swap.completeNextSwap();

        vm.prank(owner);
        stUSD.setTotalUsd(3.3 ether);

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Redeemed(alice, 1 ether, 1.1 ether);
        stUSD.redeemStUSD(1.1 ether);
        vm.startPrank(bob);
        wstUSD.approve(address(stUSD), 2 ether);
        vm.expectEmit(true, true, true, true);
        emit Redeemed(bob, 2 ether, 2.2 ether);
        stUSD.redeemWstUSD(2 ether);
        vm.stopPrank();

        vm.prank(owner);
        stUSD.redeemUnderlying(address(pool), 3 ether);

        uint256 beforeAliceBalance = stableToken.balanceOf(alice);
        uint256 beforeBobBalance = stableToken.balanceOf(bob);

        vm.prank(alice);
        stUSD.withdraw();
        vm.prank(bob);
        stUSD.withdraw();

        uint256 afterAliceBalance = stableToken.balanceOf(alice);
        uint256 afterBobBalance = stableToken.balanceOf(bob);

        assertEq(afterAliceBalance, beforeAliceBalance + 1.1e6);
        assertEq(afterBobBalance, beforeBobBalance + 2.2e6);
    }
}
