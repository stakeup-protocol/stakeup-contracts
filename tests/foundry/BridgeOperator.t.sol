// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";
import {EndpointV2} from "@LayerZero-Protocol/EndpointV2.sol";

import {BridgeOperator} from "src/messaging/BridgeOperator.sol";
import {StakeUpErrors as Errors} from "src/helpers/StakeUpErrors.sol";
import {StTBYSetup} from "./StTBYSetup.t.sol";

contract BridgeOperatorTest is StTBYSetup {
    BridgeOperator bridgeOperator;

    function setUp() public override {
        super.setUp();
        bridgeOperator = new BridgeOperator(address(stTBY), address(wstTBYBridge), owner);

        vm.startPrank(owner);
        // Set the delegate to the bridge operator
        stTBY.setDelegate(address(bridgeOperator));
        wstTBYBridge.setDelegate(address(bridgeOperator));

        // Set the bridge operator as the owner of all contracts
        stTBY.setBridgeOperator(address(bridgeOperator));
        wstTBYBridge.setBridgeOperator(address(bridgeOperator));

        // Renounce ownership of all contracts
        stTBY.renounceOwnership();
        wstTBYBridge.renounceOwnership();

        vm.stopPrank();
    }

    function test_ContractsOwnedByNoone() public {
        assertEq(stTBY.owner(), address(0));
        assertEq(wstTBYBridge.owner(), address(0));
    }

    function test_BridgeOperatorSet() public {
        assertEq(stTBY.getBridgeOperator(), address(bridgeOperator));
        assertEq(wstTBYBridge.getBridgeOperator(), address(bridgeOperator));
    }

    function test_SetWstTBYBridge() public {
        // Fails if not called by owner
        vm.startPrank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        bridgeOperator.setWstTBYBridge(1, address(wstTBYBridge));

        vm.startPrank(owner);
        // Fails if 0 address is passed
        vm.expectRevert(Errors.ZeroAddress.selector);
        bridgeOperator.setWstTBYBridge(1, address(0));

        // Successfully sets the bridge
        vm.startPrank(owner);
        bridgeOperator.setWstTBYBridge(1, address(wstTBYBridge));

        assertEq(wstTBYBridge.getBridgeByEid(1), address(wstTBYBridge));
    }

    function test_SetPeers() public {
        bytes32[3] memory peers =
            [addressToBytes32(address(1)), addressToBytes32(address(2)), addressToBytes32(address(3))];
        bytes32[3] memory invalidPeers =
            [addressToBytes32(address(0)), addressToBytes32(address(1)), addressToBytes32(address(1))];
        // Fails if not called by owner
        vm.startPrank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        bridgeOperator.setPeers(1, peers);

        vm.startPrank(owner);
        // Fails if 0 address is passed
        vm.expectRevert(Errors.ZeroAddress.selector);
        bridgeOperator.setPeers(1, invalidPeers);

        // Successfully sets the peer
        vm.startPrank(owner);
        bridgeOperator.setPeers(1, peers);

        assertEq(stTBY.peers(1), addressToBytes32(address(1)));
        assertEq(wstTBYBridge.peers(1), addressToBytes32(address(2)));
    }

    function test_UpdateDelegate() public {
        // Fails if not called by owner
        vm.startPrank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        bridgeOperator.updateDelegate(address(1));

        vm.startPrank(owner);
        // Fails if 0 address is passed
        vm.expectRevert(Errors.ZeroAddress.selector);
        bridgeOperator.updateDelegate(address(0));

        // Successfully sets the delegate
        vm.startPrank(owner);
        bridgeOperator.updateDelegate(address(1));

        assertEq(EndpointV2(address(stTBY.endpoint())).delegates(address(stTBY)), address(1));
        assertEq(EndpointV2(address(wstTBYBridge.endpoint())).delegates(address(wstTBYBridge)), address(1));
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}
