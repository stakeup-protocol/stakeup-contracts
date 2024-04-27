// SPDX-License-Identifier: MIT

pragma solidity 0.8.22;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {OFT, ERC20} from "@layerzerolabs/token/oft/v1/OFT.sol";
import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {IRewardManager} from "../interfaces/IRewardManager.sol";
import {IStakeUpToken} from "../interfaces/IStakeUpToken.sol";
import {IStakeUpStaking} from "../interfaces/IStakeUpStaking.sol";

contract StakeUpToken is IStakeUpToken, OFT, Ownable2Step {
    address private immutable _stakeupStaking;
    address private immutable _rewardManager;

    uint256 internal constant DECIMAL_SCALING = 1e18;
    uint256 internal constant MAX_SUPPLY = 1_000_000_000 * DECIMAL_SCALING;

    modifier onlyManager() {
        if (msg.sender != _rewardManager) revert CallerNotRewardManager();
        _;
    }

    constructor(
        address layerZeroEndpoint,
        address stakeupStaking,
        address rewardManager,
        address owner
    ) OFT("StakeUp Token", "SUP", layerZeroEndpoint) Ownable2Step() {
        _stakeupStaking = stakeupStaking;
        _rewardManager = rewardManager;

        IRewardManager(rewardManager).initialize();

        _transferOwnership(owner);
    }

    /// @inheritdoc IStakeUpToken
    function mintLpSupply(Allocation[] memory allocations) external onlyOwner {
        uint256 length = allocations.length;
        for (uint256 i = 0; i < length; ++i) {
            _mintAndVest(allocations[i], _stakeupStaking);
        }
    }

    /// @inheritdoc IStakeUpToken
    function airdropTokens(
        TokenRecipient[] memory recipients,
        uint256 percentOfTotalSupply
    ) external onlyOwner {
        uint256 length = recipients.length;
        uint256 tokenAllocation = (MAX_SUPPLY * percentOfTotalSupply) /
            DECIMAL_SCALING;
        uint256 tokensRemaining = tokenAllocation;

        for (uint256 i = 0; i < length; ++i) {
            address recipient = recipients[i].recipient;
            uint256 amount = (recipients[i].percentOfAllocation *
                tokenAllocation) / DECIMAL_SCALING;

            if (amount > tokensRemaining) revert ExceedsAvailableTokens();

            tokensRemaining -= amount;
            _mint(recipient, amount);
        }
        if (tokensRemaining > 0) revert SharesNotFullyAllocated();
    }

    /// @inheritdoc IStakeUpToken
    function mintRewards(address recipient, uint256 amount) external override onlyManager {
        _mint(recipient, amount);
    }

    /// @inheritdoc IStakeUpToken
    function mintInitialSupply(
        Allocation[] memory allocations,
        uint256 initialMintPercentage
    ) external override onlyOwner {
        uint256 sharesRemaining = initialMintPercentage;
        uint256 length = allocations.length;

        for (uint256 i = 0; i < length; ++i) {
            if (sharesRemaining < allocations[i].percentOfSupply) {
                revert ExceedsAvailableTokens();               
            }
            sharesRemaining -= allocations[i].percentOfSupply;
            _mintAndVest(allocations[i], _stakeupStaking);
        }
        if (totalSupply() > MAX_SUPPLY) revert ExceedsMaxAllocationLimit();

        if (sharesRemaining > 0) revert SharesNotFullyAllocated();
    }

    function _mintAndVest(
        Allocation memory allocation,
        address stakeupStaking
    ) internal {
        TokenRecipient[] memory recipients = allocation.recipients;
        uint256 tokensReserved = (MAX_SUPPLY * allocation.percentOfSupply) /
            DECIMAL_SCALING;
        uint256 allocationRemaining = tokensReserved;
        uint256 length = recipients.length;

        for (uint256 i = 0; i < length; ++i) {
            address recipient = recipients[i].recipient;
            uint256 amount = (tokensReserved *
                recipients[i].percentOfAllocation) / DECIMAL_SCALING;

            if (recipient == address(0)) revert InvalidRecipient();
            if (amount > allocationRemaining) revert ExceedsAvailableTokens();
            allocationRemaining -= amount;

            // Set the vesting state for this recipient in the vesting contract
            IStakeUpStaking(stakeupStaking).vestTokens(recipient, amount);

            // Mint the tokens to the vesting contract
            _mint(stakeupStaking, amount);
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

/**************************** Diff Block Start ****************************
diff --git a/src/token/StakeUpToken.sol b/src/token/StakeUpToken.sol
index 59fe17b..3146487 100644
--- a/src/token/StakeUpToken.sol
+++ b/src/token/StakeUpToken.sol
@@ -133,7 +133,7 @@ contract StakeUpToken is IStakeUpToken, OFT, Ownable2Step {
     }
 
     function _mint(address account, uint256 amount) internal override(ERC20) {
-        if (totalSupply() + amount > MAX_SUPPLY) revert ExceedsMaxSupply();
+        if (totalSupply() > MAX_SUPPLY) revert ExceedsMaxSupply();
         super._mint(account, amount);
     }
 }
**************************** Diff Block End *****************************/

        super._transferOwnership(newOwner);
    }

    function _mint(address account, uint256 amount) internal override(ERC20) {
        if (totalSupply() > MAX_SUPPLY) revert ExceedsMaxSupply();
        super._mint(account, amount);
    }
}
