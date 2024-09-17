// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console2} from "forge-std/Script.sol";
import {LibRLP} from "solady/utils/LibRLP.sol";

import {StakeUpStaking} from "src/staking/StakeUpStaking.sol";
import {StakeUpToken} from "src/token/StakeUpToken.sol";
import {StUsdc} from "src/token/StUsdc.sol";
import {WstUsdc} from "src/token/WstUsdc.sol";
import {WstUsdcBridge} from "src/messaging/WstUsdcBridge.sol";
import {BridgeOperator} from "src/messaging/BridgeOperator.sol";

contract DeployFullScript is Script {
    address public USDC_BASE_SEP = 0x0dfda9C55381949cafF24dbe0fB61f34be8c4832;
    address public BIB01_BASE_SEP = 0x6E6132E8D7126c53458aD6CA047305F7D561A837;
    address public BLOOM_POOL_BASE_SEP = 0x182a1E1d7Ee2DEC6331cDF6a668BdD85D9Ad86CE;

    uint256 public LAYER_ZERO_EID_BASE_SEP = 40245;
    address public LAYER_ZERO_ENDPOINT_BASE_SEP = 0x6EDCE65403992e310A62460808c4b910D972f10f;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address owner = 0x263c0a1ff85604f0ee3f4160cAa445d0bad28dF7;

        address expectedSupAddress = LibRLP.computeAddress(owner, vm.getNonce(owner) + 1);
        address expectedStUsdcAddress = LibRLP.computeAddress(owner, vm.getNonce(owner) + 2);
        address expectedBridgeOperatorAddress = LibRLP.computeAddress(owner, vm.getNonce(owner) + 5);

        StakeUpStaking staking = new StakeUpStaking(address(expectedSupAddress), expectedStUsdcAddress);
        console2.log("StakeUpStaking", address(staking));

        StakeUpToken supToken = new StakeUpToken(
            address(staking),
            address(0), // Not needed for testnet
            owner,
            address(LAYER_ZERO_ENDPOINT_BASE_SEP),
            expectedBridgeOperatorAddress
        );
        require(address(supToken) == expectedSupAddress, "SUP address mismatch");
        console2.log("StakeUpToken", address(supToken));

        address expectedWstUsdcAddress = LibRLP.computeAddress(owner, vm.getNonce(owner) + 1);

        StUsdc stUsdc = new StUsdc(
            address(USDC_BASE_SEP),
            address(BLOOM_POOL_BASE_SEP),
            address(staking),
            expectedWstUsdcAddress,
            address(LAYER_ZERO_ENDPOINT_BASE_SEP),
            expectedBridgeOperatorAddress
        );
        vm.label(address(stUsdc), "StUsdc");
        require(address(stUsdc) == expectedStUsdcAddress, "StUsdc address mismatch");
        console2.log("StUsdc", address(stUsdc));

        WstUsdc wstUsdc = new WstUsdc(address(stUsdc));
        vm.label(address(wstUsdc), "WstUsdc");
        require(address(wstUsdc) == expectedWstUsdcAddress, "WstUsdc address mismatch");
        console2.log("WstUsdc", address(wstUsdc));

        WstUsdcBridge wstUsdcBridge = new WstUsdcBridge(address(wstUsdc), address(LAYER_ZERO_ENDPOINT_BASE_SEP), expectedBridgeOperatorAddress);
        vm.label(address(wstUsdcBridge), "WstUsdc Bridge");
        console2.log("WstUsdc Bridge", address(wstUsdcBridge));

        BridgeOperator bridgeOperator = new BridgeOperator(address(wstUsdc), address(wstUsdcBridge), owner);
        vm.label(address(bridgeOperator), "Bridge Operator");
        require(address(bridgeOperator) == expectedBridgeOperatorAddress, "Bridge Operator address mismatch");
        console2.log("Bridge Operator", address(bridgeOperator));
    }
}
