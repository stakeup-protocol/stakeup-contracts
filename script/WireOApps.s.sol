// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console2} from "forge-std/Script.sol";
import {LibRLP} from "solady/utils/LibRLP.sol";
import {OFT, ERC20} from "@LayerZero/oft/OFT.sol";

import {StTBYBase} from "src/token/StTBYBase.sol";
import {WstTBYBase} from "src/token/WstTBYBase.sol";
import {StakeUpMessenger} from "src/messaging/StakeUpMessenger.sol";
import {StakeUpTokenLite} from "src/token/StakeUpTokenLite.sol";
import {WstTBYBridge} from "src/messaging/WstTBYBridge.sol";
import {BridgeOperator} from "src/messaging/BridgeOperator.sol";
import {StakeUpToken} from "src/token/StakeUpToken.sol";

contract WireOAppsScript is Script {
    address public USDC_ARB_SEP = 0x52bFe207B9FBd8E703edD40a266130fd44C559db;
    address public BIB01_ARB_SEP = 0x50868a9E0C576bea3aFe97e4b8b1f9E18aa8095d;
    uint256 public LAYER_ZERO_EID_ARB_SEP = 40231;
    address public LAYER_ZERO_ENDPOINT_ARB_SEP =
        0x6EDCE65403992e310A62460808c4b910D972f10f;

    uint256 public LAYER_ZERO_EID_BASE_SEP = 40245;
    address public LAYER_ZERO_ENDPOINT_BASE_SEP =
        0x6EDCE65403992e310A62460808c4b910D972f10f;

    uint256 public LAYER_ZERO_EID_SEP = 40161;
    address public LAYER_ZERO_ENDPOINT_SEP =
        0x6EDCE65403992e310A62460808c4b910D972f10f;

    bytes32[3] basePeers;
    bytes32[3] sepPeers;
    bytes32[3] arbPeers;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address owner = 0x263c0a1ff85604f0ee3f4160cAa445d0bad28dF7;

        BridgeOperator operator = BridgeOperator(
            0xb1F14EBD8188441d2527E72913b71FFcF45585b1
        );
        operator.setWstTBYBridge(
            uint32(LAYER_ZERO_EID_SEP),
            0xd2FC5AA33D9825ad5664Ca6742b8e0a70029AA63
        );
        operator.setWstTBYBridge(
            uint32(LAYER_ZERO_EID_ARB_SEP),
            0xca7aE3BB3389e0Ddc22d0f9bFcB7DFa8fdFEF81B
        );

        basePeers[0] = addressToBytes32(
            0x68997637aa6657295B60edF9ab8C16310B9717A5
        );
        basePeers[1] = addressToBytes32(
            0x120b677acd511A15992d7E09BC37be9dF46d8Ac6
        );
        basePeers[2] = addressToBytes32(
            0x1E41135733611eB4068fACb0e233B8d7d9d60CEB
        );

        sepPeers[0] = addressToBytes32(
            0xb4E9a3d383dC174B479b805f141595c44Dd1562D
        );
        sepPeers[1] = addressToBytes32(
            0xd2FC5AA33D9825ad5664Ca6742b8e0a70029AA63
        );
        sepPeers[2] = addressToBytes32(
            0xd06fc810D15f11f32B576e3f4F89C44aC9c3D366
        );

        arbPeers[0] = addressToBytes32(
            0xE274423b1d8d32C485cFC08FEbfD88247149b49d
        );
        arbPeers[1] = addressToBytes32(
            0xca7aE3BB3389e0Ddc22d0f9bFcB7DFa8fdFEF81B
        );
        arbPeers[2] = addressToBytes32(
            0x4C5EFa7fA20f707c3B1B1FB15a92537c0FDbc363
        );

        // operator.setPeers(uint32(LAYER_ZERO_EID_BASE_SEP), basePeers);
        operator.setPeers(uint32(LAYER_ZERO_EID_SEP), sepPeers);
        operator.setPeers(uint32(LAYER_ZERO_EID_ARB_SEP), arbPeers);
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}
