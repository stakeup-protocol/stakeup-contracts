// // SPDX-License-Identifier: BUSL-1.1
// pragma solidity 0.8.26;

// import {Test} from "forge-std/Test.sol";

// import {StakeUpStaking} from "src/staking/StakeUpStaking.sol";
// import {StakeUpToken, IStakeUpToken} from "src/token/StakeUpToken.sol";
// import {StakeUpErrors as Errors} from "src/helpers/StakeUpErrors.sol";

// import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// import {MockEndpoint} from "../mocks/MockEndpoint.sol";
// import {MockStakeUpStaking} from "../mocks/MockStakeUpStaking.sol";

// contract StakeUpTokenTest is Test {
//     StakeUpToken public stakeupToken;

//     address internal alice;
//     address internal bob;
//     address internal rando;
//     address internal owner;
//     address internal stTBY;
//     address internal layerZeroEndpoint;

//     MockEndpoint internal layerZeroEndpointA;
//     MockEndpoint internal layerZeroEndpointB;
//     uint32 internal constant EID_A = 1;
//     uint32 internal constant EID_B = 2;

//     MockStakeUpStaking internal stakeupStaking;

//     uint64 initialMintPercentage = 1e15; // .01%

//     function setUp() public {
//         // Set variables
//         alice = makeAddr("alice");
//         bob = makeAddr("bob");
//         rando = makeAddr("rando");
//         stTBY = makeAddr("stTBY");

//         owner = makeAddr("owner");
//         layerZeroEndpoint = makeAddr("layerZeroEndpoint");
//         stakeupStaking = new MockStakeUpStaking();
//         stakeupStaking.setStTBY(stTBY);

//         layerZeroEndpointA = new MockEndpoint();
//         layerZeroEndpointB = new MockEndpoint();
//     }

//     function testViewFunctions() public {
//         uint256 expectedSupply = 1_000_000e18; // .01 * 1 billion

//         // Alice is the only token recipient
//         _deployOneAllocation(initialMintPercentage);

//         assertEq(stakeupToken.name(), "StakeUp Token");
//         assertEq(stakeupToken.symbol(), "SUP");
//         assertEq(stakeupToken.token(), address(stakeupToken));

//         //assertEq(stakeupToken.sharedDecimals(), 6);
//         assertEq(stakeupToken.decimals(), 18);

//         assertEq(stakeupToken.totalSupply(), expectedSupply);
//     }

//     function testOwnership() public {
//         _deployOneAllocation(initialMintPercentage);
//         assertEq(stakeupToken.owner(), owner);
//     }

//     function testSingleAllocationMint() public {
//         uint256 expectedSupply = 1_000_000e18; // .01 * 1 billion
//         _deployOneAllocation(initialMintPercentage);

//         assertEq(stakeupToken.balanceOf(address(stakeupStaking)), expectedSupply);
//     }

//     function testMultiAllocationMint() public {
//         uint256 expectedSupply = 1_000_000e18; // .01 * 1 billion

//         // Alice and bob split the first allocation 50/50, rando gets the second allocation
//         // Both allocations are 50% of the total supply
//         _deployMultiAllocation(initialMintPercentage, false, false, false, bytes4(0));

//         assertEq(stakeupToken.balanceOf(address(stakeupStaking)), expectedSupply);
//     }

//     function testMintLpSupply() public {
//         uint64 lpPercentage = 1e15; // .01%
//         uint256 expectedSupply = 2_000_000e18; // .01 + .01 * 1 billion
//         address lp1 = makeAddr("lp1");
//         address lp2 = makeAddr("lp2");

//         _deployOneAllocation(initialMintPercentage);

//         IStakeUpToken.TokenRecipient[] memory lpRecipients = new IStakeUpToken.TokenRecipient[](2);
//         lpRecipients[0] = IStakeUpToken.TokenRecipient({
//             recipient: lp1,
//             percentOfAllocation: 5e17 // 50%
//         });
//         lpRecipients[1] = IStakeUpToken.TokenRecipient({
//             recipient: lp2,
//             percentOfAllocation: 5e17 // 50%
//         });

