// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract StakeUpTokenLite is ERC20Burnable {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        // Solhint-disable-previous-line no-empty-blocks
    }
}
