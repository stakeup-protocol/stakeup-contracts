// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {Test} from "forge-std/Test.sol";
import {LibRLP} from "solady/utils/LibRLP.sol";
import {OptionsBuilder} from "@LayerZero/oapp/libs/OptionsBuilder.sol";
import {OFTComposeMsgCodec} from "@LayerZero/oft/libs/OFTComposeMsgCodec.sol";

import {BridgeOperator} from "src/messaging/BridgeOperator.sol";
import {StUsdc} from "src/token/StUsdc.sol";
import {StUsdcLite} from "src/token/StUsdcLite.sol";
import {StakeUpToken} from "src/token/StakeUpToken.sol";
import {StakeUpTokenLite} from "src/token/StakeUpTokenLite.sol";
import {WstUsdc} from "src/token/WstUsdc.sol";
import {WstUsdcLite} from "src/token/WstUsdcLite.sol";
import {WstUsdcBridge} from "src/messaging/WstUsdcBridge.sol";

import {StUsdcSetup} from "./StUsdcSetup.t.sol";

abstract contract CrossChainSetup is StUsdcSetup {
    using OFTComposeMsgCodec for address;
    using OptionsBuilder for bytes;
    using OFTComposeMsgCodec for bytes32;

    // Mapping of endpoint ids to the stakeUp contracts on that chain (used for non-base chains)
    mapping(uint32 => StakeUpContracts) internal stakeUpContracts;

    /// @dev A struct to hold all the contracts for a StakeUp deployment (not on the initial chain)
    struct StakeUpContracts {
        StUsdcLite stUsdcLite;
        WstUsdcLite wstUsdcLite;
        StakeUpTokenLite stakeUpTokenLite;
        WstUsdcBridge wstUsdcBridge;
        BridgeOperator bridgeOperator;
    }

    function setUp() public virtual override(StUsdcSetup) {
        _setNumberOfEndpoints(numberOfEndpoints);
        super.setUp();
        _deployL2Contracts();
    }

    function _deployL2Contracts() internal {
        address[] memory supAddrs = new address[](numberOfEndpoints);
        address[] memory stUsdcAddrs = new address[](numberOfEndpoints);
        address[] memory wstUsdcBridgeAddrs = new address[](numberOfEndpoints);

        supAddrs[0] = address(supToken);
        stUsdcAddrs[0] = address(stUsdc);
        wstUsdcBridgeAddrs[0] = address(wstUsdcBridge);

        vm.startPrank(owner);
        for (uint32 i = 1; i < numberOfEndpoints; i++) {
            (address expectedSupAddr, address expectedStUsdcAddr, address expectedWstUsdcBridgeAddr) =
                _computeExpectedAddresses();

            _deployAndSetupContracts(i, expectedSupAddr, expectedStUsdcAddr, expectedWstUsdcBridgeAddr);

            supAddrs[i] = address(stakeUpContracts[i + 1].stakeUpTokenLite);
            stUsdcAddrs[i] = address(stakeUpContracts[i + 1].stUsdcLite);
            wstUsdcBridgeAddrs[i] = address(stakeUpContracts[i + 1].wstUsdcBridge);
        }
        vm.stopPrank();
        _connectContracts(stUsdcAddrs, supAddrs, wstUsdcBridgeAddrs);
    }

    function _computeExpectedAddresses() internal view returns (address, address, address) {
        return (
            LibRLP.computeAddress(owner, vm.getNonce(owner) + 1),
            LibRLP.computeAddress(owner, vm.getNonce(owner) + 2),
            LibRLP.computeAddress(owner, vm.getNonce(owner) + 4)
        );
    }

    function _deployAndSetupContracts(
        uint32 i,
        address expectedSupAddr,
        address expectedStUsdcAddr,
        address expectedWstUsdcBridgeAddr
    ) internal {
        BridgeOperator bridgeOperator =
            new BridgeOperator(expectedStUsdcAddr, expectedSupAddr, expectedWstUsdcBridgeAddr, owner);
        stakeUpContracts[i + 1].bridgeOperator = bridgeOperator;

        StakeUpTokenLite stakeUpTokenLite = new StakeUpTokenLite(endpoints[i + 1], address(bridgeOperator));
        require(expectedSupAddr == address(stakeUpTokenLite), "Address mismatch");
        stakeUpContracts[i + 1].stakeUpTokenLite = stakeUpTokenLite;

        StUsdcLite stUsdcLite = new StUsdcLite(endpoints[i + 1], address(bridgeOperator), true);
        require(expectedStUsdcAddr == address(stUsdcLite), "Address mismatch");
        stakeUpContracts[i + 1].stUsdcLite = stUsdcLite;

        bridgeOperator.setKeeper(keeper);

        WstUsdcLite wstUsdcLite = new WstUsdcLite(expectedStUsdcAddr);
        stakeUpContracts[i + 1].wstUsdcLite = wstUsdcLite;

        WstUsdcBridge wstUsdcBridge = new WstUsdcBridge(address(wstUsdcLite), endpoints[i + 1], address(bridgeOperator));
        require(expectedWstUsdcBridgeAddr == address(wstUsdcBridge), "Address mismatch");
        stakeUpContracts[i + 1].wstUsdcBridge = wstUsdcBridge;
    }

    function _connectContracts(
        address[] memory stUsdcAddrs,
        address[] memory supAddrs,
        address[] memory wstUsdcBridgeAddrs
    ) internal {
        for (uint32 i = 0; i < numberOfEndpoints; i++) {
            BridgeOperator operator = (i == 0) ? bridgeOperator : stakeUpContracts[i + 1].bridgeOperator;

            for (uint256 j = 0; j < numberOfEndpoints; j++) {
                if (i == j) continue;
                _setPeersAndWstUsdcBridge(operator, j, stUsdcAddrs, supAddrs, wstUsdcBridgeAddrs);
            }
        }
    }

    function _setPeersAndWstUsdcBridge(
        BridgeOperator operator,
        uint256 j,
        address[] memory stUsdcAddrs,
        address[] memory supAddrs,
        address[] memory wstUsdcBridgeAddrs
    ) internal {
        bytes32[3] memory peers =
            [addressToBytes32(stUsdcAddrs[j]), addressToBytes32(supAddrs[j]), addressToBytes32(wstUsdcBridgeAddrs[j])];
        vm.startPrank(owner);
        operator.setPeers(uint32(j + 1), peers);
        operator.setWstUsdcBridge(uint32(j + 1), wstUsdcBridgeAddrs[j]);
        vm.stopPrank();
    }
}
