import "./ERC20/ERC20_StakeupToken.spec";
import "./ERC20/IERC20.spec";
import "./ILayerZeroEndpoint.spec";

//////////////////// USING ////////////////////////

using StakeupTokenHarness as _StakeupToken;

/////////////////// METHODS ///////////////////////

methods {

    // StakeupTokenHarness
    function _StakeupToken.DECIMAL_SCALING_HARNESS() external returns (uint256) envfree;
    function _StakeupToken.MAX_SUPPLY_HARNESS() external returns (uint256) envfree;

    // StakeupToken
    function _StakeupToken.mintLpSupply(IStakeupToken.Allocation[] allocations) external;
    function _StakeupToken.airdropTokens(IStakeupToken.TokenRecipient[] recipients, uint256 percentOfTotalSupply) external;
    function _StakeupToken.mintRewards(address recipient, uint256 amount) external;
    function _StakeupToken.mintInitialSupply(IStakeupToken.Allocation[] allocations, uint256 initialMintPercentage) external;

    // Ownable2Step
    function _StakeupToken.pendingOwner() external returns (address) envfree;
    function _StakeupToken.acceptOwnership() external;

    // Ownable
    function _StakeupToken.owner() external returns (address) envfree;
    function _StakeupToken.transferOwnership(address newOwner) external;
    function _StakeupToken.renounceOwnership() external;
}

////////////////// FUNCTIONS //////////////////////

function init_StakeupToken() {
    init_ERC20_StakeupToken();
    requireInvariant totalSupplyLeqMaxSupply;
}

///////////////// PROPERTIES //////////////////////

// SUP-01 Supply can never surpass MAX_SUPPLY
invariant totalSupplyLeqMaxSupply() ghostErc20TotalSupply_StakeupToken <= to_mathint(_StakeupToken.MAX_SUPPLY_HARNESS()) {
    preserved {
        init_StakeupToken();
    }
}