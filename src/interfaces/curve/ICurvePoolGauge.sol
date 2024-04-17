// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

interface ICurvePoolGauge {
    /**
     * @notice Get the reward token associated with a gauge at a given index
     * @param index Index of the reward token to get
     * @return Address of the reward token at the given index
     */
    function reward_tokens(uint256 index) external view returns (address);

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
    function deposit_reward_token(
        address reward_token,
        uint256 amount
    ) external;

    /**
     * @notice Sets the gauge manager
     * @dev This is a permissioned function that can only be called by the gauge manager or factory admin
     * @param _gauge_manager The address of the new gauge manager
     */
    function set_gauge_manager(address _gauge_manager) external;
}
