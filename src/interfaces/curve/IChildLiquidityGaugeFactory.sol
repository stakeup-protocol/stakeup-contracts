// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IChildLiquidityGaugeFactory {
    function deploy_gauge(address _lp_token, bytes32 _salt) external returns (address);
}
