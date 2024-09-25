// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {OFTController} from "../messaging/controllers/OFTController.sol";

contract StakeUpTokenLite is OFTController {
    constructor(address layerZeroEndpoint, address bridgeOperator)
        OFTController("StakeUp Token", "SUP", layerZeroEndpoint, bridgeOperator)
    {
        // Solhint-disable-previous-line no-empty-blocks
    }
}
