import "./base/_StakeUpToken.spec";
import "./base/_StakeUpStaking.spec";
import "./base/_RewardManager.spec";
import "./base/OFT.spec";

/////////////////// METHODS ///////////////////////

methods {

    // IRewardManager
    function _.initialize() external => rewardManagerInitializeCVL() expect void;
}

////////////////// FUNCTIONS //////////////////////

ghost bool rewardManagerInitializeCalled;
function rewardManagerInitializeCVL() {
    rewardManagerInitializeCalled = true;
}

///////////////// DEFINITIONS /////////////////////

definition ONLY_OWNER_FUNCTIONS(method f) returns bool =
    f.selector == sig:mintLpSupply(IStakeUpToken.Allocation[]).selector
    || f.selector == sig:airdropTokens(IStakeUpToken.TokenRecipient[], uint256).selector
    || f.selector == sig:mintInitialSupply(IStakeUpToken.Allocation[], uint256).selector;

definition LZ_FUNCTIONS(method f) returns bool =
    f.selector == sig:sendFrom(address, uint16, bytes, uint, address, address, bytes).selector;

///////////////// PROPERTIES //////////////////////

use builtin rule sanity; 

// StakeUpToken valid state
use invariant totalSupplyLeqMaxSupply;

// RewardManager valid state
use invariant startTimestampValue;
use invariant pokeRewardsRemainingLimitationInv;
use invariant timeStampsSolvency;

// StakeUpStaking valid state
use invariant amountStakedLeqTotalStakeUpStaked;
use invariant vestingTimestampLeqBlockTimestamp;
use invariant lastRewardBlockGeqBlockNumber;
use invariant userStakingDataIndexLeqrewardDataIndex;
use invariant startingBalanceAlwaysGeqCurrentBalance;
use invariant tokenAllocationsZeroTimestampSolvency;

// SUP-02 Ownership transfer follows the two-step process
rule ownershipTransferFollowsTwoStepProcess(env e, method f, calldataarg args) {

    address ownerBefore = owner();
    address pendingOwner = pendingOwner();

    f(e, args);

    address ownerAfter = owner();

    assert(ownerBefore != ownerAfter 
            // acceptOwnership()
        => (ownerAfter == pendingOwner && ownerAfter == e.msg.sender
            // renounceOwnership()
            || ownerAfter == 0
        )
        );
}

// SUP-03 Only reward manager or owner can mint
rule onlyRewardManagerOrOwnerCanMint(env e, method f, calldataarg args) filtered { f -> !LZ_FUNCTIONS(f) } {

    bool isOnlyRewardManagerOrOwner = 
        e.msg.sender == _RewardManager 
        || e.msg.sender == owner()
        || e.msg.sender == currentContract;

    mathint totalSupplyBefore = ghostErc20TotalSupply_StakeUpToken;

    f@withrevert(e, args);
    bool reverted = lastReverted;

    bool minted = ghostErc20TotalSupply_StakeUpToken > totalSupplyBefore;

    assert(minted && !isOnlyRewardManagerOrOwner => reverted);
}

// SUP-04 When minting, the increase in supply is equal to the amount allocated

rule mintLpSupplyIncreaseSupplySolvency(env e, IStakeUpToken.Allocation[] allocations) {

    init_StakeUpToken();

    mathint totalSupplyBefore = ghostErc20TotalSupply_StakeUpToken;

    require(allocations.length <= 2);
    mintLpSupply(e, allocations);

    mathint totalSupplyAfter = ghostErc20TotalSupply_StakeUpToken;

    mathint percentOfSupply1 = allocations.length > 0 ? allocations[0].percentOfSupply : 0;
    mathint amount0 = (to_mathint(MAX_SUPPLY_HARNESS()) * percentOfSupply1) / to_mathint(DECIMAL_SCALING_HARNESS());
    mathint percentOfSupply2 = allocations.length > 1 ? allocations[1].percentOfSupply : 0;
    mathint amount1 = (to_mathint(MAX_SUPPLY_HARNESS()) * percentOfSupply2) / to_mathint(DECIMAL_SCALING_HARNESS());

    assert(totalSupplyAfter > totalSupplyBefore => totalSupplyAfter - totalSupplyBefore == amount0 + amount1);
}

rule airdropTokensIncreaseSupplySolvency(env e, uint256 percentOfTotalSupply, IStakeUpToken.TokenRecipient[] recipients) {

    init_StakeUpToken();

    mathint totalSupplyBefore = ghostErc20TotalSupply_StakeUpToken;

    airdropTokens(e, recipients, percentOfTotalSupply);

    mathint amount = (to_mathint(MAX_SUPPLY_HARNESS()) * to_mathint(percentOfTotalSupply)) / to_mathint(DECIMAL_SCALING_HARNESS());

    mathint totalSupplyAfter = ghostErc20TotalSupply_StakeUpToken;

    assert(totalSupplyAfter > totalSupplyBefore => totalSupplyAfter - totalSupplyBefore == amount);
}

rule mintRewardsIncreaseSupplySolvency(env e, address recipient, uint256 amount) {

    init_StakeUpToken();

    mathint totalSupplyBefore = ghostErc20TotalSupply_StakeUpToken;

    mintRewards(e, recipient, amount);

    mathint totalSupplyAfter = ghostErc20TotalSupply_StakeUpToken;

    assert(totalSupplyAfter > totalSupplyBefore => totalSupplyAfter - totalSupplyBefore == to_mathint(amount));
}

