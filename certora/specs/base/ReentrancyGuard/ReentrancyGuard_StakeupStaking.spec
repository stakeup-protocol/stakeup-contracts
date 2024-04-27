import "./ReentrancyGuard.spec";

//////////////////// USING ////////////////////////

using StakeUpStakingHarness as _ReentrancyGuard_StakeUpStaking;

////////////////// FUNCTIONS //////////////////////

function reentrancyIsLocked_StakeUpStaking() returns bool {
    return ghostLocked_StakeUpStaking == _REENTRANCY_GUARD_ENTERED();
}

///////////////// GHOSTS & HOOKS //////////////////

//
// Ghost copy of `_status`
//

ghost uint256 ghostLocked_StakeUpStaking {
    init_state axiom ghostLocked_StakeUpStaking == _REENTRANCY_GUARD_NOT_ENTERED();
    axiom ghostLocked_StakeUpStaking == _REENTRANCY_GUARD_NOT_ENTERED() || ghostLocked_StakeUpStaking == _REENTRANCY_GUARD_ENTERED(); 
}

hook Sload uint256 val _ReentrancyGuard_StakeUpStaking._status STORAGE {
    require(ghostLocked_StakeUpStaking == val);
}

hook Sstore _ReentrancyGuard_StakeUpStaking._status uint256 val STORAGE {
    ghostLocked_StakeUpStaking = val;
}