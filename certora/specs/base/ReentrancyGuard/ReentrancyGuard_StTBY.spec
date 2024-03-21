import "./ReentrancyGuard.spec";

//////////////////// USING ////////////////////////

using StTBYHarness as _ReentrancyGuard_StTBY;

////////////////// FUNCTIONS //////////////////////

function reentrancyIsLocked_StTBY() returns bool {
    return ghostLocked_StTBY == _REENTRANCY_GUARD_ENTERED();
}

///////////////// GHOSTS & HOOKS //////////////////

//
// Ghost copy of `_status`
//

ghost uint256 ghostLocked_StTBY {
    init_state axiom ghostLocked_StTBY == _REENTRANCY_GUARD_NOT_ENTERED();
    axiom ghostLocked_StTBY == _REENTRANCY_GUARD_NOT_ENTERED() || ghostLocked_StTBY == _REENTRANCY_GUARD_ENTERED(); 
}

hook Sload uint256 val _ReentrancyGuard_StTBY._status STORAGE {
    require(ghostLocked_StTBY == val);
}

hook Sstore _ReentrancyGuard_StTBY._status uint256 val STORAGE {
    ghostLocked_StTBY = val;
}