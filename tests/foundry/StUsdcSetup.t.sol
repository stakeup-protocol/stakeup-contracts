// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {FixedPointMathLib as FpMath} from "solady/utils/FixedPointMathLib.sol";
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
    using FpMath for uint256;

    // StakeUp Contracts
    StUsdc internal stUsdc;
    WstUsdc internal wstUsdc;
    WstUsdcBridge internal wstUsdcBridge;
    StakeUpStaking internal staking;
    StakeUpToken internal supToken;
    BridgeOperator internal bridgeOperator;
    // Bloom Pool Contracts
    MockERC20 internal stableToken;
    MockERC20 internal billToken;
    IBloomPoolExt internal bloomPool;
    Tby internal tby;
    MockPriceFeed internal priceFeed;

    // Bloom Pool Settings
    uint256 internal initialLeverage = 50e18;
    uint256 internal initialSpread = 0.995e18;

    // LayerZero Contracts
    MockEndpoint internal layerZeroEndpointA;

    // Users
    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal rando = makeAddr("rando");

    // Bloom Users
    address internal borrower = makeAddr("borrower");
    address internal marketMaker = makeAddr("marketMaker");

    // Constants
    uint256 internal constant SCALER = 1e12;
    uint32 internal constant EID_A = 1;

    bytes internal constant NOT_OWNER_ERROR = bytes("Ownable: caller is not the owner");

    address[] internal bloomLenders;

    function setUp() public virtual {
        // Deploy Bloom Dependencies
        stableToken = new MockERC20(6);
        vm.label(address(stableToken), "StableToken");
        billToken = new MockERC20(18);
        vm.label(address(billToken), "BillyToken");

        skip(1 weeks);

        vm.startPrank(owner);
        priceFeed = new MockPriceFeed(8); // bib01 token price feed has 8 decimals
        vm.label(address(priceFeed), "BillyToken PriceFeed");
        priceFeed.setLatestRoundData(1, 110e8, block.timestamp, block.timestamp, 1);

        /// Because of openzeppelin versioning collisions, we need to deploy the bloom pool using
        ///     the artifact instead of the source repo.
        bloomPool = IBloomPoolExt(
            deployCode(
                "lib/bloom-v2/out/BloomPool.sol/BloomPool.json",
                abi.encode(address(stableToken), address(billToken), priceFeed, initialLeverage, initialSpread, owner)
            )
        );
        vm.label(address(bloomPool), "Bloom Pool");

        bloomPool.whitelistBorrower(borrower, true);
        bloomPool.whitelistMarketMaker(marketMaker, true);

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

        bloomLenders.push(address(stUsdc));
    }

    function _depositAsset(address user, uint256 amount) internal returns (uint256) {
        vm.startPrank(user);
        // Mint and approve stableToken
        stableToken.mint(user, amount);
        stableToken.approve(address(stUsdc), amount);

        // Deposit asset into stUsdc
        return stUsdc.depositAsset(amount);
    }

    function _matchBloomOrder(address user, uint256 amount) internal returns (uint256) {
        vm.startPrank(borrower);
        uint256 neededAmount = amount.divWad(bloomPool.leverage());
        stableToken.mint(borrower, neededAmount);
        stableToken.approve(address(bloomPool), neededAmount);
        bloomPool.fillOrder(user, amount);
        return amount + neededAmount;
    }

    function _bloomStartNewTby(uint256 stableAmount) internal returns (uint256 id) {
        (, int256 answer,,,) = priceFeed.latestRoundData();
        uint256 answerScaled = uint256(answer) * (10 ** (18 - priceFeed.decimals()));
        uint256 rwaAmount = (stableAmount * (10 ** (18 - stableToken.decimals()))).divWadUp(answerScaled);

        vm.startPrank(marketMaker);
        billToken.mint(marketMaker, rwaAmount);
        billToken.approve(address(bloomPool), rwaAmount);
        (id,) = bloomPool.swapIn(bloomLenders, stableAmount);
    }

    function _bloomEndTby(uint256 id, uint256 stableAmount) internal {
        (, int256 answer,,,) = priceFeed.latestRoundData();
        uint256 answerScaled = uint256(answer) * (10 ** (18 - priceFeed.decimals()));
        uint256 rwaAmount = (stableAmount * (10 ** (18 - stableToken.decimals()))).divWadUp(answerScaled);

        vm.startPrank(marketMaker);
        stableToken.mint(marketMaker, stableAmount);
        stableToken.approve(address(bloomPool), stableAmount);
        bloomPool.swapOut(id, rwaAmount);
    }

    function _redeemStUsdc(address user, uint256 amount) internal returns (uint256) {
        vm.startPrank(user);
        return stUsdc.redeemStUsdc(amount);
    }

    function _skipAndUpdatePrice(uint256 time, uint256 price, uint80 roundId) internal {
        vm.startPrank(owner);
        skip(time);
        priceFeed.setLatestRoundData(roundId, int256(price), block.timestamp, block.timestamp, roundId);
        vm.stopPrank();
    }
}