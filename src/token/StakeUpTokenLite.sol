// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {OFT, ERC20} from "@LayerZero/oft/OFT.sol";

contract StakeUpTokenLite is OFT {
    constructor(
        address layerZeroEndpoint,
        address bridgeOperator
    ) OFT("StakeUp Token", "SUP", layerZeroEndpoint, bridgeOperator) {
        // Solhint-disable-previous-line no-empty-blocks
    }
}