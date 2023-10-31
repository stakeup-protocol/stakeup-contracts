// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {AllocatedToken} from "./AllocatedToken.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

error ExceedsAvailableTokens();
contract StakeupToken is AllocatedToken {

    uint256 private _startTime;
    uint256 private constant CLIFF_DURATION = 365 days;
    uint256 private constant VESTING_DURATION = 3 * 365 days;
    uint256 private constant FIVE_YEARS = 5 * 365 days;

    constructor(
        TokenRecipient[] memory startupRecipients,
        TokenRecipient[] memory investorRecipients,
        TokenRecipient[] memory operatorRecipients,
        TokenRecipient[] memory airdropRecipients,
        address _layerZeroEndpoint
    )
        AllocatedToken(
            startupRecipients,
            investorRecipients,
            operatorRecipients,
            airdropRecipients,
            _layerZeroEndpoint
        )
    {
        _startTime = block.timestamp;        
    }

    function getAvailableTokens(address account) public returns (uint256) {
        Allocation memory allocation = _tokenAllocations[account];
        uint256 timeElapsed = block.timestamp - _startTime;
        uint256 balance = balanceOf(account);

        if (
            allocation.data.schedule == Schedule.standardMint
            || allocation.data.allocationType == AllocationType.nullValue
            || timeElapsed > FIVE_YEARS
        ) {
            return balance;
        }

        bool isSubjectToCliff = (allocation.data.schedule == Schedule.linearVesting);

        if (isSubjectToCliff) {
            if (timeElapsed < CLIFF_DURATION) {
                return 0;
            } else {
                uint256 month = (VESTING_DURATION - CLIFF_DURATION) / 24;
                // TODO: FIX MATH
                uint256 monthsVested = (timeElapsed - CLIFF_DURATION) / month;
                uint256 amountVested = (allocation.amountAvailable + allocation.amountLocked) * (monthsVested + VESTING_DURATION) / 36;
                uint256 amountLocked = allocation.amountAvailable + allocation.amountLocked - amountVested;
                _tokenAllocations[account].amountAvailable = amountVested;
                _tokenAllocations[account].amountLocked = amountLocked;
                return balance - amountLocked;
            }
        }

        if (allocation.data.schedule == Schedule.annualHalving) {
            uint256 year = timeElapsed / 365 days;
            uint256 amountVested = (allocation.amountAvailable + allocation.amountLocked) / (2 ** year);
            uint256 amountLocked = allocation.amountAvailable + allocation.amountLocked - amountVested;
            _tokenAllocations[account].amountAvailable = amountVested;
            _tokenAllocations[account].amountLocked = amountLocked;
            return balance - amountLocked;
        }

        return _tokenAllocations[account].amountAvailable;
    }

    function transfer(address _recipient, uint256 amount) public override returns (bool) {
        uint256 availableTokens = getAvailableTokens(msg.sender);
        if (amount <= availableTokens) revert ExceedsAvailableTokens();
        require(amount <= availableTokens, "StakeupToken: transfer amount exceeds available tokens");
        _transfer(msg.sender, _recipient, amount);
        return true;
    }

    function transferFrom(address _sender, address _recipient, uint256 amount) public override returns (bool) {
        uint256 availableTokens = getAvailableTokens(_sender);
        if (amount <= availableTokens) revert ExceedsAvailableTokens();
        _transfer(_sender, _recipient, amount);
        return true;
    }
    
}
