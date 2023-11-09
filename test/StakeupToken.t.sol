// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {SUPVesting} from "src/token/SUPVesting.sol";
import {StakeupToken, IStakeupToken} from "src/token/StakeupToken.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {MockSUPVesting} from "./mock/MockSUPVesting.sol";
import {MockRewardManager} from "./mock/MockRewardManager.sol";

contract StakeupTokenTest is Test {
    StakeupToken public stakeupToken;
    IStakeupToken.Allocation[] public allocations;
    IStakeupToken.TokenRecipient[] public recipients;

    address internal alice;
    address internal bob;
    address internal rando;
    address internal owner;
    address internal layerZeroEndpoint;
    MockSUPVesting internal vestingContract;
    MockRewardManager internal rewardManager;

    uint64 initialMintPercentage = 1e15; // .01%

    function setUp() public {
        // Set variables
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        rando = makeAddr("rando");

        owner = makeAddr("owner");
        layerZeroEndpoint = makeAddr("layerZeroEndpoint");
        vestingContract = new MockSUPVesting();
        rewardManager = new MockRewardManager();
    }

    function testViewFunctions() public {
        uint256 expectedSupply = 1_000_000e18; // .01 * 1 billion
        
        // Alice is the only token recipient
        _deployOneAllocation(initialMintPercentage);
        
        assertEq(stakeupToken.name(), "Stakeup Token");
        assertEq(stakeupToken.symbol(), "SUP");
        assertEq(stakeupToken.token(), address(stakeupToken));

        assertEq(stakeupToken.sharedDecimals(), 6);
        assertEq(stakeupToken.decimals(), 18);

        assertEq(stakeupToken.totalSupply(), expectedSupply);
        assertEq(stakeupToken.circulatingSupply(), stakeupToken.totalSupply());
    }

    function testOwnership() public {        
        _deployOneAllocation(initialMintPercentage);
        assertEq(stakeupToken.owner(), owner);
    }

    function testSingleAllocationMint() public {
        uint256 expectedSupply = 1_000_000e18; // .01 * 1 billion
        _deployOneAllocation(initialMintPercentage);

        assertEq(stakeupToken.balanceOf(address(vestingContract)), expectedSupply);
    }

    function testMultiAllocationMint() public {
        uint256 expectedSupply = 1_000_000e18; // .01 * 1 billion

        // Alice and bob split the first allocation 50/50, rando gets the second allocation
        // Both allocations are 50% of the total supply
        _deployMultiAllocation(initialMintPercentage, false, false, false);

        assertEq(stakeupToken.balanceOf(address(vestingContract)), expectedSupply);
    }

    function testMintLpSupply() public {
        uint64 lpPercentage = 1e15; // .01%
        uint256 expectedSupply = 2_000_000e18; // .01 + .01 * 1 billion
        address lp1 = makeAddr("lp1");
        address lp2 = makeAddr("lp2");

        _deployOneAllocation(initialMintPercentage);

        IStakeupToken.TokenRecipient[] memory lpRecipients = new IStakeupToken.TokenRecipient[](2);
        lpRecipients[0] = IStakeupToken.TokenRecipient({
            recipient: lp1,
            percentOfAllocation: 5e17 // 50%
        });
        lpRecipients[1] = IStakeupToken.TokenRecipient({
            recipient: lp2,
            percentOfAllocation: 5e17 // 50%
        });

        IStakeupToken.Allocation[] memory lpAllocation = new IStakeupToken.Allocation[](1);
        lpAllocation[0] = IStakeupToken.Allocation({
            recipients: lpRecipients,
            percentOfSupply: lpPercentage // .01%
        });

        // Fails when caller is not owner
        vm.expectRevert("Ownable: caller is not the owner");
        stakeupToken.mintLpSupply(lpAllocation);

        // Mint the LP supply
        vm.startPrank(owner);
        stakeupToken.mintLpSupply(lpAllocation);
        vm.stopPrank();

        // Check that the LP supply was minted
        assertEq(stakeupToken.balanceOf(address(vestingContract)), expectedSupply);
        assertEq(stakeupToken.totalSupply(), expectedSupply);
        assertEq(stakeupToken.circulatingSupply(), expectedSupply);

    }

    function testAirdrop() public {
        uint64 airdropPercentage = 1e15; // .01%
        uint256 expectedSupply = 2_000_000e18; // .01 + .01 * 1 billion
        address airdrop1 = makeAddr("airdrop1");
        address airdrop2 = makeAddr("airdrop2");

        _deployOneAllocation(initialMintPercentage);

        IStakeupToken.TokenRecipient[] memory airdropRecipients = new IStakeupToken.TokenRecipient[](2);
        airdropRecipients[0] = IStakeupToken.TokenRecipient({
            recipient: airdrop1,
            percentOfAllocation: 5e17 // 50%
        });
        airdropRecipients[1] = IStakeupToken.TokenRecipient({
            recipient: airdrop2,
            percentOfAllocation: 5e17 // 50%
        });

        // Fails when caller is not owner
        vm.expectRevert("Ownable: caller is not the owner");
        stakeupToken.airdropTokens(airdropRecipients, airdropPercentage);

        // Mint the LP supply
        vm.startPrank(owner);
        stakeupToken.airdropTokens(airdropRecipients, airdropPercentage);
        vm.stopPrank();

        // Check that the LP supply was minted
        assertEq(stakeupToken.balanceOf(address(vestingContract)), expectedSupply / 2);
        assertEq(stakeupToken.balanceOf(airdrop1), 500_000e18);
        assertEq(stakeupToken.balanceOf(airdrop2), 500_000e18);
        assertEq(stakeupToken.totalSupply(), expectedSupply);
        assertEq(stakeupToken.circulatingSupply(), expectedSupply);
    }

    function testRevertZeroAddress() public {
        vm.expectRevert(IStakeupToken.InvalidRecipient.selector);
        _deployMultiAllocation(initialMintPercentage, true, false, false);
    }

    function testRevertExcessTokens() public {
        vm.expectRevert(IStakeupToken.ExceedsAvailableTokens.selector);
        _deployMultiAllocation(initialMintPercentage, false, true, false);
    }

    function testRevertNotFullyAllocated() public {
        vm.expectRevert(IStakeupToken.SharesNotFullyAllocated.selector);
        _deployMultiAllocation(initialMintPercentage, false, false, true);
    }

    function _deployOneAllocation(uint64 initialMintPercent) internal {

        IStakeupToken.TokenRecipient memory recipient = IStakeupToken.TokenRecipient({
            recipient: alice,
            percentOfAllocation: 1e18 // 100%
        });

        recipients.push(recipient);

        IStakeupToken.Allocation memory allocation = IStakeupToken.Allocation({
            recipients: recipients,
            percentOfSupply: initialMintPercent // .1%
        });

        allocations.push(allocation);

        stakeupToken = new StakeupToken(
            allocations,
            initialMintPercent, // .1%
            address(0),
            address(vestingContract),
            address(rewardManager),
            owner
        );
    }

    /**
     * 
     * @param initialMintPercent How much of the total supply to mint
     * @param zeroAddress True if we want to send a token to the zero address
     * @param excessTokens True if we want to try and mint excess tokens
     * @param notFullyAllocated True if we only want to partially allocate the tokens
     */
    function _deployMultiAllocation(
        uint64 initialMintPercent,
        bool zeroAddress,
        bool excessTokens,
        bool notFullyAllocated
    ) internal {
        uint64 percentPerAllocation = initialMintPercent / 2;
        uint64 aliceAllocation = 5e17;

        if (zeroAddress) {
            alice = address(0);
        }
        if (excessTokens) {
            aliceAllocation += 1e16;
        }
        if (notFullyAllocated) {
            aliceAllocation -= 1e16;
        }

        // First allocation
        IStakeupToken.TokenRecipient memory recipient1 = IStakeupToken.TokenRecipient({
            recipient: alice,
            percentOfAllocation: aliceAllocation
        });
        recipients.push(recipient1);
        IStakeupToken.TokenRecipient memory recipient2 = IStakeupToken.TokenRecipient({
            recipient: bob,
            percentOfAllocation: 5e17
        });
        recipients.push(recipient2);

        IStakeupToken.Allocation memory allocation1 = IStakeupToken.Allocation({
            recipients: recipients,
            percentOfSupply: percentPerAllocation
        });
        allocations.push(allocation1);

        IStakeupToken.TokenRecipient[] memory recipientsList2 = new IStakeupToken.TokenRecipient[](1);

        recipientsList2[0] = IStakeupToken.TokenRecipient({
            recipient: rando,
            percentOfAllocation: 1e18 // 100%
        });
        
        IStakeupToken.Allocation memory allocation2 = IStakeupToken.Allocation({
            recipients: recipientsList2,
            percentOfSupply: percentPerAllocation
        });
        allocations.push(allocation2);

        stakeupToken = new StakeupToken(
            allocations,
            initialMintPercent,
            address(0),
            address(vestingContract),
            address(rewardManager),
            owner
        );
    }

    function testMintRewards() public {
        uint256 expectedSupply = 1_000_001e18; // .01 * 1 billion + 1e18
        uint256 rewards = 1e18;
        _deployOneAllocation(initialMintPercentage);

        // Fails when caller is not reward manager
        vm.expectRevert(IStakeupToken.CallerNotRewardManager.selector);
        stakeupToken.mintRewards(address(this), rewards);

        // Mint rewards
        vm.startPrank(address(rewardManager));
        stakeupToken.mintRewards(address(rewardManager), rewards);
        vm.stopPrank();

        // Check that the LP supply was minted
        assertEq(stakeupToken.balanceOf(address(rewardManager)), rewards);
        assertEq(stakeupToken.totalSupply(), expectedSupply);
        assertEq(stakeupToken.circulatingSupply(), expectedSupply);
    }
}