//         IStakeUpToken.Allocation[] memory lpAllocation = new IStakeUpToken.Allocation[](1);
//         lpAllocation[0] = IStakeUpToken.Allocation({
//             recipients: lpRecipients,
//             percentOfSupply: lpPercentage // .01%
//         });

//         // Fails when caller is not owner
//         vm.expectRevert("Ownable: caller is not the owner");
//         stakeupToken.mintLpSupply(lpAllocation);

//         // Mint the LP supply
//         vm.startPrank(owner);
//         stakeupToken.mintLpSupply(lpAllocation);
//         vm.stopPrank();

//         // Check that the LP supply was minted
//         assertEq(stakeupToken.balanceOf(address(stakeupStaking)), expectedSupply);
//         assertEq(stakeupToken.totalSupply(), expectedSupply);
//     }

//     function testAirdrop() public {
//         uint64 airdropPercentage = 1e15; // .01%
//         uint256 expectedSupply = 2_000_000e18; // .01 + .01 * 1 billion
//         address airdrop1 = makeAddr("airdrop1");
//         address airdrop2 = makeAddr("airdrop2");

//         _deployOneAllocation(initialMintPercentage);

//         IStakeUpToken.TokenRecipient[] memory airdropRecipients = new IStakeUpToken.TokenRecipient[](2);
//         airdropRecipients[0] = IStakeUpToken.TokenRecipient({
//             recipient: airdrop1,
//             percentOfAllocation: 5e17 // 50%
//         });
//         airdropRecipients[1] = IStakeUpToken.TokenRecipient({
//             recipient: airdrop2,
//             percentOfAllocation: 5e17 // 50%
//         });

//         // Fails when caller is not owner
//         vm.expectRevert("Ownable: caller is not the owner");
//         stakeupToken.airdropTokens(airdropRecipients, airdropPercentage);

//         // Mint the LP supply
//         vm.startPrank(owner);
//         stakeupToken.airdropTokens(airdropRecipients, airdropPercentage);
//         vm.stopPrank();

//         // Check that the LP supply was minted
//         assertEq(stakeupToken.balanceOf(address(stakeupStaking)), expectedSupply / 2);
//         assertEq(stakeupToken.balanceOf(airdrop1), 500_000e18);
//         assertEq(stakeupToken.balanceOf(airdrop2), 500_000e18);
//         assertEq(stakeupToken.totalSupply(), expectedSupply);
//     }

//     function testRevertZeroAddress() public {
//         _deployMultiAllocation(initialMintPercentage, true, false, false, Errors.InvalidRecipient.selector);
//     }

//     function testRevertExcessTokens() public {
//         _deployMultiAllocation(initialMintPercentage, false, true, false, Errors.ExceedsAvailableTokens.selector);
//     }

//     function testRevertNotFullyAllocated() public {
//         _deployMultiAllocation(initialMintPercentage, false, false, true, Errors.SharesNotFullyAllocated.selector);
//     }

//     function _deployOneAllocation(uint64 initialMintPercent) internal {
//         IStakeUpToken.TokenRecipient memory recipient = IStakeUpToken.TokenRecipient({
//             recipient: alice,
//             percentOfAllocation: 1e18 // 100%
//         });
//         IStakeUpToken.TokenRecipient[] memory recipients = new IStakeUpToken.TokenRecipient[](1);

//         recipients[0] = recipient;

//         IStakeUpToken.Allocation memory allocation = IStakeUpToken.Allocation({
//             recipients: recipients,
//             percentOfSupply: initialMintPercent // .1%
//         });

//         IStakeUpToken.Allocation[] memory allocations = new IStakeUpToken.Allocation[](1);

//         allocations[0] = allocation;

