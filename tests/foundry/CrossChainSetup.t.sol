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
import {StakeUpKeeper} from "src/messaging/StakeUpKeeper.sol";
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
        StakeUpKeeper keeper;
    }

    function setUp() public virtual override(StUsdcSetup) {
        _setNumberOfEndpoints(numberOfEndpoints);
        super.setUp();
    }

    function _deployL2Contracts() internal {
        address[] memory supAddrs = new address[](numberOfEndpoints);
        address[] memory stUsdcAddrs = new address[](numberOfEndpoints);
        address[] memory wstUsdcBridgeAddrs = new address[](numberOfEndpoints);
        address[] memory keeperAddrs = new address[](numberOfEndpoints);

        supAddrs[0] = address(supToken);
        stUsdcAddrs[0] = address(stUsdc);
        wstUsdcBridgeAddrs[0] = address(wstUsdcBridge);
        keeperAddrs[0] = address(stUsdc.keeper());

        vm.startPrank(owner);
        for (uint32 i = 1; i < numberOfEndpoints; i++) {
            _deployAndSetupContracts(i);

            supAddrs[i] = address(stakeUpContracts[i + 1].stakeUpTokenLite);
            stUsdcAddrs[i] = address(stakeUpContracts[i + 1].stUsdcLite);
            wstUsdcBridgeAddrs[i] = address(stakeUpContracts[i + 1].wstUsdcBridge);
            keeperAddrs[i] = address(stakeUpContracts[i + 1].keeper);
        }
        _connectContracts(stUsdcAddrs, supAddrs, wstUsdcBridgeAddrs, keeperAddrs);
        vm.stopPrank();
    }

    function _deployAndSetupContracts(uint32 i) internal {
        /// Compute expected addresses
        address expectedStUsdcAddr = LibRLP.computeAddress(owner, vm.getNonce(owner) + 1);
        address expectedBridgeOperatorAddr = LibRLP.computeAddress(owner, vm.getNonce(owner) + 2);
        address expectedWstUsdcBridgeAddr = LibRLP.computeAddress(owner, vm.getNonce(owner) + 4);

        // Deploy StUsdcLite
        StUsdcLite stUsdcLite = new StUsdcLite(endpoints[i + 1], address(expectedBridgeOperatorAddr));
        stakeUpContracts[i + 1].stUsdcLite = stUsdcLite;
        stakeUpContracts[i + 1].keeper = stUsdcLite.keeper();

        // Deploy StakeUpTokenLite
        StakeUpTokenLite stakeUpTokenLite = new StakeUpTokenLite(endpoints[i + 1], address(expectedBridgeOperatorAddr));
        stakeUpContracts[i + 1].stakeUpTokenLite = stakeUpTokenLite;

        // Deploy BridgeOperator
        BridgeOperator operator =
            new BridgeOperator(address(stUsdcLite), address(stakeUpTokenLite), expectedWstUsdcBridgeAddr, owner);
        stakeUpContracts[i + 1].bridgeOperator = operator;
        require(expectedBridgeOperatorAddr == address(operator), "Address mismatch");

        // Deploy WstUsdcLite
        WstUsdcLite wstUsdcLite = new WstUsdcLite(address(stUsdcLite));
        stakeUpContracts[i + 1].wstUsdcLite = wstUsdcLite;

        // Deploy WstUsdcBridge
        WstUsdcBridge wstUsdcBridge = new WstUsdcBridge(address(wstUsdcLite), endpoints[i + 1], address(operator));
        require(expectedWstUsdcBridgeAddr == address(wstUsdcBridge), "Address mismatch");
        stakeUpContracts[i + 1].wstUsdcBridge = wstUsdcBridge;
    }

    function _connectContracts(
        address[] memory stUsdcAddrs,
        address[] memory supAddrs,
        address[] memory wstUsdcBridgeAddrs,
        address[] memory keeperAddrs
    ) internal {
        for (uint32 i = 0; i < numberOfEndpoints; i++) {
            BridgeOperator operator = (i == 0) ? bridgeOperator : stakeUpContracts[i + 1].bridgeOperator;

            for (uint256 j = 0; j < numberOfEndpoints; j++) {
                if (i == j) continue;
                bytes32[4] memory peers = [
                    stUsdcAddrs[j].addressToBytes32(),
                    supAddrs[j].addressToBytes32(),
                    wstUsdcBridgeAddrs[j].addressToBytes32(),
                    address(StUsdc(stUsdcAddrs[j]).keeper()).addressToBytes32()
                ];
                operator.setPeers(uint32(j + 1), peers);
                operator.setWstUsdcBridge(uint32(j + 1), wstUsdcBridgeAddrs[j]);
            }
        }
    }
}
