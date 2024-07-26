// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console2} from "forge-std/Script.sol";
import {LibRLP} from "solady/utils/LibRLP.sol";

import {StTBY} from "src/token/StTBY.sol";
import {WstTBY} from "src/token/WstTBY.sol";
import {StakeUpStaking} from "src/staking/StakeUpStaking.sol";
import {WstTBYBridge} from "src/messaging/WstTBYBridge.sol";
import {BridgeOperator} from "src/messaging/BridgeOperator.sol";
import {StakeUpToken} from "src/token/StakeUpToken.sol";
import {IStakeUpToken} from "src/interfaces/IStakeUpToken.sol";

contract DeployFullScript is Script {
    address public USDC_ARB_SEP = 0x52bFe207B9FBd8E703edD40a266130fd44C559db;
    address public BIB01_ARB_SEP = 0x50868a9E0C576bea3aFe97e4b8b1f9E18aa8095d;
    address public factory = 0x7b1dE7ba3bC08408df1dA65c8F4E19efdC51515d;
    address public registry = 0x7B828A8cE30594F8Ee0d4f5EA7fF23F386752F26;
    address public bpsFeed = 0x7B828A8cE30594F8Ee0d4f5EA7fF23F386752F26;

    uint256 public LAYER_ZERO_EID_ARB_SEP = 40231;
    address public LAYER_ZERO_ENDPOINT_ARB_SEP =
        0x6EDCE65403992e310A62460808c4b910D972f10f;

    uint256 mintBps = 1;
    uint256 redeemBps = 50;
    uint256 performanceFeeBps = 1000;
    IStakeUpToken.TokenRecipient[] recipients;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address owner = 0x263c0a1ff85604f0ee3f4160cAa445d0bad28dF7;

        address expectedBridgeOperatorAddress = LibRLP.computeAddress(
            owner,
            vm.getNonce(owner) + 6
        );

        address expectedSUPAddress = LibRLP.computeAddress(
            owner,
            vm.getNonce(owner) + 1
        );

        address expectedstTBYddress = LibRLP.computeAddress(
            owner,
            vm.getNonce(owner) + 2
        );
        StakeUpStaking staking = new StakeUpStaking(
            address(expectedSUPAddress),
            expectedstTBYddress
        );
        console2.log("staking", address(staking));
        StakeUpToken supToken = new StakeUpToken(
            address(staking),
            address(0),
            owner,
            address(LAYER_ZERO_ENDPOINT_ARB_SEP),
            expectedBridgeOperatorAddress
        );

        console2.log("supToken", address(supToken));

        address expectedWrapperAddress = LibRLP.computeAddress(
            owner,
            vm.getNonce(owner) + 1
        );

        StTBY stTBY = new StTBY(
            address(USDC_ARB_SEP),
            address(staking),
            address(factory),
            address(registry),
            address(bpsFeed),
            expectedWrapperAddress,
            address(LAYER_ZERO_ENDPOINT_ARB_SEP),
            expectedBridgeOperatorAddress
        );
        console2.log("stTBY", address(stTBY));
        WstTBY wstTBY = new WstTBY(address(stTBY));
        console2.log("wstTBY", address(wstTBY));

        WstTBYBridge wstTBYBridge = new WstTBYBridge(
            address(wstTBY),
            address(LAYER_ZERO_ENDPOINT_ARB_SEP),
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
            address(wstTBY) == expectedWrapperAddress,
            "Incorrect wrapper address"
        );
        require(
            address(wstTBY.getStTBY()) == address(stTBY),
            "Incorrect StTBY address"
        );

        require(
            address(stTBY) == expectedstTBYddress,
            "Incorrect stTBY address"
        );

        require(
            address(bridgeOperator) == expectedBridgeOperatorAddress,
            "Incorrect BridgeOperator address"
        );
        require(
            address(supToken) == expectedSUPAddress,
            "Incorrect staking address"
        );

        // Check settings
        require(stTBY.owner() == owner, "Incorrect owner");
        require(
            address(stTBY.getUnderlyingToken()) == address(USDC_ARB_SEP),
            "Incorrect underlying token"
        );
        require(
            stTBY.getPerformanceBps() == performanceFeeBps,
            "Incorrect performance fee basis points"
        );

        recipients.push(
            IStakeUpToken.TokenRecipient({
                recipient: owner,
                percentOfAllocation: 1e18
            })
        );
        supToken.airdropTokens(recipients, 1e17);
    }
}
