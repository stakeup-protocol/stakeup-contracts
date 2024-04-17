// SPDX-License-Identifier: MIT

pragma solidity 0.8.22;

import {OFT, ERC20} from "@LayerZero/oft/OFT.sol";
import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {StakeUpConstants as Constants} from "../helpers/StakeUpConstants.sol";
import {StakeUpErrors as Errors} from "../helpers/StakeUpErrors.sol";

import {IStakeupToken} from "../interfaces/IStakeupToken.sol";
import {IStakeupStaking} from "../interfaces/IStakeupStaking.sol";

contract StakeupToken is IStakeupToken, OFT, Ownable2Step {
    // =================== Storage ===================

    /// @notice Address of the StakeUp Staking contract
    address private immutable _stakeupStaking;

    /// @notice Mapping of authorized minters status'
    mapping(address => bool) private _authorizedMinters;

    // =================== Modifiers ===================

    modifier onlyAuthorized() {
        if (!_authorizedMinters[msg.sender]) {
            revert Errors.UnauthorizedCaller();
        }
        _;
    }

    // ================= Constructor =================

    constructor(
        address stakeupStaking,
        address gaugeDistributor, // Optional parameter for the gauge distributor
        address owner,
        address layerZeroEndpoint,
        address _layerZeroDelegate
    )
        OFT("Stakeup Token", "SUP", layerZeroEndpoint, _layerZeroDelegate)
        Ownable2Step()
    {
        _stakeupStaking = stakeupStaking;

        _authorizedMinters[_stakeupStaking] = true;
        _authorizedMinters[
            address(IStakeupStaking(stakeupStaking).getStTBY())
        ] = true;

        if (gaugeDistributor != address(0)) {
            _authorizedMinters[gaugeDistributor] = true;
        }

        _transferOwnership(owner);
    }

    /// @inheritdoc IStakeupToken
    function mintLpSupply(Allocation[] memory allocations) external onlyOwner {
        uint256 length = allocations.length;
        for (uint256 i = 0; i < length; ++i) {
            _mintAndVest(allocations[i], _stakeupStaking);
        }
    }

    /// @inheritdoc IStakeupToken
    function airdropTokens(
        TokenRecipient[] memory recipients,
        uint256 percentOfTotalSupply
    ) external onlyOwner {
        uint256 length = recipients.length;
        uint256 tokenAllocation = (Constants.MAX_SUPPLY *
            percentOfTotalSupply) / Constants.FIXED_POINT_ONE;
        uint256 tokensRemaining = tokenAllocation;

        for (uint256 i = 0; i < length; ++i) {
            address recipient = recipients[i].recipient;
            uint256 amount = (recipients[i].percentOfAllocation *
                tokenAllocation) / Constants.FIXED_POINT_ONE;

            if (amount > tokensRemaining) {
                revert Errors.ExceedsAvailableTokens();
            }

            tokensRemaining -= amount;
            _mint(recipient, amount);
        }
        if (tokensRemaining > 0) revert Errors.SharesNotFullyAllocated();
    }

    /// @inheritdoc IStakeupToken
    function mintRewards(
        address recipient,
        uint256 amount
    ) external override onlyAuthorized {
        _mint(recipient, amount);
    }

    /// @inheritdoc IStakeupToken
    function mintInitialSupply(
        Allocation[] memory allocations,
        uint256 initialMintPercentage
    ) external override onlyOwner {
        uint256 sharesRemaining = initialMintPercentage;
        uint256 length = allocations.length;

        for (uint256 i = 0; i < length; ++i) {
            if (sharesRemaining < allocations[i].percentOfSupply) {
                revert Errors.ExceedsAvailableTokens();
            }
            sharesRemaining -= allocations[i].percentOfSupply;
            _mintAndVest(allocations[i], _stakeupStaking);
        }
        if (totalSupply() > Constants.MAX_SUPPLY)
            revert Errors.ExceedsMaxAllocationLimit();

        if (sharesRemaining > 0) revert Errors.SharesNotFullyAllocated();
    }

    function _mintAndVest(
        Allocation memory allocation,
        address stakeupStaking
    ) internal {
        TokenRecipient[] memory recipients = allocation.recipients;
        uint256 tokensReserved = (Constants.MAX_SUPPLY *
            allocation.percentOfSupply) / Constants.FIXED_POINT_ONE;
        uint256 allocationRemaining = tokensReserved;
        uint256 length = recipients.length;

        for (uint256 i = 0; i < length; ++i) {
            address recipient = recipients[i].recipient;
            uint256 amount = (tokensReserved *
                recipients[i].percentOfAllocation) / Constants.FIXED_POINT_ONE;

            if (recipient == address(0)) revert Errors.InvalidRecipient();
            if (amount > allocationRemaining) {
                revert Errors.ExceedsAvailableTokens();
            }
            allocationRemaining -= amount;

            // Set the vesting state for this recipient in the vesting contract
            IStakeupStaking(stakeupStaking).vestTokens(recipient, amount);

            // Mint the tokens to the vesting contract
            _mint(stakeupStaking, amount);
        }
        if (allocationRemaining > 0) revert Errors.SharesNotFullyAllocated();
    }

    function transferOwnership(
        address newOwner
    ) public override(Ownable, Ownable2Step) {
        super.transferOwnership(newOwner);
    }

    function _transferOwnership(
        address newOwner
    ) internal override(Ownable, Ownable2Step) {
        super._transferOwnership(newOwner);
    }

    function _mint(address account, uint256 amount) internal override(ERC20) {
        if (totalSupply() + amount > Constants.MAX_SUPPLY) {
            revert Errors.ExceedsMaxSupply();
        }
        super._mint(account, amount);
    }
}
