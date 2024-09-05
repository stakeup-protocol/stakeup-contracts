// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {LibRLP} from "solady/utils/LibRLP.sol";

// Bloom Dependencies
import {IBloomPoolExt} from "../mocks/IBloomPoolExt.sol";
import {Tby} from "@bloom-v2/token/Tby.sol";

// StakeUp Dependencies
import {BridgeOperator} from "src/messaging/BridgeOperator.sol";
import {StUsdc} from "src/token/StUsdc.sol";
import {StakeUpToken} from "src/token/StakeUpToken.sol";
import {WstUsdc} from "src/token/WstUsdc.sol";
import {StakeUpStaking} from "src/staking/StakeUpStaking.sol";
import {WstUsdcBridge} from "src/messaging/WstUsdcBridge.sol";

import {MockEndpoint} from "../mocks/MockEndpoint.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockPriceFeed} from "../mocks/MockPriceFeed.sol";

abstract contract StUsdcSetup is Test {
    // StakeUp Contracts
    StUsdc internal stUsdc;
    WstUsdc internal wstUsdc;
    WstUsdcBridge internal wstUsdcBridge;
    StakeUpStaking internal staking;
    StakeUpToken internal supToken;
    BridgeOperator internal bridgeOperator;
    // Bloom Pool Contracts
    MockERC20 internal stableToken;
    MockERC20 internal billyToken;
    IBloomPoolExt internal bloomPool;
    Tby internal tby;

    // Bloom Pool Settings
    uint256 internal initialLeverage = 50e18;
    uint256 internal initialSpread = 0.995e18;

    // LayerZero Contracts
    MockEndpoint internal layerZeroEndpointA;

    // Users
    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    // Constants
    uint256 internal constant SCALER = 1e12;
    uint32 internal constant EID_A = 1;

    bytes internal constant NOT_OWNER_ERROR = bytes("Ownable: caller is not the owner");

    function setUp() public virtual {
        // Deploy Bloom Dependencies
        stableToken = new MockERC20(6);
        vm.label(address(stableToken), "StableToken");
        billyToken = new MockERC20(18);
        vm.label(address(billyToken), "BillyToken");

        skip(1 weeks);

        vm.startPrank(owner);
        MockPriceFeed priceFeed = new MockPriceFeed(8); // bib01 token price feed has 8 decimals
        vm.label(address(priceFeed), "BillyToken PriceFeed");
        priceFeed.setLatestRoundData(1, 110e8, block.timestamp, block.timestamp, 1);

        /// Because of openzeppelin versioning collisions, we need to deploy the bloom pool using
        ///     the artifact instead of the source repo.
        bloomPool = IBloomPoolExt(
            deployCode("lib/bloom-v2/out/BloomPool.sol/BloomPool.json", abi.encode(address(stableToken), address(billyToken), priceFeed, initialLeverage, initialSpread, owner))
        );
        vm.label(address(bloomPool), "Bloom Pool");

        tby = Tby(bloomPool.tby());
        vm.label(address(tby), "Tby");

        // Deploy LayerZero Contracts
        layerZeroEndpointA = new MockEndpoint();
        vm.label(address(layerZeroEndpointA), "LayerZero Endpoint A");

        // Deploy StakeUp Contracts
        address expectedSupAddress = LibRLP.computeAddress(owner, vm.getNonce(owner) + 1);
        address expectedStUsdcAddress = LibRLP.computeAddress(owner, vm.getNonce(owner) + 2);
        address expectedBridgeOperatorAddress = LibRLP.computeAddress(owner, vm.getNonce(owner) + 5);

        staking = new StakeUpStaking(address(expectedSupAddress), expectedStUsdcAddress);

        supToken = new StakeUpToken(
            address(staking),
            address(0), // gaugeDistributor
            owner,
            address(layerZeroEndpointA),
            expectedBridgeOperatorAddress
        );
        require(address(supToken) == expectedSupAddress, "SUP address mismatch");

        address expectedWstUsdcAddress = LibRLP.computeAddress(owner, vm.getNonce(owner) + 1);

        stUsdc = new StUsdc(
            address(stableToken),
            address(bloomPool),
            address(staking),
            expectedWstUsdcAddress,
            address(layerZeroEndpointA),
            expectedBridgeOperatorAddress
        );
        vm.label(address(stUsdc), "StUsdc");
        require(address(stUsdc) == expectedStUsdcAddress, "StUsdc address mismatch");

        wstUsdc = new WstUsdc(address(stUsdc));
        vm.label(address(wstUsdc), "WstUsdc");
        require(address(wstUsdc) == expectedWstUsdcAddress, "WstUsdc address mismatch");

        wstUsdcBridge = new WstUsdcBridge(address(wstUsdc), address(layerZeroEndpointA), expectedBridgeOperatorAddress);
        vm.label(address(wstUsdcBridge), "WstUsdc Bridge");

        bridgeOperator = new BridgeOperator(address(wstUsdc), address(wstUsdcBridge), owner);
        vm.label(address(bridgeOperator), "Bridge Operator");
        require(address(bridgeOperator) == expectedBridgeOperatorAddress, "Bridge Operator address mismatch");

        // Deploy Bloom Pool Contracts
        vm.stopPrank();
    }
}
