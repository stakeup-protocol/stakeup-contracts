import "./ReentrancyGuard.spec";

//////////////////// USING ////////////////////////

using StakeupStakingHarness as _ReentrancyGuard_StakeupStaking;

////////////////// FUNCTIONS //////////////////////

function reentrancyIsLocked_StakeupStaking() returns bool {
    return ghostLocked_StakeupStaking == _REENTRANCY_GUARD_ENTERED();
}

///////////////// GHOSTS & HOOKS //////////////////

//
// Ghost copy of `_status`
//

ghost uint256 ghostLocked_StakeupStaking {
    init_state axiom ghostLocked_StakeupStaking == _REENTRANCY_GUARD_NOT_ENTERED();
    axiom ghostLocked_StakeupStaking == _REENTRANCY_GUARD_NOT_ENTERED() || ghostLocked_StakeupStaking == _REENTRANCY_GUARD_ENTERED(); 
}

hook Sload uint256 val _ReentrancyGuard_StakeupStaking._status STORAGE {
    require(ghostLocked_StakeupStaking == val);
}

hook Sstore _ReentrancyGuard_StakeupStaking._status uint256 val STORAGE {
    ghostLocked_StakeupStaking = val;
}