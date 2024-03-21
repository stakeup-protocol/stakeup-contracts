// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.22;

import {MockERC20} from "./MockERC20.sol";

contract StableTokenMockERC20 is MockERC20 {
   constructor() MockERC20(6) {}

   function decimals() public pure override returns (uint8) { 
      return 6;
   }
}