// SUP-05 Airdrops, LP and initial supply minting are owner-restricted operations
rule onlyOwnerIntegrity(env e, method f, calldataarg args)
    filtered { f -> ONLY_OWNER_FUNCTIONS(f)  } {

    f@withrevert(e, args);
    bool reverted = lastReverted;

    assert(!reverted => e.msg.sender == owner());
}

// SUP-06 The contract initialization triggers the reward manager's initialization
invariant constructorInitialization() rewardManagerInitializeCalled
    filtered { f -> f.selector == 0 } {
    preserved {
        require(rewardManagerInitializeCalled == false);
        require(false);
    }
}

// SUP-07 Airdrop minting respects allocation boundaries
rule airdropTokensRespectsAllocationBoundaries(env e, uint256 percentOfTotalSupply, IStakeUpToken.TokenRecipient[] recipients) {
    
    init_StakeUpToken();

    require(recipients.length <= 2);
    
    address recipient1 = recipients[0].recipient;
    address recipient2 = recipients[1].recipient;
    require(recipient1 != 0 && recipient2 != 0 => recipient1 != recipient2);

    // Allocations
    mathint tokenAllocation = (to_mathint(MAX_SUPPLY_HARNESS()) * percentOfTotalSupply) / to_mathint(DECIMAL_SCALING_HARNESS());
    mathint recipient1Tokens = recipients.length >= 1 
        ? (to_mathint(recipients[0].percentOfAllocation) * tokenAllocation) / to_mathint(DECIMAL_SCALING_HARNESS())
        : 0;
    mathint recipient2Tokens = recipients.length >= 2 
        ? (to_mathint(recipients[1].percentOfAllocation) * tokenAllocation) / to_mathint(DECIMAL_SCALING_HARNESS())
        : 0;

    // SUP balance before
    mathint balanceBefore1 = ghostErc20Balances_StakeUpToken[recipient1];
    mathint balanceBefore2 = ghostErc20Balances_StakeUpToken[recipient2];

    airdropTokens(e, recipients, percentOfTotalSupply);

    // SUP balance after
    mathint balanceAfter1 = ghostErc20Balances_StakeUpToken[recipient1];
    mathint balanceAfter2 = ghostErc20Balances_StakeUpToken[recipient2];

    // Balance increase to allocation amount
    assert(balanceAfter1 - balanceBefore1 == recipient1Tokens);
    assert(balanceAfter2 - balanceBefore2 == recipient2Tokens);

    // Total allocation solvency
    assert(tokenAllocation == recipient1Tokens + recipient2Tokens);
}

// SUP-08 Vesting contracts are correctly called during mintAndVest operations
rule mintAndVestCorrectlyVestTokens(env e, IStakeUpToken.Allocation[] allocations) {

    init_StakeUpToken();
    init_StakeUpStaking(e);

    // One allocation with two recipients
    require(allocations.length == 1);
    require(allocations[0].recipients.length <= 2);

    address recipient1 = allocations[0].recipients[0].recipient;
    address recipient2 = allocations[0].recipients[1].recipient;
    require(recipient1 != 0 && recipient2 != 0 => recipient1 != recipient2);

    // Allocations
    mathint tokensReserved = (to_mathint(MAX_SUPPLY_HARNESS()) * allocations[0].percentOfSupply) / to_mathint(DECIMAL_SCALING_HARNESS());
    mathint recipient1Tokens = allocations[0].recipients.length >= 1 
        ? (tokensReserved * to_mathint(allocations[0].recipients[0].percentOfAllocation)) / to_mathint(DECIMAL_SCALING_HARNESS())
        : 0;
    mathint recipient2Tokens = allocations[0].recipients.length >= 2 
        ? (tokensReserved * to_mathint(allocations[0].recipients[1].percentOfAllocation)) / to_mathint(DECIMAL_SCALING_HARNESS())
        : 0;

    // Vesting balances before
    mathint startingBalance1Before = ghostTAStartingBalance[recipient1];
    mathint currentBalance1Before = ghostTACurrentBalance[recipient1];
    mathint startingBalance2Before = ghostTAStartingBalance[recipient2];
    mathint currentBalance2Before = ghostTACurrentBalance[recipient2];

    mintLpSupply(e, allocations);

    // Vesting balances after
    mathint startingBalance1After = ghostTAStartingBalance[recipient1];
    mathint currentBalance1After = ghostTACurrentBalance[recipient1];
    mathint startingBalance2After = ghostTAStartingBalance[recipient2];
    mathint currentBalance2After = ghostTACurrentBalance[recipient2];

    // Allocated equal to vesting increase
    assert(startingBalance1After - startingBalance1Before == recipient1Tokens);
    assert(currentBalance1After - currentBalance1Before == recipient1Tokens);
    assert(startingBalance2After - startingBalance2Before == recipient2Tokens);
    assert(currentBalance2After - currentBalance2Before == recipient2Tokens);

    // Total allocation solvency
    assert(tokensReserved == recipient1Tokens + recipient2Tokens);
}

