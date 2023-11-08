// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBloomPool is IERC20 {
    enum State {
        Other,
        Commit,
        ReadyPreHoldSwap,
        PendingPreHoldSwap,
        Holding,
        ReadyPostHoldSwap,
        PendingPostHoldSwap,
        EmergencyExit,
        FinalWithdraw
    }

    function depositLender(uint256 amount) external returns (uint256 newId);

    function state() external view returns (State currentState);

    function withdrawLender(uint256 shares) external;

    function COMMIT_PHASE_END() external view returns (uint256);
}
