// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {OFTV2} from "@layerzerolabs/token/oft/v2/OFTV2.sol";

import {IAllocatedToken} from "../interfaces/IAllocatedToken.sol";

abstract contract AllocatedToken is IAllocatedToken, OFTV2 {
    mapping(address => Allocation) internal _tokenAllocations;
    
    uint256 internal constant DECIMAL_SCALING = 1e6;
    uint256 internal constant MAX_SUPPLY = 1_000_000 * DECIMAL_SCALING;
    
    // Additional reward allocations; Follow a 5-year annual halving schedule
    uint256 internal constant STUSD_USDC_REWARDS = MAX_SUPPLY * 1e5 / 1e6; // 10% of total supply
    uint256 internal constant STUSD_STETH_REWARDS = MAX_SUPPLY * 5e4 / 1e6; // 5% of total supply
    uint256 internal constant STUSD_CHAI_REWARDS = MAX_SUPPLY * 5e4 / 1e6; // 5% of total supply
    uint256 internal constant REBASE_REWARDS = MAX_SUPPLY * 1e4 / 1e6; // 1% of total supply

    constructor(
        TokenRecipient[] memory startupRecipients,
        TokenRecipient[] memory investorRecipients,
        TokenRecipient[] memory operatorRecipients,
        TokenRecipient[] memory airdropRecipients,
        address _layerZeroEndpoint
    )
        OFTV2("Stakeup Token", "SUP", 6, _layerZeroEndpoint)
    {
        _mintInitialSupply(
            startupRecipients,
            investorRecipients,
            operatorRecipients,
            airdropRecipients
        );
    }

    /**
     * @notice Mints the intial Supply of SUP tokens to the different allocations
     * and sets necessary state variables for vesting and distribution.
     * @param startupRecipients An array of TokenRecipients that will receive tokens
     * from the startupContributors allocation.
     * @param investorRecipients An array of TokenRecipients that will receive tokens
     * from the investors allocation.
     * @param operatorRecipients An array of TokenRecipients that will receive tokens
     * from the operators and technical advisors allocation.
     * @param airdropRecipients An array of TokenRecipients that will receive tokens
     * from the airdrop allocation.
     */
    function _mintInitialSupply(
        TokenRecipient[] memory startupRecipients,
        TokenRecipient[] memory investorRecipients,
        TokenRecipient[] memory operatorRecipients,
        TokenRecipient[] memory airdropRecipients
    ) internal virtual {
_setAllocations(AllocationType.startupContributors, startupRecipients);
        _setAllocations(AllocationType.investors, investorRecipients);
        _setAllocations(AllocationType.operators, operatorRecipients);
        _setAllocations(AllocationType.airdrop, airdropRecipients);
    }

    function _setAllocations(
        AllocationType allocationType,
        TokenRecipient[] memory recipients
    ) internal {
        Schedule schedule;
        uint64 percentShare;

        if (allocationType == AllocationType.startupContributors) {
            schedule = Schedule.linearVesting;
            percentShare = .21e6;
        } else if (allocationType == AllocationType.investors) {
            schedule = Schedule.linearVesting;
            percentShare = .24e6;
        } else if (allocationType == AllocationType.operators) {
            schedule = Schedule.linearVesting;
            percentShare = .09e6;
        } else if (allocationType == AllocationType.airdrop) {
            schedule = Schedule.annualHalving;
            percentShare = .03e6;
        } else {
            revert InvalidAllocationType();
        }

        _mintAllocatedShares(recipients, allocationType, schedule, percentShare);
    }

    /**
     * @notice Mints tokens for the given recipients based on their percent share
     * and sets the necessary state variables for tracking vesting and distribution.
     * @param recipients A list of TokenRecipients that will be minted tokens
     * @param allocationShare percentage of total supply that will be minted for 
     * a given allocationType
     */
    function _mintAllocatedShares(
        TokenRecipient[] memory recipients,
        AllocationType allocationType,
        Schedule schedule,
        uint64 allocationShare
    ) internal {
        uint256 sharesRemaining = allocationShare;
        uint256 length = recipients.length;

        if (sharesRemaining != 0) revert SharesNotFullyAllocated();

        for (uint256 i = 0; i < length; ++i) {
            address recipient = recipients[i].recipient;
            uint64 shares = recipients[i].percentShare;

            if (recipient == address(0)) revert InvalidRecipient();
            if (shares > sharesRemaining) revert InvalidShares();

            sharesRemaining -= shares;

            uint256 amount = MAX_SUPPLY * shares / DECIMAL_SCALING;

            _tokenAllocations[recipient] = Allocation({
                data: TypeData({
                    allocationType: allocationType,
                    totalShare: allocationShare,
                    schedule: schedule
                }),
                amountAvailable: 0, 
                amountLocked: amount
            });

            _mint(recipient, amount);
        }
        if (sharesRemaining != 0) revert SharesNotFullyAllocated();
    }
}