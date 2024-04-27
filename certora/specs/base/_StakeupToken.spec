import "./ERC20/ERC20_StakeUpToken.spec";
import "./ERC20/IERC20.spec";
import "./ILayerZeroEndpoint.spec";

//////////////////// USING ////////////////////////

using StakeUpTokenHarness as _StakeUpToken;

/////////////////// METHODS ///////////////////////

methods {

    // StakeUpTokenHarness
    function _StakeUpToken.DECIMAL_SCALING_HARNESS() external returns (uint256) envfree;
    function _StakeUpToken.MAX_SUPPLY_HARNESS() external returns (uint256) envfree;

    // StakeUpToken
    function _StakeUpToken.mintLpSupply(IStakeUpToken.Allocation[] allocations) external;
    function _StakeUpToken.airdropTokens(IStakeUpToken.TokenRecipient[] recipients, uint256 percentOfTotalSupply) external;
    function _StakeUpToken.mintRewards(address recipient, uint256 amount) external;
    function _StakeUpToken.mintInitialSupply(IStakeUpToken.Allocation[] allocations, uint256 initialMintPercentage) external;

    // Ownable2Step
    function _StakeUpToken.pendingOwner() external returns (address) envfree;
    function _StakeUpToken.acceptOwnership() external;

    // Ownable
    function _StakeUpToken.owner() external returns (address) envfree;
    function _StakeUpToken.transferOwnership(address newOwner) external;
    function _StakeUpToken.renounceOwnership() external;
}

////////////////// FUNCTIONS //////////////////////

function init_StakeUpToken() {
    init_ERC20_StakeUpToken();
    requireInvariant totalSupplyLeqMaxSupply;
}

///////////////// PROPERTIES //////////////////////

// SUP-01 Supply can never surpass MAX_SUPPLY
invariant totalSupplyLeqMaxSupply() ghostErc20TotalSupply_StakeUpToken <= to_mathint(_StakeUpToken.MAX_SUPPLY_HARNESS()) {
    preserved {
        init_StakeUpToken();
    }
}