// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface ICurveGaugeDistributor {

    /// @notice Emitted if the caller tries to seed the gauges to early
    error TooEarlyToSeed();

    /// @notice Emitted if the caller passes an invalid address
    error InvalidAddress();

    /// @notice Emitted if the reward allocation is not met
    error RewardAllocationNotMet();
    
    /** 
     * @notice Data for a Curve pool
     * @param curvePool Address of the Curve pool
     * @param curveGauge Address of the Curve gauge
     * @param curveFactory Address of the Curve factory
     * @param rewardsRemaining Amount of rewards remaining to be distributed
     * @param maxRewards Maximum amount of rewards to distribute
     */
    struct CurvePoolData {
        address curvePool;
        address curveGauge;
        address curveFactory;
        uint256 rewardsRemaining;
        uint256 maxRewards;
    }

    /**
     * @notice Emitted when rewards are sent to a gauge
     * @param gauge Address of the gauge
     * @param amount Amount sent to the gauge
     */
    event GaugeSeeded(address indexed gauge, uint256 amount);

    /**
     * @notice Emitted when a new gauge is deployed
     * @param gauge Address of the gauge
     * @param pool Address of the pool associated with the gauge
     */
    event GaugeDeployed(address indexed gauge, address indexed pool);

    /**
     * @notice Seeds the gauges with rewards
     * @dev This function should be called at the end of every epoch (1 week)
     *     to maintain consistent reward distributions
     */
    function seedGauges() external;

    /**
     * @notice Returns the data for all Curve pool registered with the distributor
     */
    function getCurvePoolData() external view returns (CurvePoolData[] memory);

}