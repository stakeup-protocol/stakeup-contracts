// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {ICurvePoolFactory} from "src/interfaces/curve/ICurvePoolFactory.sol";
import {MockCurveGauge} from "./MockCurveGauge.sol";

contract MockCurveFactory is ICurvePoolFactory {

    function deploy_gauge(address /*pool*/) external override returns (address) {
        MockCurveGauge gauge = new MockCurveGauge();
        return address(gauge);
    }
}