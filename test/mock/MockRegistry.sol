// SPDX-License-Identifier: BUSL-1.1
/*
██████╗░██╗░░░░░░█████╗░░█████╗░███╗░░░███╗
██╔══██╗██║░░░░░██╔══██╗██╔══██╗████╗░████║
██████╦╝██║░░░░░██║░░██║██║░░██║██╔████╔██║
██╔══██╗██║░░░░░██║░░██║██║░░██║██║╚██╔╝██║
██████╦╝███████╗╚█████╔╝╚█████╔╝██║░╚═╝░██║
╚═════╝░╚══════╝░╚════╝░░╚════╝░╚═╝░░░░░╚═╝
*/

pragma solidity 0.8.19;

import {IExchangeRateRegistry} from "src/interfaces/IExchangeRateRegistry.sol";

import {MockERC20} from "./MockERC20.sol";

contract MockRegistry is IExchangeRateRegistry {
    address public pool;
    TokenInfo public tokenInfo;

    constructor(address _pool) {
        pool = _pool;
    }

    function tokenInfos(
        address /*token*/
    ) external view override returns (TokenInfo memory) {
        return tokenInfo;
    }

    function setTokenInfos(bool registeredAndActive) public {
        tokenInfo = TokenInfo({
            registered: registeredAndActive,
            active: registeredAndActive,
            createdAt: block.timestamp
        });
    }
}
