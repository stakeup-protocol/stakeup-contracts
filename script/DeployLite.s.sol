// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console2} from "forge-std/Script.sol";
import {LibRLP} from "solady/utils/LibRLP.sol";
import {OFT, ERC20} from "@LayerZero/oft/OFT.sol";

import {StTBYBase} from "src/token/StTBYBase.sol";
import {WstTBYBase} from "src/token/WstTBYBase.sol";
import {StakeUpTokenLite} from "src/token/StakeUpTokenLite.sol";
import {WstTBYBridge} from "src/messaging/WstTBYBridge.sol";
import {BridgeOperator} from "src/messaging/BridgeOperator.sol";
import {StakeUpToken} from "src/token/StakeUpToken.sol";

contract DeployLiteScript is Script {
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

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address owner = 0x263c0a1ff85604f0ee3f4160cAa445d0bad28dF7;

        address expectedBridgeOperatorAddress = LibRLP.computeAddress(
            owner,
            vm.getNonce(owner) + 5
        );

        address expectedMessengerAddress = LibRLP.computeAddress(
            owner,
            vm.getNonce(owner) + 1
        );

        StTBYBase stTBY = new StTBYBase(
            address(LAYER_ZERO_ENDPOINT_SEP),
            expectedBridgeOperatorAddress
        );
        console2.log("stTBY", address(stTBY));

        StakeUpTokenLite sup = new StakeUpTokenLite(
            address(LAYER_ZERO_ENDPOINT_SEP),
            expectedBridgeOperatorAddress
        );

        console2.log("sup", address(sup));

        WstTBYBase wstTBY = new WstTBYBase(address(stTBY));

        console2.log("wstTBY", address(wstTBY));

        WstTBYBridge wstTBYBridge = new WstTBYBridge(
            address(wstTBY),
            address(LAYER_ZERO_ENDPOINT_SEP),
            expectedBridgeOperatorAddress
        );

        console2.log("wstTBYBridge", address(wstTBYBridge));

        BridgeOperator bridgeOperator = new BridgeOperator(
            address(stTBY),
            address(wstTBYBridge),
            owner
        );
        console2.log("bridgeOperator", address(bridgeOperator));

        require(
            address(bridgeOperator) == expectedBridgeOperatorAddress,
            "Incorrect bridge operator address"
        );
    }
}
