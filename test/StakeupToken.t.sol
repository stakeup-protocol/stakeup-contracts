// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {SUPVesting} from "src/token/SUPVesting.sol";
import {StakeupToken, IStakeupToken} from "src/token/StakeupToken.sol";

contract StakeupTokenTest is Test {
    StakeupToken public stakeupToken;
    IStakeupToken.Allocation[] public allocations;


    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal owner = makeAddr("owner");
    address internal layerZeroEndpoint = makeAddr("layerZeroEndpoint");
    address internal vestingContract = makeAddr("vestingContract");

    function _deployOneAllocation() internal {
        IStakeupToken.TokenRecipient[] memory recipients = new IStakeupToken.TokenRecipient[](1);
        recipients[1] = IStakeupToken.TokenRecipient({
            recipient: alice,
            percentOfAllocation: 1e8
        });

        allocations = new IStakeupToken.Allocation[](1);
        allocations[0] = IStakeupToken.Allocation({
            recipients: recipients,
            percentOfSupply: 10e8
        });

        stakeupToken = new StakeupToken(
            allocations,
            100,
            address(0),
            address(0),
            address(0)
        );
    }

    function testSingleAllocationMint() public {
        _deployOneAllocation();
        assertEq(stakeupToken.name(), "Stakeup Token");
        assertEq(stakeupToken.symbol(), "SUP");
        assertEq(stakeupToken.decimals(), 6);
        assertEq(stakeupToken.totalSupply(), 10e6);
        assertEq(stakeupToken.balanceOf(address(vestingContract)), 10e6);
    }

    function testOwnership() public {
        _deployOneAllocation();
        assertEq(stakeupToken.owner(), owner);
    }
    
}
