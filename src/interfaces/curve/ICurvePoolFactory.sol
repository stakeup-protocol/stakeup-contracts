// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

interface ICurvePoolFactory {

    /**
     * @notice Deploys a gauge for the given pool
     * @param pool Address of the pool to deploy a gauge for
     * @return Address of the deployed gauge
     */
    function deploy_gauge(address pool) external returns (address);
}