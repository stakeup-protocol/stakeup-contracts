// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {ICurvePoolFactory} from "src/interfaces/curve/ICurvePoolFactory.sol";
import {MockCurveGauge} from "./MockCurveGauge.sol";

contract MockCurveFactory is ICurvePoolFactory {
    function deploy_gauge(
        address /*pool*/
    ) external override returns (address) {
        MockCurveGauge gauge = new MockCurveGauge();
        return address(gauge);
    }

    function deploy_plain_pool(
        string memory /*name*/,
        string memory /*symbol*/,
        address[] memory /*coins*/,
        uint256 /*a*/,
        uint256 /*fee*/,
        uint256 /*offpegFeeMultiplier*/,
        uint256 /*maExTime*/,
        uint256 /*impl*/,
        uint8[] memory /*asset_types*/,
        bytes4[] memory /*methodId*/,
        address[] memory /*oracles*/
    ) external pure override returns (address) {
        return address(0);
    }
}
