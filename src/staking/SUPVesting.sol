// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {StakeUpConstants as Constants} from "../helpers/StakeUpConstants.sol";
import {StakeUpErrors as Errors} from "../helpers/StakeUpErrors.sol";

import {IStakeUpToken} from "../interfaces/IStakeUpToken.sol";
import {ISUPVesting} from "../interfaces/ISUPVesting.sol";

/**
 * @title SUPVesting
 * @notice This contract handles the vesting of SUP tokens
 * @dev All SUP tokens that a subject to vesting are held by this contract
 * and follow the following vesting schedule:
 * - 2-year linear vesting w/ a 1-year cliff
 * @dev All SUP tokens held in this vesting contract are considered to be
 * automatically staked in the StakeUp protocol
 */
abstract contract SUPVesting is ISUPVesting {
    using SafeERC20 for IERC20;

    // =================== Storage ===================
    /// @notice Total amount of STAKEUP locked in vesting
    uint256 internal _totalStakeUpVesting;

    /// @notice A mapping of user addresses to their vested token allocations
    mapping(address => VestedAllocation) internal _tokenAllocations;

    // =================== Immutables ===================
    /// @notice The STAKEUP token
    IStakeUpToken internal immutable _stakeupToken;

    // =================== Modifiers ===================
    modifier onlySUP() {
        require(msg.sender == address(_stakeupToken), Errors.UnauthorizedCaller());
        _;
    }

    // ================= Constructor =================
    constructor(address stakeupToken_) {
        require(stakeupToken_ != address(0), Errors.ZeroAddress());
        _stakeupToken = IStakeUpToken(stakeupToken_);
    }

    // =================== Functions ===================
    /// @inheritdoc ISUPVesting
    function vestTokens(address account, uint256 amount) external onlySUP {
        require(account != address(0), Errors.ZeroAddress());
        require(amount > 0, Errors.ZeroAmount());

        _updateRewardState(account);
        VestedAllocation storage allocation = _tokenAllocations[account];

        _totalStakeUpVesting += amount;

        // If this is the first time vesting for this account, set initial vesting state
        // Otherwise, update the vesting state
        if (allocation.vestingStartTime == 0) {
            _tokenAllocations[account].vestingStartTime = block.timestamp;
            _tokenAllocations[account].startingBalance = amount;
            _tokenAllocations[account].currentBalance = amount;
        } else {
            _tokenAllocations[account].startingBalance = allocation.startingBalance + amount;
            _tokenAllocations[account].currentBalance = allocation.currentBalance + amount;
        }
    }

    /// @inheritdoc ISUPVesting
    function claimAvailableTokens() external returns (uint256) {
        _updateRewardState(msg.sender);

        VestedAllocation storage allocation = _tokenAllocations[msg.sender];

        uint256 amount = availableTokens(msg.sender);

        _totalStakeUpVesting -= amount;
        allocation.currentBalance -= amount;

        if (allocation.currentBalance == 0) {
            delete _tokenAllocations[msg.sender];
        }

        IERC20(address(_stakeupToken)).safeTransfer(msg.sender, amount);

        return amount;
    }

    /// @inheritdoc ISUPVesting
    function availableTokens(address account) public view returns (uint256) {
        VestedAllocation memory allocation = _tokenAllocations[account];
        uint256 timeElapsed = _validateTimeElapsed(block.timestamp - allocation.vestingStartTime);
        uint256 claimedTokens = allocation.startingBalance - allocation.currentBalance;

        if (timeElapsed < Constants.CLIFF_DURATION) {
            return 0;
        } else {
            return (allocation.startingBalance * timeElapsed) / Constants.VESTING_DURATION - claimedTokens;
        }
    }

    /// @inheritdoc ISUPVesting
    function currentBalance(address account) public view override returns (uint256) {
        return _tokenAllocations[account].currentBalance;
    }

    /**
     * @notice Returns the time that has elapsed that is valid for vesting purposes
     * @param timeUnderVesting The time that has elapsed since the vesting start time
     */
    function _validateTimeElapsed(uint256 timeUnderVesting) internal pure returns (uint256) {
        return Math.min(timeUnderVesting, Constants.VESTING_DURATION);
    }

    /**
     * @notice Updates the global reward index and distributes rewards to the user
     * @dev A hook that is called at the beginning of the `vestTokens` & `claimAvailableTokens`function
     * @param user The user to vest tokens for
     */
    function _updateRewardState(address user) internal virtual {}
}
