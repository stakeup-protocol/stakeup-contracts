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

import {IExchangeRateRegistry} from "src/interfaces/bloom/IExchangeRateRegistry.sol";

import {MockERC20} from "./MockERC20.sol";

contract MockRegistry is IExchangeRateRegistry {
    address public pool;
    TokenInfo public tokenInfo;
    address[] activeTokens;
    uint256 exchangeRate;

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

    function getActiveTokens()
        external
        view
        override
        returns (address[] memory)
    {
        return activeTokens;
    }

    function setActiveTokens(address[] memory tokens) public {
        for (uint256 i = 0; i < tokens.length; i++) {
            activeTokens.push(tokens[i]);
        }
    }

    function getExchangeRate(
        address /*token*/
    ) external view override returns (uint256) {
        return exchangeRate;
    }

    function setExchangeRate(uint256 rate) public {
        exchangeRate = rate;
    }
}
