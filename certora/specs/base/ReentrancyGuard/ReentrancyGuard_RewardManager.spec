import "./ReentrancyGuard.spec";

//////////////////// USING ////////////////////////

using RewardManagerHarness as _ReentrancyGuard_RewardManager;

////////////////// FUNCTIONS //////////////////////

function reentrancyIsLocked_RewardManager() returns bool {
    return ghostLocked_RewardManager == _REENTRANCY_GUARD_ENTERED();
}

///////////////// GHOSTS & HOOKS //////////////////

//
// Ghost copy of `_status`
//

ghost uint256 ghostLocked_RewardManager {
    init_state axiom ghostLocked_RewardManager == _REENTRANCY_GUARD_NOT_ENTERED();
    axiom ghostLocked_RewardManager == _REENTRANCY_GUARD_NOT_ENTERED() || ghostLocked_RewardManager == _REENTRANCY_GUARD_ENTERED(); 
}

hook Sload uint256 val _ReentrancyGuard_RewardManager._status STORAGE {
    require(ghostLocked_RewardManager == val);
}

hook Sstore _ReentrancyGuard_RewardManager._status uint256 val STORAGE {
    ghostLocked_RewardManager = val;
}