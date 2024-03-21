// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "../../src/token/WstTBY.sol";

contract WstTBYHarness is WstTBY { 
    
    constructor(address stTBY) WstTBY(stTBY) { }
}