//         stakeupToken = new StakeUpToken(address(stakeupStaking), address(0), owner, address(layerZeroEndpointA), owner);

//         vm.startPrank(owner);
//         stakeupToken.mintInitialSupply(allocations, initialMintPercent);
//         vm.stopPrank();
//     }

//     /**
//      *
//      * @param initialMintPercent How much of the total supply to mint
//      * @param zeroAddress True if we want to send a token to the zero address
//      * @param excessTokens True if we want to try and mint excess tokens
//      * @param notFullyAllocated True if we only want to partially allocate the tokens
//      * @param expectedRevert The selector of the expected revert
//      */
//     function _deployMultiAllocation(
//         uint64 initialMintPercent,
//         bool zeroAddress,
//         bool excessTokens,
//         bool notFullyAllocated,
//         bytes4 expectedRevert
//     ) internal {
//         uint64 percentPerAllocation = initialMintPercent / 2;
//         uint64 aliceAllocation = 5e17;

//         if (zeroAddress) {
//             alice = address(0);
//         }
//         if (excessTokens) {
//             aliceAllocation += 1e16;
//         }
//         if (notFullyAllocated) {
//             aliceAllocation -= 1e16;
//         }

//         IStakeUpToken.TokenRecipient[] memory recipientsList1 = new IStakeUpToken.TokenRecipient[](2);
//         IStakeUpToken.TokenRecipient[] memory recipientsList2 = new IStakeUpToken.TokenRecipient[](1);

//         IStakeUpToken.Allocation[] memory allocations = new IStakeUpToken.Allocation[](2);

//         {
//             // First allocation
//             IStakeUpToken.TokenRecipient memory recipient1 =
//                 IStakeUpToken.TokenRecipient({recipient: alice, percentOfAllocation: aliceAllocation});
//             recipientsList1[0] = recipient1;
//             IStakeUpToken.TokenRecipient memory recipient2 =
//                 IStakeUpToken.TokenRecipient({recipient: bob, percentOfAllocation: 5e17});
//             recipientsList1[1] = recipient2;

//             IStakeUpToken.Allocation memory allocation1 =
//                 IStakeUpToken.Allocation({recipients: recipientsList1, percentOfSupply: percentPerAllocation});

//             allocations[0] = allocation1;

//             recipientsList2[0] = IStakeUpToken.TokenRecipient({
//                 recipient: rando,
//                 percentOfAllocation: 1e18 // 100%
//             });

//             IStakeUpToken.Allocation memory allocation2 =
//                 IStakeUpToken.Allocation({recipients: recipientsList2, percentOfSupply: percentPerAllocation});
//             allocations[1] = allocation2;

//             stakeupToken =
//                 new StakeUpToken(address(stakeupStaking), address(stTBY), owner, address(layerZeroEndpointA), owner);
//         }

//         vm.startPrank(owner);
//         if (expectedRevert != bytes4(0)) {
//             vm.expectRevert(expectedRevert);
//             stakeupToken.mintInitialSupply(allocations, initialMintPercent);
//         } else {
//             stakeupToken.mintInitialSupply(allocations, initialMintPercent);
//         }
//         vm.stopPrank();
//     }

//     function testMintRewards() public {
//         uint256 expectedSupply = 1_000_001e18; // .01 * 1 billion + 1e18
//         uint256 rewards = 1e18;
//         _deployOneAllocation(initialMintPercentage);

//         // Fails when caller is not reward manager
//         vm.expectRevert(Errors.UnauthorizedCaller.selector);
//         stakeupToken.mintRewards(address(this), rewards);

//         // Mint rewards
//         vm.startPrank(address(stTBY));
//         stakeupToken.mintRewards(address(stTBY), rewards);
//         vm.stopPrank();

//         // Check that the LP supply was minted
//         assertEq(stakeupToken.balanceOf(address(stTBY)), rewards);
//         assertEq(stakeupToken.totalSupply(), expectedSupply);
//     }
// }
