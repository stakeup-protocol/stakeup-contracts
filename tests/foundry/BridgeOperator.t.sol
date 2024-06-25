// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {Test} from "forge-std/Test.sol";
import {EndpointV2} from "@LayerZero-Protocol/EndpointV2.sol";

import {BridgeOperator} from "src/messaging/BridgeOperator.sol";
import {StakeUpErrors as Errors} from "src/helpers/StakeUpErrors.sol";
import {StTBYSetup} from "./StTBYSetup.t.sol";

contract BridgeOperatorTest is StTBYSetup {
    BridgeOperator bridgeOperator;

    function setUp() public override {
        super.setUp();
        bridgeOperator = new BridgeOperator(
            address(stTBY),
            address(wstTBYBridge),
            address(messenger),
            owner
        );

        vm.startPrank(owner);
        // Set the delegate to the bridge operator
        stTBY.setDelegate(address(bridgeOperator));
        wstTBYBridge.setDelegate(address(bridgeOperator));
        messenger.setDelegate(address(bridgeOperator));

        // Set the bridge operator as the owner of all contracts
        stTBY.setBridgeOperator(address(bridgeOperator));
        wstTBYBridge.setBridgeOperator(address(bridgeOperator));
        messenger.setBridgeOperator(address(bridgeOperator));

        // Renounce ownership of all contracts
        stTBY.renounceOwnership();
        wstTBYBridge.renounceOwnership();
        messenger.renounceOwnership();

        vm.stopPrank();
    }

    function test_ContractsOwnedByNoone() public {
        assertEq(stTBY.owner(), address(0));
        assertEq(wstTBYBridge.owner(), address(0));
        assertEq(messenger.owner(), address(0));
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
        // Fails if not called by owner
        vm.startPrank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        bridgeOperator.setPeers(1, addressToBytes32(address(1)));

        vm.startPrank(owner);
        // Fails if 0 address is passed
        vm.expectRevert(Errors.ZeroAddress.selector);
        bridgeOperator.setPeers(1, bytes32(0));

        // Successfully sets the peer
        vm.startPrank(owner);
        bridgeOperator.setPeers(1, addressToBytes32(address(1)));

        assertEq(stTBY.peers(1), addressToBytes32(address(1)));
        assertEq(stTBY.peerEids(0), 1);
        assertEq(wstTBYBridge.peers(1), addressToBytes32(address(1)));
        assertEq(messenger.peers(1), addressToBytes32(address(1)));
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

        assertEq(
            EndpointV2(address(stTBY.endpoint())).delegates(address(stTBY)),
            address(1)
        );
        assertEq(
            EndpointV2(address(wstTBYBridge.endpoint())).delegates(
                address(wstTBYBridge)
            ),
            address(1)
        );
        assertEq(
            EndpointV2(address(messenger.endpoint())).delegates(
                address(messenger)
            ),
            address(1)
        );
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}
