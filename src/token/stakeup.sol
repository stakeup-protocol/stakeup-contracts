// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {OFTV2} from "@layerzerolabs/token/oft/v2/OFTV2.sol";

contract StakeupToken is OFTV2 {

    uint256 internal constant INITIAL_SUPPLY = 10_000_000 * 1e6;
    uint256 internal constant MAX_SUPPLY = 1_000_000 * 1e6;

    constructor(address _layerZeroEndpoint, address mintToAddress)
        OFTV2("Stakeup Token", "SUP", 6, _layerZeroEndpoint)
    {
        if (mintToAddress != address(0)) {
            _mint(mintToAddress, INITIAL_SUPPLY * 1e6);
        }
    }

    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }
}
