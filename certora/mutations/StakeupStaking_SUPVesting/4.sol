// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { IStakeupToken } from "../interfaces/IStakeupToken.sol";
import { ISUPVesting } from "../interfaces/ISUPVesting.sol";

/**
 * @title SUPVesting
 * @notice This contract handles the vesting of SUP tokens
 * @dev All SUP tokens that a subject to vesting are held by this contract
 * and follow the following vesting schedule:
 * - 3-year linear vesting w/ a 1-year cliff
 * @dev All SUP tokens held in this vesting contract are considered to be
 * automatically staked in the StakeUp protocol
 */
abstract contract SUPVesting is ISUPVesting {
    using SafeERC20 for IERC20;

    // =================== Storage ===================

    /// @notice The STAKEUP token
    IStakeupToken internal immutable _stakeupToken;

    /// @notice Total amount of STAKEUP locked in vesting
    uint256 internal _totalStakeUpVesting;

    /// @notice A mapping of user addresses to their vested token allocations
    mapping(address => VestedAllocation) internal _tokenAllocations;

    /// @notice The duration of the cliff users are subject to
    uint256 private constant CLIFF_DURATION = 52 weeks;

    /// @notice The total duration of the vesting period
    uint256 private constant VESTING_DURATION = 3 * CLIFF_DURATION;

    // =================== Modifiers ===================

    modifier onlySUP() {
        if (msg.sender != address(_stakeupToken)) revert CallerNotSUP();
        _;
    }

    // ================= Constructor =================

    constructor(address stakeupToken) {
        _stakeupToken = IStakeupToken(stakeupToken);
    }

    // =================== Functions ===================

    /// @inheritdoc ISUPVesting
    function vestTokens(address account, uint256 amount) external onlySUP {
        _vestTokens(account);

        VestedAllocation storage allocation = _tokenAllocations[account];

        _totalStakeUpVesting += amount;

        // If this is the first time vesting for this account, set initial vesting state
        // Otherwise, update the vesting state
        if (allocation.vestingStartTime == 0) {
            _tokenAllocations[account].vestingStartTime = block.timestamp;
            _tokenAllocations[account].startingBalance = amount;
            _tokenAllocations[account].currentBalance = amount;
        } else {
            _tokenAllocations[account].startingBalance =
                allocation.startingBalance +
                amount;
            _tokenAllocations[account].currentBalance =
                allocation.currentBalance +
                amount;
        }
    }

    /// @inheritdoc ISUPVesting
    function claimAvailableTokens() external returns (uint256) {
        _claimTokens(msg.sender);

        VestedAllocation storage allocation = _tokenAllocations[msg.sender];

/**************************** Diff Block Start ****************************
diff --git a/src/staking/SUPVesting.sol b/src/staking/SUPVesting.sol
index 04e70a2..788d179 100644
--- a/src/staking/SUPVesting.sol
+++ b/src/staking/SUPVesting.sol
@@ -84,7 +84,7 @@ abstract contract SUPVesting is ISUPVesting {
         uint256 amount = getAvailableTokens(msg.sender);
 
         _totalStakeUpVesting -= amount;
-        allocation.currentBalance -= amount;
+        allocation.startingBalance -= amount;
 
         if (allocation.currentBalance == 0) {
             delete _tokenAllocations[msg.sender];
**************************** Diff Block End *****************************/


        uint256 amount = getAvailableTokens(msg.sender);

        _totalStakeUpVesting -= amount;
        allocation.startingBalance -= amount;

        if (allocation.currentBalance == 0) {
            delete _tokenAllocations[msg.sender];
        }

        IERC20(address(_stakeupToken)).safeTransfer(msg.sender, amount);

        return amount;
    }

    /// @inheritdoc ISUPVesting
    function getAvailableTokens(address account) public view returns (uint256) {
        VestedAllocation memory allocation = _tokenAllocations[account];
        uint256 timeElapsed = _validateTimeElapsed(
            block.timestamp - allocation.vestingStartTime
        );
        uint256 claimedTokens = allocation.startingBalance -
            allocation.currentBalance;

        if (timeElapsed < CLIFF_DURATION) {
            return 0;
        } else {
            return
                (allocation.startingBalance * timeElapsed) /
                VESTING_DURATION -
                claimedTokens;
        }
    }

    /// @inheritdoc ISUPVesting
    function getCurrentBalance(
        address account
    ) public view override returns (uint256) {
        return _tokenAllocations[account].currentBalance;
    }

    /**
     * @notice Returns the time that has elapsed that is valid for vesting purposes
     * @param timeUnderVesting The time that has elapsed since the vesting start time
     */
    function _validateTimeElapsed(
        uint256 timeUnderVesting
    ) internal pure returns (uint256) {
        return Math.min(timeUnderVesting, VESTING_DURATION);
    }

    /**
     * @notice A hook that is called at the beginning of the `vestTokens` function
     * @param user The user to vest tokens for
     */
    function _vestTokens(address user) internal virtual {}

    /**
     * @notice A hook that is called at the beginning of the `claimAvailableTokens` function
     * @param user The user to claim tokens for
     */
    function _claimTokens(address user) internal virtual {}
}
