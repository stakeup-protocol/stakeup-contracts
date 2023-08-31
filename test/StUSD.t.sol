// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";

import {StUSD, IERC20} from "src/token/StUSD.sol";
import {WstUSD} from "src/token/WstUSD.sol";
import {MockERC20} from "./mock/MockERC20.sol";
import {MockSwapFacility} from "./mock/MockSwapFacility.sol";
import {MockBloomPool} from "./mock/MockBloomPool.sol";

contract StUSDTest is Test {
    StUSD internal stUSD;
    WstUSD internal wstUSD;

    MockERC20 internal stableToken;
    MockERC20 internal billyToken;
    MockSwapFacility internal swap;
    MockBloomPool internal pool;

    address internal owner = makeAddr("owner");
    address internal nonOwner = makeAddr("nonOwner");
    address internal treasury = makeAddr("treasury");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    bytes internal constant NOT_OWNER_ERROR =
        bytes("Ownable: caller is not the owner");

    // ============== Redefined Events ===============
    event MintBpsUpdated(uint16 mintBps);
    event RedeemBpsUpdated(uint16 redeempBps);
    event TreasuryUpdated(address treasury);
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
        stUSD = new StUSD(address(stableToken), treasury);
        vm.label(address(stUSD), "StUSD");

        assertEq(stUSD.owner(), owner);
        assertEq(stUSD.treasury(), treasury);
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
        new StUSD(address(0), treasury);

        vm.expectRevert(StUSD.InvalidAddress.selector);
        new StUSD(address(stableToken), address(0));
    }

    function test_setMintBps_fail_with_ParameterOutOfBounds() public {
        vm.expectRevert(StUSD.ParameterOutOfBounds.selector);
        vm.prank(owner);
        stUSD.setMintBps(201);
    }

    function test_setMintBps_fail_with_nonOwner() public {
        vm.expectRevert(NOT_OWNER_ERROR);
        vm.prank(nonOwner);
        stUSD.setMintBps(100);
    }

    function test_setMintBps_success() public {
        vm.expectEmit(true, true, true, true);
        vm.prank(owner);
        emit MintBpsUpdated(100);
        stUSD.setMintBps(100);

        assertEq(stUSD.mintBps(), 100);
    }

    function test_setRedeemBps_fail_with_ParameterOutOfBounds() public {
        vm.expectRevert(StUSD.ParameterOutOfBounds.selector);
        vm.prank(owner);
        stUSD.setRedeemBps(201);
    }

    function test_setRedeemBps_fail_with_nonOwner() public {
        vm.expectRevert(NOT_OWNER_ERROR);
        vm.prank(nonOwner);
        stUSD.setRedeemBps(100);
    }

    function test_setRedeemBps_success() public {
        vm.expectEmit(true, true, true, true);
        vm.prank(owner);
        emit RedeemBpsUpdated(100);
        stUSD.setRedeemBps(100);

        assertEq(stUSD.redeemBps(), 100);
    }

    function test_setTreasury_fail_with_InvalidAddress() public {
        vm.expectRevert(StUSD.InvalidAddress.selector);
        vm.prank(owner);
        stUSD.setTreasury(address(0));
    }

    function test_setTreasury_fail_with_nonOwner() public {
        vm.expectRevert(NOT_OWNER_ERROR);
        vm.prank(nonOwner);
        stUSD.setTreasury(makeAddr("newTreasury"));
    }

    function test_setTreasury_success() public {
        vm.expectEmit(true, true, true, true);
        vm.prank(owner);
        address newTreasury = makeAddr("newTreasury");
        emit TreasuryUpdated(newTreasury);
        stUSD.setTreasury(newTreasury);

        assertEq(stUSD.treasury(), newTreasury);
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
        uint256 amount = 1.1 ether;
        uint256 fee = (amount * stUSD.mintBps()) / stUSD.BPS();
        pool.mint(alice, amount);
        whitelistTBY(address(pool), true);

        vm.startPrank(alice);
        pool.approve(address(stUSD), amount);
        vm.expectEmit(true, true, true, true);
        emit Deposit(alice, address(pool), amount - fee, amount - fee);
        stUSD.deposit(address(pool), amount);
        vm.stopPrank();

        assertEq(pool.balanceOf(treasury), fee);
        assertEq(stUSD.balanceOf(alice), amount - fee);
    }

    function testFullFlow() public {
        uint256 aliceAmount = 1 ether;
        uint256 bobAmount = 2 ether;
        pool.mint(alice, aliceAmount);
        pool.mint(bob, bobAmount);
        whitelistTBY(address(pool), true);

        uint256 aliceMintFee = (aliceAmount * stUSD.mintBps()) / stUSD.BPS();
        uint256 bobMintFee = (bobAmount * stUSD.mintBps()) / stUSD.BPS();
        uint256 aliceMintAmount = aliceAmount - aliceMintFee;
        uint256 bobMintAmount = bobAmount - bobMintFee;
        uint256 totalMintAmount = aliceMintAmount + bobMintAmount;

        vm.startPrank(alice);
        pool.approve(address(stUSD), aliceAmount);
        vm.expectEmit(true, true, true, true);
        emit Deposit(alice, address(pool), aliceMintAmount, aliceMintAmount);
        stUSD.deposit(address(pool), aliceAmount);
        vm.stopPrank();

        vm.startPrank(bob);
        pool.approve(address(stUSD), bobAmount);
        vm.expectEmit(true, true, true, true);
        emit Deposit(bob, address(pool), bobMintAmount, bobMintAmount);
        stUSD.deposit(address(pool), bobAmount);
        stUSD.approve(address(wstUSD), bobMintAmount);
        wstUSD.wrap(bobMintAmount);
        vm.stopPrank();

        assertEq(wstUSD.getWstUSDByStUSD(1 ether), 1 ether);
        assertEq(wstUSD.getStUSDByWstUSD(1 ether), 1 ether);
        assertEq(wstUSD.stUsdPerToken(), 1 ether);
        assertEq(wstUSD.tokensPerStUsd(), 1 ether);

        stableToken.mint(address(pool), 3_000000);
        swap.setRate(1e18);
        pool.initiatePreHoldSwap();
        swap.completeNextSwap();

        swap.setRate(1.1e18);
        pool.initiatePostHoldSwap();
        swap.completeNextSwap();

        vm.prank(owner);
        stUSD.setTotalUsd((totalMintAmount * 11) / 10); // 1.1x

        assertEq(wstUSD.getWstUSDByStUSD(1.1 ether), 1 ether);
        assertEq(wstUSD.getStUSDByWstUSD(1 ether), 1.1 ether);
        assertEq(wstUSD.stUsdPerToken(), 1.1 ether);
        assertEq(wstUSD.tokensPerStUsd(), 909090909090909090);

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Redeemed(alice, aliceMintAmount, (aliceMintAmount * 11) / 10);
        stUSD.redeemStUSD((aliceMintAmount * 11) / 10);
        vm.startPrank(bob);
        wstUSD.approve(address(stUSD), bobMintAmount);
        vm.expectEmit(true, true, true, true);
        emit Redeemed(bob, bobMintAmount, (bobMintAmount * 11) / 10);
        stUSD.redeemWstUSD(bobMintAmount);
        vm.stopPrank();

        vm.prank(owner);
        stUSD.redeemUnderlying(address(pool), 3 ether);

        uint256 beforeAliceBalance = stableToken.balanceOf(alice);
        uint256 beforeBobBalance = stableToken.balanceOf(bob);
        uint256 beforeTreasuryBalance = stableToken.balanceOf(treasury);

        vm.prank(alice);
        stUSD.withdraw();
        vm.prank(bob);
        stUSD.withdraw();

        uint256 afterAliceBalance = stableToken.balanceOf(alice);
        uint256 afterBobBalance = stableToken.balanceOf(bob);
        uint256 afterTreasuryBalance = stableToken.balanceOf(treasury);

        uint256 aliceWithdrawAmount = (aliceMintAmount * 11) / 10 / 1e12;
        uint256 aliceWithdrawFee = (aliceWithdrawAmount * stUSD.redeemBps()) /
            stUSD.BPS();
        uint256 bobWithdrawAmount = (bobMintAmount * 11) / 10 / 1e12;
        uint256 bobWithdrawFee = (bobWithdrawAmount * stUSD.redeemBps()) /
            stUSD.BPS();
        assertEq(
            afterAliceBalance,
            beforeAliceBalance + aliceWithdrawAmount - aliceWithdrawFee
        );
        assertEq(
            afterBobBalance,
            beforeBobBalance + bobWithdrawAmount - bobWithdrawFee
        );
        assertEq(
            afterTreasuryBalance,
            beforeTreasuryBalance + aliceWithdrawFee + bobWithdrawFee
        );
    }
}
