// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface ICurvePoolFactory {
    /**
     * @notice Deploys a gauge for the given pool
     * @param pool Address of the pool to deploy a gauge for
     * @return Address of the deployed gauge
     */
    function deploy_gauge(address pool) external returns (address);

    /**
     * @notice Deploys a plain curve pool
     * @dev This function is used for testing purposes only in this repository
     */
    function deploy_plain_pool(
        string memory name,
        string memory symbol,
        address[] memory coins,
        uint256 a,
        uint256 fee,
        uint256 offpegFeeMultiplier,
        uint256 maExTime,
        uint256 impl,
        uint8[] memory asset_types,
        bytes4[] memory methodId,
        address[] memory oracles
    ) external returns (address);
}
