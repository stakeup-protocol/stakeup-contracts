// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {OFTV2, ERC20} from "@layerzerolabs/token/oft/v2/OFTV2.sol";
import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {IRewardManager} from "../interfaces/IRewardManager.sol";
import {IStakeupToken} from "../interfaces/IStakeupToken.sol";
import {ISUPVesting} from "../interfaces/ISUPVesting.sol";

contract StakeupToken is IStakeupToken, Ownable2Step, OFTV2 {
    address private _vestingContract;
    address private _rewardManager;

    uint256 internal constant DECIMAL_SCALING = 1e18;
    uint256 internal constant MAX_SUPPLY = 1_000_000_000 * DECIMAL_SCALING;
    uint256 internal constant REWARD_SUPPLY =
        (MAX_SUPPLY * 23e4) / DECIMAL_SCALING; // 23% of total supply

    modifier onlyManager() {
        if (msg.sender != _rewardManager) revert CallerNotRewardManager();
        _;
    }

    constructor(
        address layerZeroEndpoint,
        address vestingContract,
        address rewardManager,
        address owner
    ) OFTV2("Stakeup Token", "SUP", 6, layerZeroEndpoint) Ownable2Step() {
        _vestingContract = vestingContract;
        _rewardManager = rewardManager;

        IRewardManager(rewardManager).initialize();

        _transferOwnership(owner);
    }

    function mintLpSupply(Allocation[] memory allocations) external onlyOwner {
        uint256 length = allocations.length;
        for (uint256 i = 0; i < length; i++) {
            _mintAndVest(allocations[i], _vestingContract, MAX_SUPPLY);
        }
    }

    function airdropTokens(
        TokenRecipient[] memory recipients,
        uint256 percentOfTotalSupply
    ) external onlyOwner {
        uint256 length = recipients.length;
        uint256 tokenAllocation = (MAX_SUPPLY * percentOfTotalSupply) /
            DECIMAL_SCALING;
        uint256 tokensRemaining = tokenAllocation;

        for (uint256 i = 0; i < length; i++) {
            address recipient = recipients[i].recipient;
            uint256 amount = (recipients[i].percentOfAllocation *
                tokenAllocation) / DECIMAL_SCALING;

            if (amount > tokensRemaining) revert ExceedsAvailableTokens();

            tokensRemaining -= amount;
            _mint(recipient, amount);
        }
        if (tokensRemaining > 0) revert SharesNotFullyAllocated();
    }

    function mintRewards(address recipient, uint256 amount) external override onlyManager {
        _mint(recipient, amount);
    }

    function mintInitialSupply(
        Allocation[] memory allocations,
        address vestingContract,
        uint256 initialMintPercentage
    ) external override onlyOwner {
        uint256 maxSupply = MAX_SUPPLY;
        uint256 sharesRemaining = initialMintPercentage;
        uint256 length = allocations.length;

        for (uint256 i = 0; i < length; i++) {
            if (sharesRemaining < allocations[i].percentOfSupply) {
                revert ExceedsAvailableTokens();               
            }
            sharesRemaining -= allocations[i].percentOfSupply;
            _mintAndVest(allocations[i], vestingContract, maxSupply);
        }
        if (sharesRemaining > 0) revert SharesNotFullyAllocated();
    }

    function _mintAndVest(
        Allocation memory allocation,
        address vestingContract,
        uint256 maxTokenSupply
    ) internal {
        TokenRecipient[] memory recipients = allocation.recipients;
        uint256 tokensReserved = (maxTokenSupply * allocation.percentOfSupply) /
            DECIMAL_SCALING;
        uint256 allocationRemaining = tokensReserved;
        uint256 length = recipients.length;

        for (uint256 i = 0; i < length; i++) {
            address recipient = recipients[i].recipient;
            uint256 amount = (tokensReserved *
                recipients[i].percentOfAllocation) / DECIMAL_SCALING;

            if (recipient == address(0)) revert InvalidRecipient();
            if (amount > allocationRemaining) revert ExceedsAvailableTokens();
            allocationRemaining -= amount;

            // Set the vesting state for this recipient in the vesting contract
            ISUPVesting(vestingContract).vestTokens(recipient, amount);

            // Mint the tokens to the vesting contract
            _mint(vestingContract, amount);
        }
        if (allocationRemaining > 0) revert SharesNotFullyAllocated();
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
        if (totalSupply() + amount > MAX_SUPPLY) revert ExceedsMaxSupply();
        super._mint(account, amount);
    }
}
