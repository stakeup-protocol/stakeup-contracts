// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {ICurvePoolGauge} from "src/interfaces/curve/ICurvePoolGauge.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockCurveGauge is ICurvePoolGauge {
    address private _rewardToken;
    address private _distributor;

    function add_reward(
        address reward_token,
        address distributor
    ) external override {
        _rewardToken = reward_token;
        _distributor = distributor;
    }

    function deposit_reward_token(
        address reward_token,
        uint256 amount
    ) external override {
        if (msg.sender != _distributor) revert("Invalid caller");
        IERC20(reward_token).transferFrom(msg.sender, address(this), amount);
    }

    function set_gauge_manager(address _gauge_manager) external override {}

    function reward_tokens(
        uint256 index
    ) external view override returns (address) {}
}