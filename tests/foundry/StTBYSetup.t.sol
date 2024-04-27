// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {Test} from "forge-std/Test.sol";
import {LibRLP} from "solady/utils/LibRLP.sol";

import {StTBY} from "src/token/StTBY.sol";
import {WstTBY} from "src/token/WstTBY.sol";
import {StakeupStaking} from "src/staking/StakeupStaking.sol";
import {MessagingHelpers} from "./MessagingHelpers.t.sol";
import {StakeUpMessenger} from "src/messaging/StakeUpMessenger.sol";

import {IStTBY} from "src/interfaces/IStTBY.sol";
import {ILayerZeroSettings} from "src/interfaces/ILayerZeroSettings.sol";

import {MockEndpoint} from "../mocks/MockEndpoint.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockSwapFacility} from "../mocks/MockSwapFacility.sol";
import {MockBloomPool, IBloomPool} from "../mocks/MockBloomPool.sol";
import {MockBloomFactory} from "../mocks/MockBloomFactory.sol";
import {MockEmergencyHandler} from "../mocks/MockEmergencyHandler.sol";
import {MockRegistry} from "../mocks/MockRegistry.sol";

abstract contract StTBYSetup is Test, MessagingHelpers {
    StTBY internal stTBY;
    WstTBY internal wstTBY;

    MockERC20 internal stableToken;
    MockERC20 internal billyToken;
    MockERC20 internal supToken;
    MockSwapFacility internal swap;
    MockBloomPool internal pool;
    MockBloomFactory internal factory;
    MockRegistry internal registry;
    StakeupStaking internal staking;
    MockEmergencyHandler internal emergencyHandler;

    MockEndpoint internal layerZeroEndpointA;
    MockEndpoint internal layerZeroEndpointB;

    StakeUpMessenger internal messenger;

    address internal owner = makeAddr("owner");
    address internal layerZeroEndpoint = makeAddr("layerZeroEndpoint");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    // Fees
    uint16 internal mintBps = 1;
    uint16 internal redeemBps = 50;
    uint16 internal performanceFeeBps = 1000;

    uint16 internal constant BPS = 10000;

    uint32 internal constant EID_A = 1;
    uint32 internal constant EID_B = 2;

    bytes internal constant NOT_OWNER_ERROR =
        bytes("Ownable: caller is not the owner");

    function setUp() public virtual {
        stableToken = new MockERC20(6);
        vm.label(address(stableToken), "StableToken");
        billyToken = new MockERC20(18);
        vm.label(address(billyToken), "BillyToken");
        supToken = new MockERC20(18);
        vm.label(address(supToken), "SupToken");

        swap = new MockSwapFacility(stableToken, billyToken);
        vm.label(address(swap), "MockSwapFacility");

        pool = new MockBloomPool(
            address(stableToken),
            address(billyToken),
            address(swap),
            6
        );
        vm.label(address(pool), "MockBloomPool");

        emergencyHandler = new MockEmergencyHandler();
        vm.label(address(emergencyHandler), "MockEmergencyHandler");

        pool.setEmergencyHandler(address(emergencyHandler));

        vm.startPrank(owner);

        factory = new MockBloomFactory();
        vm.label(address(factory), "MockBloomFactory");
        factory.setLastCreatedPool(address(pool));

        registry = new MockRegistry(address(pool));

        layerZeroEndpointA = new MockEndpoint();
        layerZeroEndpointB = new MockEndpoint();

        address expectedstTBYddress = LibRLP.computeAddress(
            owner,
            vm.getNonce(owner) + 1
        );

        staking = new StakeupStaking(
            address(supToken),
            expectedstTBYddress,
            address(0)
        );

        address expectedWrapperAddress = LibRLP.computeAddress(
            owner,
            vm.getNonce(owner) + 1
        );
        address expectedMessengerAddress = LibRLP.computeAddress(
            owner,
            vm.getNonce(owner) + 2
        );
        stTBY = new StTBY(
            address(stableToken),
            address(staking),
            address(factory),
            address(registry),
            expectedWrapperAddress,
            expectedMessengerAddress,
            true,
            address(layerZeroEndpointA),
            owner
        );
        vm.label(address(stTBY), "StTBY");

        assertEq(stTBY.owner(), owner);
        assertEq(address(stTBY.getUnderlyingToken()), address(stableToken));
        assertEq(stTBY.getMintBps(), mintBps);
        assertEq(stTBY.getRedeemBps(), redeemBps);
        assertEq(stTBY.getPerformanceBps(), performanceFeeBps);

        wstTBY = new WstTBY(address(stTBY));
        vm.label(address(wstTBY), "WstTBY");

        messenger = new StakeUpMessenger(
            address(stTBY),
            address(layerZeroEndpointA),
            owner
        );
        assertEq(address(wstTBY), expectedWrapperAddress);
        assertEq(address(wstTBY.getStTBY()), address(stTBY));

        vm.stopPrank();
    }
}
