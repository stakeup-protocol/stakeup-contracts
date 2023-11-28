// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

interface ICurvePoolGauge {
    /**
     * @notice Adds a reward token to the gauge and sets the distributor
     * @dev The distributor will be in charge of seeding the gauge with rewards
     * @param reward_token Address of the reward token to add
     * @param distributor Address of the distributor to set
     */
    function add_reward(address reward_token, address distributor) external;

    /**
     * @notice Deposits reward tokens into the gauge
     * @dev In order to maintain consistent reward distributions the gauge should
     *     be seeded with rewards at the end of every epoch (1 week)
     * @param reward_token The address of the reward token to deposit
     * @param amount Amount of reward tokens to deposit
     */
    function deposit_reward_token(address reward_token, uint256 amount) external;
}