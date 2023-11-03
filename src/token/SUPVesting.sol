// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {StakeupToken} from "../token/StakeupToken.sol";
import {ISUPVesting} from "../interfaces/ISUPVesting.sol";

/**
 * @title SUPVesting
 * @notice This contract handles the vesting of SUP tokens
 * @dev All SUP tokens that a subject to vesting are held by this contract
 * and follow the following vesting schedule:
 * - 3-year linear vesting w/ a 1-year cliff
 * @dev All SUP tokens held in this vesting contract are considered to be 
 * automatically staked in the StakeUp protocol
 */
contract SUPVesting is ISUPVesting {
    using SafeERC20 for StakeupToken;

    StakeupToken private _token;

    uint256 private constant CLIFF_DURATION = 365 days;
    uint256 private constant VESTING_DURATION = 3 * 365 days;

    mapping(address => VestedAllocation) private _tokenAllocations;

    modifier onlySUP() {
        require(msg.sender == address(_token), "CallerNotSUP");
        _;
    }

    constructor(StakeupToken token) {
        _token = token;
    }

    function getAvailableTokens(address account) public view returns (uint256) {
        VestedAllocation memory allocation = _tokenAllocations[account];
        uint256 timeElapsed = block.timestamp - allocation.vestingStartTime;

        if (timeElapsed < CLIFF_DURATION) {
            return 0;
        } else {
            return
                (allocation.startingBalance * timeElapsed) / VESTING_DURATION;
        }
    }

    function vestTokens(address account, uint256 amount) external onlySUP {
        VestedAllocation storage allocation = _tokenAllocations[account];

        // If this is the first time vesting for this account, set initial vesting state
        // Otherwise, update the vesting state
        if (allocation.vestingStartTime == 0) {
            _tokenAllocations[account].vestingStartTime = block.timestamp;
            _tokenAllocations[account].startingBalance = amount;
            _tokenAllocations[account].currentBalance = amount;
        } else {
            _tokenAllocations[account].startingBalance =
                allocation.startingBalance + amount;
            _tokenAllocations[account].currentBalance =
                allocation.currentBalance + amount;
        }
    }

    function claimAvailableTokens() external returns (uint256) {
        VestedAllocation storage allocation = _tokenAllocations[msg.sender];
        uint32 amount = uint32(getAvailableTokens(msg.sender));

        allocation.currentBalance -= amount;

        if (allocation.currentBalance == 0) {
            delete _tokenAllocations[msg.sender];
        }

        _token.safeTransfer(msg.sender, amount);

        return amount;
    }

    function getCurrentBalance(
        address account
    ) external view override returns (uint256) {
        return _tokenAllocations[account].currentBalance;
    }

    function getSUPToken() external view override returns (address) {
        return address(_token);
    }
}