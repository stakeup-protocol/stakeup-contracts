// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {OFTV2} from "@layerzerolabs/solidity-examples/contracts/token/oft/v2/OFTV2.sol";

contract StakeupToken is OFTV2 {
    constructor(address _layerZeroEndpoint, address mintToAddress)
        OFTV2("Stakeup Token", "SUP", 6, _layerZeroEndpoint)
    {
        if (mintToAddress != address(0)) {
            _mint(mintToAddress, 10_000_000 * 1e6);
        }
    }
}
