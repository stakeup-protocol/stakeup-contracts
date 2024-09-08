// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {StUsdcSetup} from "./StUsdcSetup.t.sol";

contract YieldBenchmarkTest is StUsdcSetup {
    uint256 tbyCount = 0;

    function setUp() public override {
        // Import the Arbitrum RPC URL from foundry.toml
        string memory ARBITRUM_RPC_URL = vm.envString("ARBITRUM_RPC_URL");
        // Fork Arbitrum
        vm.createSelectFork(ARBITRUM_RPC_URL);
        super.setUp();

        uint256 currentPrice = 110e8;
        uint80 roundId = 1;
        for (uint256 i = 0; i <= 180 days; i += 2 days) {
            // Go through the process of generating a new tby.
            _depositAsset(alice, 1_000e6);
            uint256 totalCollateral = _matchBloomOrder(address(stUsdc), 1_000e6);
            currentPrice += 0.02e8;
            skip(1 weeks);
            _skipAndUpdatePrice(0, uint80(currentPrice), roundId++);
            _bloomStartNewTby(totalCollateral);
            tbyCount++;
        }
        assertGt(tby.balanceOf(address(stUsdc), tbyCount - 1), 0);
    }

    function testArbitrumForkSetup() public {
        // This is a basic test to ensure the fork is set up correctly
        assertEq(block.chainid, 42161); // Arbitrum's chain ID
    }

    function testYieldBenchmark() public {
        stUsdc.poke();
    }
}