// // SPDX-License-Identifier: BUSL-1.1
// pragma solidity 0.8.26;

// import {Test} from "forge-std/Test.sol";
// import {LibRLP} from "solady/utils/LibRLP.sol";

// import {StTBY} from "src/token/StTBY.sol";
// import {WstTBY} from "src/token/WstTBY.sol";
// import {StakeUpStaking} from "src/staking/StakeUpStaking.sol";
// import {WstTBYBridge} from "src/messaging/WstTBYBridge.sol";

// import {MockEndpoint} from "../mocks/MockEndpoint.sol";
// import {MockERC20} from "../mocks/MockERC20.sol";
// import {MockSwapFacility} from "../mocks/MockSwapFacility.sol";
// import {BloomFactory} from "@Bloom/BloomFactory.sol";
// import {BloomPool} from "@Bloom/BloomPool.sol";
// import {MockBloomPool} from "../mocks/MockBloomPool.sol";
// import {MockEmergencyHandler} from "../mocks/MockEmergencyHandler.sol";
// import {MockBloomFactory} from "../mocks/MockBloomFactory.sol";
// import {MockRegistry} from "../mocks/MockRegistry.sol";
// import {MockBPSFeed} from "../mocks/MockBPSFeed.sol";
// import {MockEndpoint} from "../mocks/MockEndpoint.sol";

// abstract contract StTBYSetup is Test {
//     // StakeUp Contracts
//     StTBY internal stTBY;
//     WstTBY internal wstTBY;
//     WstTBYBridge internal wstTBYBridge;
//     StakeUpStaking internal staking;

//     MockBloomFactory internal factory;

//     // Bloom Pool Contracts
//     MockERC20 internal stableToken;
//     MockERC20 internal billyToken;
//     MockERC20 internal supToken;

//     MockBloomPool internal pool;
//     MockSwapFacility internal swap;
//     MockRegistry internal registry;
//     MockBPSFeed internal bpsFeed;

//     MockEndpoint internal layerZeroEndpointA;
//     MockEndpoint internal layerZeroEndpointB;
//     MockEmergencyHandler internal emergencyHandler;

//     // Users
//     address internal owner = makeAddr("owner");
//     address internal alice = makeAddr("alice");
//     address internal bob = makeAddr("bob");

//     // Constants
//     uint16 internal performanceFeeBps = 1000;

//     uint16 internal constant BPS = 10000;
//     uint256 internal constant SCALER = 1e12;

//     uint32 internal constant EID_A = 1;
//     uint32 internal constant EID_B = 2;

//     bytes internal constant NOT_OWNER_ERROR = bytes("Ownable: caller is not the owner");

//     function setUp() public virtual {
//         stableToken = new MockERC20(6);
//         vm.label(address(stableToken), "StableToken");
//         billyToken = new MockERC20(18);
//         vm.label(address(billyToken), "BillyToken");
//         supToken = new MockERC20(18);
//         vm.label(address(supToken), "SupToken");

//         swap = new MockSwapFacility(stableToken, billyToken);
//         vm.label(address(swap), "MockSwapFacility");

//         pool = new MockBloomPool(address(stableToken), address(billyToken), address(swap), 6);
//         vm.label(address(pool), "MockBloomPool");

//         emergencyHandler = new MockEmergencyHandler();
//         vm.label(address(emergencyHandler), "MockEmergencyHandler");

//         pool.setEmergencyHandler(address(emergencyHandler));

//         vm.startPrank(owner);

//         factory = new MockBloomFactory();
//         vm.label(address(factory), "MockBloomFactory");
//         factory.setLastCreatedPool(address(pool));

//         registry = new MockRegistry(address(pool));

//         layerZeroEndpointA = new MockEndpoint();
//         layerZeroEndpointB = new MockEndpoint();

//         address expectedstTBYddress = LibRLP.computeAddress(owner, vm.getNonce(owner) + 2);

//         staking = new StakeUpStaking(address(supToken), expectedstTBYddress);

//         address expectedWrapperAddress = LibRLP.computeAddress(owner, vm.getNonce(owner) + 2);

//         bpsFeed = new MockBPSFeed();

//         stTBY = new StTBY(
//             address(stableToken),
//             address(staking),
//             address(factory),
//             address(registry),
//             address(bpsFeed),
//             expectedWrapperAddress,
//             address(layerZeroEndpointA),
//             owner
//         );
//         vm.label(address(stTBY), "StTBY");

//         assertEq(stTBY.owner(), owner);
//         assertEq(address(stTBY.getUnderlyingToken()), address(stableToken));
//         assertEq(stTBY.getPerformanceBps(), performanceFeeBps);

//         wstTBY = new WstTBY(address(stTBY));
//         vm.label(address(wstTBY), "WstTBY");

//         assertEq(address(wstTBY), expectedWrapperAddress);
//         assertEq(address(wstTBY.getStTBY()), address(stTBY));

//         wstTBYBridge = new WstTBYBridge(address(wstTBY), address(layerZeroEndpointA), owner);

//         vm.stopPrank();
//     }
// }
