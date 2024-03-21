// SPDX-License-Identifier: BUSL-1.1
/*
██████╗░██╗░░░░░░█████╗░░█████╗░███╗░░░███╗
██╔══██╗██║░░░░░██╔══██╗██╔══██╗████╗░████║
██████╦╝██║░░░░░██║░░██║██║░░██║██╔████╔██║
██╔══██╗██║░░░░░██║░░██║██║░░██║██║╚██╔╝██║
██████╦╝███████╗╚█████╔╝╚█████╔╝██║░╚═╝░██║
╚═════╝░╚══════╝░╚════╝░░╚════╝░╚═╝░░░░░╚═╝
*/

pragma solidity 0.8.22;

import {IEmergencyHandler} from "src/interfaces/bloom/IEmergencyHandler.sol";
import {IBloomPool} from "src/interfaces/bloom/IBloomPool.sol";

import {MockERC20, IERC20} from "./MockERC20.sol";
import {MockBloomPool} from "./MockBloomPool.sol";

contract MockEmergencyHandler is IEmergencyHandler {
    uint256 private _tokensToRedeem;

    function redeem(IBloomPool _pool) external override returns (uint256) {
        MockBloomPool(address(_pool)).transferFrom(msg.sender, address(this), _tokensToRedeem);
        MockBloomPool(address(_pool)).emergencyBurn(_tokensToRedeem);
        IERC20(MockBloomPool(address(_pool)).UNDERLYING_TOKEN()).transfer(msg.sender, _tokensToRedeem); // @note use `UNDERLYING_TOKEN` to support certora
        return _tokensToRedeem;
    }

    function setNumTokensToRedeem(uint256 tokensToRedeem) public {
        _tokensToRedeem = tokensToRedeem;
    }
}