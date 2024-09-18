// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console2} from "forge-std/Script.sol";
import {LibRLP} from "solady/utils/LibRLP.sol";
import {OFT, ERC20} from "@LayerZero/oft/OFT.sol";

import {StUsdcLite} from "src/token/StUsdcLite.sol";
import {WstUsdcLite} from "src/token/WstUsdcLite.sol";
import {StakeUpTokenLite} from "src/token/StakeUpTokenLite.sol";
import {WstUsdcBridge} from "src/messaging/WstUsdcBridge.sol";
import {BridgeOperator} from "src/messaging/BridgeOperator.sol";
import {YieldRelayer} from "src/messaging/YieldRelayer.sol";

contract DeployLiteScript is Script {
    uint256 public LAYER_ZERO_EID_ARB_SEP = 40231;
    address public LAYER_ZERO_ENDPOINT_ARB_SEP = 0x6EDCE65403992e310A62460808c4b910D972f10f;

    uint256 public LAYER_ZERO_EID_SEP = 40161;
    address public LAYER_ZERO_ENDPOINT_SEP = 0x6EDCE65403992e310A62460808c4b910D972f10f;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address owner = 0x263c0a1ff85604f0ee3f4160cAa445d0bad28dF7;

        address expectedStUsdcAddr = LibRLP.computeAddress(owner, vm.getNonce(owner) + 3);
        address expectedWstUsdcBridgeAddr = LibRLP.computeAddress(owner, vm.getNonce(owner) + 4);

        BridgeOperator bridgeOperator = new BridgeOperator(expectedStUsdcAddr, expectedWstUsdcBridgeAddr, owner);
        console2.log("BridgeOperator", address(bridgeOperator));
        StakeUpTokenLite stakeUpTokenLite = new StakeUpTokenLite(LAYER_ZERO_ENDPOINT_ARB_SEP, address(bridgeOperator));
        console2.log("StakeUpTokenLite", address(stakeUpTokenLite));

        WstUsdcLite wstUsdcLite = new WstUsdcLite(expectedStUsdcAddr);
        console2.log("WstUsdcLite", address(wstUsdcLite));
        StUsdcLite stUsdcLite = new StUsdcLite(LAYER_ZERO_ENDPOINT_ARB_SEP, address(bridgeOperator));
        require(expectedStUsdcAddr == address(stUsdcLite), "StUsdcLite address mismatch");
        console2.log("StUsdcLite", address(stUsdcLite));
        WstUsdcBridge wstUsdcBridge = new WstUsdcBridge(address(wstUsdcLite), LAYER_ZERO_ENDPOINT_ARB_SEP, address(bridgeOperator));
        require(expectedWstUsdcBridgeAddr == address(wstUsdcBridge), "WstUsdcBridge address mismatch");
        console2.log("WstUsdcBridge", address(wstUsdcBridge));
        YieldRelayer yieldRelayer = new YieldRelayer(address(stUsdcLite), address(bridgeOperator), owner);
        console2.log("YieldRelayer", address(yieldRelayer));

        stUsdcLite.setYieldRelayer(address(yieldRelayer));
    }
}
