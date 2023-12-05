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

import {IExchangeRateRegistry} from "src/interfaces/bloom/IExchangeRateRegistry.sol";

import {MockERC20} from "./MockERC20.sol";

contract MockRegistry is IExchangeRateRegistry {
    address public pool;
    TokenInfo public tokenInfo;
    address[] activeTokens;
    mapping(address => uint256) public exchangeRates;

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
        address token
    ) external view override returns (uint256) {
        return exchangeRates[token];
    }

    function setExchangeRate(address token, uint256 rate) public {
        exchangeRates[token] = rate;
    }
}
