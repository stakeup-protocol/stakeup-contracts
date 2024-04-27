# StakeUp - Formal Verification Report

## Summary
This document describes the specification and verification of **Blueberry**'s **StakeUp** smart contracts using the Certora Prover. The work was undertaken from February 23, 2024 to March 19, 2024.

The scope of our project was:
* StTBY token
* WstTBY token
* Rewards
* Staking
* Vesting
* StakeUp token
* RedemptionNFT

The Certora Prover proved the implementation of the contracts is correct with respect to the formal rules written by us, researchers [@alexzoid_eth](https://twitter.com/alexzoid_eth) and [@neumoXX](https://twitter.com/neumoXX). During the verification process, the Certora Prover discovered bugs in the code listed in the sections below.

The following sections formally define high level specifications of Blueberry's StakeUp smart contracts. All the rules are available in a private github: https://github.com/alexzoid-eth/Blueberryfi-StakeUp-FV/tree/main/certora.

## Disclaimer
The Certora Prover takes as input a contract and a specification and formally proves that the contract satisfies the specification in all scenarios. More importantly, the guarantees of the Certora Prover are scoped to the provided specification, and the Certora Prover does not check any cases not covered by the specification.

We hope that this information is useful, but provide no warranty of any kind, explicit or implied. The contents of this report should not be construed as a complete guarantee that the contract is secure in all dimensions. In no event shall [@neumoXX](https://twitter.com/neumoXX) or [@alexzoid_eth](https://twitter.com/alexzoid_eth) be liable for any claim, damages or other liability, whether in an action of contract, tort or otherwise, arising from, out of or in connection with the results reported here.

## Notations
✅ indicates the rule is formally verified on the latest reviewed commit.

❌ indicates the rule was violated under one of the tested versions of the code.


## Verification of StTBY

Assumptions/Simplifications:
* Assume external call to `getExchangeRate` always returns 1000000000000000000.
* Simplified function `min` of `FixedPointMathLib` library, to avoid an error in the prover.

Mutation testing
* Access the report for mutation testing [here](https://mutation-testing.certora.com/?id=83c21a44-2f5c-4f3a-9364-83833883aa6a&anonymousKey=614c444e-a5a0-4705-8c2f-23128accad39)

Properties
1. Total `StTBY` supply equals the value of underlying assets (TBYs, USDC) adjusted for scaling
* High Level
* Rule [stTBYTotalSupplyEqualsValueOfUnderlyingAssets](./specs/StTBY.spec#L19-L39)
    * Pass: ✅
2. Only calls deposits, pokes and redemptions of underlying can make amountStaked increase
* High Level
* Rule [onlyDepositsPokeAndRedeemUnderlyingCanMakeAmountStakedIncrease](./specs/StTBY.spec#L42-L71)
    * Pass: ✅
3. SUP rewards to `StTBY` depositors don't exceed the mint rewards cutoff
* High Level
* Rule [supRewardsToDepositorsDontExceedRewardsCutoff](./specs/StTBY.spec#L74-L104)
    * Pass: ✅
4. `StTBY` holder's amountStaked increase with mint reward distribution, proportional to their deposits
* High Level
* Rule [amountStakedIncreaseWithMintRewardDistribution](./specs/StTBY.spec#L107-L142)
    * Pass: ✅
5. Only calls to deposits, poke, withdraw and redemptions of underlying can make _totalUsd vary
* Valid State
* Rule [onlyDepositsPokeWithdrawAndRedeemUnderlyingCanMakeTotalUsdVary](./specs/StTBY.spec#L145-L174)
    * Pass: ✅
6. Deposits of TBY/USDC increase `StTBY` supply, adjusted for fees and scaling
* State Transitions
* Rule [depositsIncreaseStTBYSupply](./specs/StTBY.spec#L177-L215)
    * Pass: ✅
7. `StTBY` withrawals decrease total supply and total shares, and can only be made by redemption NFT contract
* State Transitions
* Rule [withdrawalsOnlyByNFTAndDecreaseStTBYSupplyAndShares](./specs/StTBY.spec#L218-L243)
    * Pass: ✅
8. When calling poke, lastRateUpdate does not change if less than 12 hours between two calls
* State Transitions
* Rule [lastRateUpdateDoesNotChangeIfLessThan12HoursBetweenPokeCalls](./specs/StTBY.spec#L246-L265)
    * Pass: ✅
9. When redeeming underlying if there is yield, totalUsd increases
* State Transitions
* Rule [whenRedeemUnderlyingIfYieldPositiveTotalUsdIncreases](./specs/StTBY.spec#L268-L282)
    * Pass: ✅
10. Fees are transferred to StakeUpStaking
* State Transitions
* Rule [feesAreTransferredToStakeUpStaking](./specs/StTBY.spec#L285-L362)
    * Pass: ✅
11. Remaining balance of underlying assets is accurate post poke
* State Transitions
* Rule [remainingBalanceAccuratePostPoke](./specs/StTBY.spec#L365-L391)
    * Pass: ✅
12. Only RedemptionNFT can withdraw
* State Transitions
* Rule [onlyRedemptionNFTCanWithdraw](./specs/StTBY.spec#L394-L405)
    * Pass: ✅
13. Only assets with underlying equal to _underlyingToken can be deposited to the contract
* State Transitions
* Rule [onlyAssetsWithCorrectUnderlyingCanBeDeposited](./specs/StTBY.spec#L408-L421)
    * Pass: ✅
14. Deposit and redeemUnderlying only support assets that are active in the Bloom registry
* State Transitions
* Rule [depositAndRedeemUnderlyingOnlySupportActiveAssets](./specs/StTBY.spec#L424-L447)
    * Pass: ✅
15. Unit tests to check consistency of functions
* Unit test
* Rule [gettersOnlyRevertIfPositiveValueSent](./specs/StTBY.spec#L450-L493)
    * Pass: ✅
* Rule [approveConsistencyCheck](./specs/StTBY.spec#L496-L513)
    * Pass: ✅
* Rule [increaseAllowanceConsistencyCheck](./specs/StTBY.spec#L516-L536)
    * Pass: ✅
* Rule [decreaseAllowanceConsistencyCheck](./specs/StTBY.spec#L539-L559)
    * Pass: ✅
* Rule [depositConsistencyCheck](./specs/StTBY.spec#L562-L585)
    * Pass: ✅
* Rule [processProceedsConsistencyCheck](./specs/StTBY.spec#L588-L603)
    * Pass: ✅
 
## Verification of WstTBY

Assumptions/Simplifications:
* N/A.

Mutation testing
* Access the report for mutation testing [here](https://mutation-testing.certora.com/?id=2e929f61-3fa6-4272-9771-d27061dc840c&anonymousKey=1947aa36-e032-4ad6-8982-a2b1ad24abdd)

Properties
1. After wrapping in `WstTBY`, balance of sender must increase
* State Transitions
* Rule [wstTBYBalanceOfSenderIncreasesAfterWrapping](./specs/WstTBY.spec#L10-L26)
    * Pass: ❌
2. After unwrapping in `WstTBY`, shares of `stTBY` of sender must increase
* State Transitions
* Rule [stTBYBalanceOfSenderIncreasesAfterUnwrapping](./specs/WstTBY.spec#L29-L45)
    * Pass: ✅
3. The total supply of `WstTBY` is always equal to the total `StTBY` shares held by the contract
* Valid States
* Invariant [wstTBYTotalSupplyEqualsStTBYShares](./specs/WstTBY.spec#L48-L55)
    * Pass: ❌
4. Unit tests to check consistency of functions
* Unit test
* Rule [wrapConsistencyCheck](./specs/WstTBY.spec#L58-L92)
    * Pass: ✅
* Rule [unwrapConsistencyCheck](./specs/WstTBY.spec#L95-L125)
    * Pass: ✅
* Rule [getWstTBYByStTBYConsistencyCheck](./specs/WstTBY.spec#L128-L140)
    * Pass: ✅
* Rule [getStTBYByWstTBYConsistencyCheck](./specs/WstTBY.spec#L143-L155)
    * Pass: ✅
* Rule [stTBYPerTokenConsistencyCheck](./specs/WstTBY.spec#L158-L169)
    * Pass: ✅
* Rule [tokensPerStTBYConsistencyCheck](./specs/WstTBY.spec#L172-L183)
    * Pass: ✅
* Rule [getStTBYConsistencyCheck](./specs/WstTBY.spec#L186-L192)
    * Pass: ✅



## Verification of Rewards

Assumptions/Simplifications:
* Summarize `deploy_gauge` as non-deterministic (to simplify execution).

Mutation testing
* Access the report for mutation testing [here](https://mutation-testing.certora.com/?id=b1245c45-3504-4ac2-a8b0-9d9a34353794&anonymousKey=6a1ee93a-1675-4328-b4d1-a3170b0c2159).

Properties
1. Rewards are minted and staked directly to the receiver's account
* High Level
* Rule [rewardsMintStakedToReceiver](./specs/RewardManager.spec#L33-L47)
    * Pass: ✅
2. Mint rewards are proportional to `stTBY` amount
* High Level
* Rule [mintRewardsProportionalStTBYAmount](./specs/RewardManager.spec#L50-L65)
    * Pass: ✅
3. After calling `distributePokeRewards` or `distributeMintRewards`, the only account that can see its stakeup balance increase is the stakeup staking contract
* State Transitions
* Rule [distributeRewardsIncreaseOnlyStakeUpStakingBalance](./specs/RewardManager.spec#L68-L82)
    * Pass: ✅
4. After calling `seedGauges`, the only accounts that can see their stakeup balance increase are the curve gauges
* State Transitions
* Rule [seedGaugesIncreaseOnlyCurveBalance](./specs/RewardManager.spec#L85-L98)
    * Pass: ✅
5. Rewards are only distributed after initialization
* State Transitions
* Rule [rewardsOnlyDistributedAfterInitialization](./specs/RewardManager.spec#L101-L125)
    * Pass: ✅
6. Only the `StTBY` contract can distribute rewards
* State Transitions
* Rule [onlyStTBYDistributeRewards](./specs/RewardManager.spec#L128-L144)
    * Pass: ✅
7. Gauge seeding does not exceed max rewards
* State Transitions
* Rule [gaugeSeedingNotExceedMaxRewards](./specs/RewardManager.spec#L147-L161)
    * Pass: ✅
8. Poke rewards decrease monotonically until depletion
* Variable Transitions
* Invariant [pokeRewardsRemainingDecrease](./specs/RewardManager.spec#L164-L169)
    * Pass: ✅
9. Gauge seeding occurs at correct intervals
* High Level
* Rule [gaugeSeedingOccursAtCorrectIntervals](./specs/RewardManager.spec#L172-L191)
    * Pass: ✅
10. The only way `_pokeRewardsRemaining` can increase is by calling initialize in the `RewardManager`
* Variable Transitions
* Rule [pokeRewardsRemainingSetInInitialized](./specs/RewardManager.spec#L194-L209)
    * Pass: ✅
11. After calling `seedGauges`, `distributePokeRewards` or `distributeMintRewards` no account can see their stakeup balance decrease
* Valid State
* Rule [noStakeUpTokenDecrease](./specs/RewardManager.spec#L212-L224)
    * Pass: ✅
12. `_calculateDripAmount` must return a value <= rewards remaining
* Valid State
* Rule [calculateDripAmountReturnLeqRewardsRemaining](./specs/RewardManager.spec#L227-L232)
    * Pass: ✅
13. `_lastSeedTimestamp` and `_poolDeploymentTimestamp` are always <= `block.timestamp`
* Valid State
* Invariant [timeStampsSolvency](./specs/base/_RewardManager.spec#L267-L272)
    * Pass: ✅
14. Total distributed rewards do not exceed `SUP_MAX_SUPPLY`
* Valid State
* Rule [totalDistributedRewardsNotExceedSUPMaxSupply](./specs/RewardManager.spec#L235-L246)
    * Pass: ✅



## Verification of Staking
Assumptions/Simplifications:
* `block.timestamp` is in the range (0 - type(uint40).max).

Mutation testing
* Access the report for mutation testing [here](https://mutation-testing.certora.com/?id=10f1e942-3e5c-424d-922f-f88a8a385691&anonymousKey=07f8192f-e757-4584-889a-ffa570e4ea04) (this includes mutations for staking and vesting).

Properties
1. Any stake or unstake action changes token balances
* State Transitions
* Invariant [stakeUnstakeMoveTokens](./specs/StakeUpStaking.spec#L36-L68)
    * Pass: ✅
2. Total staked `SUP` cannot exceed the total `SUP` supply
* Valid State
* Rule [totalStakeUpStakedLeqTotalSUPsupply](./specs/StakeUpStaking.spec#L71-L88)
    * Pass: ✅
3. Claimable rewards are calculated based on staked amounts and global reward index
* Unit test
* Rule [claimableRewardsIntegrity](./specs/StakeUpStaking.spec#L91-L106)
    * Pass: ✅
4. For all users, `userStakingData.index` is always less than or equal to `_rewardData.index`
* Valid State
* Invariant [userStakingDataIndexLeqrewardDataIndex](./specs/base/_StakeUpStaking.spec#L309)
    * Pass: ✅
5. `_lastRewardBlock` alway greater or equal to block number
* Valid State
* Invariant [lastRewardBlockGeqBlockNumber](./specs/base/_StakeUpStaking.spec#L312-L316)
    * Pass: ✅
6. For all users, `totalStakeUpStaked` changes the same way as `_stakingData[msg.sender].amountStaked`
* State Transitions
* Invariant [totalStakeUpStakedSolvency](./specs/StakeUpStaking.spec#L109-L134)
    * Pass: ✅
7. Staking balance cannot decrease unless by explicit unstake or reward claim actions
* State Transitions
* Rule [stakingBalanceCannotDecreaseUnlessUnstake](./specs/StakeUpStaking.spec#L136-L147)
    * Pass: ✅
8. For all users, `userStakingData.index` is monotonically increasing
* State Transitions
* Invariant [userStakingDataIndexIncreasing](./specs/StakeUpStaking.spec#L150-L156)
    * Pass: ✅
9. `_rewardData.index` is updated with every state modify function
* State Transitions
* Rule [rewardDataIndexUpdatePossibility](./specs/StakeUpStaking.spec#L159-L168)
    * Pass: ✅
10. The last reward distribution block is updated on every reward distribution action
* Variable Transitions
* Invariant [rewardDistributionBlockUpdatedOnEveryRewardDistribution](./specs/StakeUpStaking.spec#L171-L177)
    * Pass: ✅
11. `_rewardData.index` is monotonically increasing
* Variable Transitions
* Invariant [rewardDataIndexIncreasing](./specs/StakeUpStaking.spec#L180)
    * Pass: ✅
12. No uses's amount staked could be greater than total staked
* Valid State
* Invariant [amountStakedLeqTotalStakeUpStaked](./specs/base/_StakeUpStaking.spec#L319-L324)
    * Pass: ✅



## Verification of Vesting
Assumptions/Simplifications:
* `block.timestamp` is in the range (0 - type(uint40).max).

Properties
1. Total vested `SUP` cannot exceed the total `SUP` supply
* Valid State
* Invariant [totalVestingLeqSUPsupply](./specs/StakeUpStaking.spec#L183-L194)
    * Pass: ✅
2. Sum of `_totalStakeUpStaked` and `_totalStakeUpVesting` is always less than or equal to `IERC20(address(_stakeupToken)).balanceOf(address(VESTING_CONTRACT))`
* Valid State
* Invariant [sumOftotalStakedAndVestingLeqSUPBalanceOfCurrent](./specs/StakeUpStaking.spec#L197-L211)
    * Pass: ✅
3. Vested tokens are locked until the cliff period has passed
* Valid State
* Rule [vestedTokensLockedUntilCliffPeriodPassed](./specs/StakeUpStaking.spec#L214-L219)
    * Pass: ✅
4. For all allocations, `startingBalance` is always greater than or equal to currentBalance
* Valid State
* Invariant [startingBalanceAlwaysGeqCurrentBalance](./specs/base/_StakeUpStaking.spec#L327)
    * Pass: ✅
5. Vested tokens are released linearly after the cliff period until the end of the vesting duration
* High-Level
* Rule [vestedReleasedLinearlyAfterCliffPeriod](./specs/StakeUpStaking.spec#L222-L239)
    * Pass: ✅
6. A user's vested balance decreases as they claim vested tokens
* Variable Transitions
* Rule [userBalanceDecreasesWhenClaim](./specs/StakeUpStaking.spec#L242-L258)
    * Pass: ✅
7. The vesting start time is set upon the first vesting action for a user
* State Transitions
* Rule [vestingStartTimeSetUponAction](./specs/StakeUpStaking.spec#L261-L274)
    * Pass: ✅
8. For two timestamps after `VESTING_DURATION`, the value returned by `getAvailableTokens` should not change
* Variable Transitions
* Rule [getAvailableTokensNotChangesAfterVestingDuration](./specs/StakeUpStaking.spec#L277-L288)
    * Pass: ✅
9. Only `StakeUpToken` can execute `vestTokens()`
* State Transitions
* Rule [onlyStakeUpTokenCanExecuteVestTokens](./specs/StakeUpStaking.spec#L291-L297)
    * Pass: ✅
10. Vesting timestamp always equal or greater `block.timestamp`
* Valid State
* Invariant [vestingTimestampLeqBlockTimestamp](./specs/base/_StakeUpStaking.spec#L330-L335)
    * Pass: ✅
11. A user's token allocations empty when `block.timestamp` not set
* Valid State
* Invariant [tokenAllocationsZeroTimestampSolvency](./specs/base/_StakeUpStaking.spec#L338-L344)
    * Pass: ✅



## Verification of StakeUpToken
Assumptions/Simplifications:
* Each token balance is always less than or equal to `totalSupply`.

Mutation testing
* Access the report for mutation testing [here](https://mutation-testing.certora.com/?id=8b816f4f-8ccf-49c2-94c6-7b34b42b5373&anonymousKey=9ca355dd-a435-4b05-a67c-f5f6bb4535aa).

Properties
1. Supply can never surpass `MAX_SUPPLY`
* Valid State
* Invariant [totalSupplyLeqMaxSupply](./specs/base/_StakeUpToken.spec#L43-L47)
    * Pass: ✅
2. Ownership transfer follows the two-step process
* State Transitions
* Rule [ownershipTransferFollowsTwoStepProcess](./specs/StakeUpToken.spec#L52-L68)
    * Pass: ✅
3. Only reward manager or owner can mint
* State Transitions
* Rule [onlyRewardManagerOrOwnerCanMint](./specs/StakeUpToken.spec#L71-L86)
    * Pass: ✅
4. When minting, the increase in supply is equal to the amount allocated
* State Transitions
* Rule [mintLpSupplyIncreaseSupplySolvency](./specs/StakeUpToken.spec#L90-L107)
    * Pass: ✅
* Rule [airdropTokensIncreaseSupplySolvency](./specs/StakeUpToken.spec#L109-L122)
    * Pass: ✅
* Rule [mintRewardsIncreaseSupplySolvency](./specs/StakeUpToken.spec#L124-L135)
    * Pass: ✅
5. Airdrops, LP and initial supply minting are owner-restricted operations
* State Transitions
* Rule [onlyOwnerIntegrity](./specs/StakeUpToken.spec#L138-L145)
    * Pass: ✅
6. The contract initialization triggers the reward manager's initialization
* State Transitions
* Invariant [constructorInitialization](./specs/StakeUpToken.spec#L148-L154)
    * Pass: ✅
7. Airdrop minting respects allocation boundaries
* High Level
* Rule [airdropTokensRespectsAllocationBoundaries](./specs/StakeUpToken.spec#L157-L192)
    * Pass: ✅
8. Vesting contracts are correctly called during `mintAndVest` operations
* State Transitions
* Rule [mintAndVestCorrectlyVestTokens](./specs/StakeUpToken.spec#L195-L239)
    * Pass: ✅



## Verification of RedemptionNFT
Assumptions/Simplifications:
* N/A

Mutation testing
* Access the report for mutation testing [here](https://mutation-testing.certora.com/?id=92386e38-9a4c-4589-bbb3-20e42e5336b8&anonymousKey=10ae253e-bf43-4ed5-8a2d-268416dec338).

Properties
1. `_mintCount` is monotonically increasing
* Valid State
* Invariant [mintCountMonotonicallyIncreasing](./specs/base/_RedemptionNFT.spec#L120)
    * Pass: ✅
2. The owner of the NFT must match the owner in the withdrawal request
* Valid State
* Invariant [mintedNFTCorrespondsWithdrawalRequest](./specs/base/_RedemptionNFT.spec#L123-L124)
    * Pass: ✅
3. Each newly minted NFT must have a unique token ID
* Valid State
* Rule [mintedNFTUniqId](./specs/RedemptionNFT.spec#L32-L39)
    * Pass: ✅
4. After burn NFT, withdrawal request gets empty
* State Transitions
* Rule [afterBurnNFTWithdrawalRequestCleared](./specs/RedemptionNFT.spec#L53-L66)
    * Pass: ✅
5. After a `LayerZero` receive NFT supply is incremented by length of tokenIds array
* State Transitions
* Rule [supplyIncrementedWhenLayerZeroReceive](./specs/RedemptionNFT.spec#L69-L89)
    * Pass: ✅
6. Withdrawal requests can only be claimed once
* High Level
* Rule [withdrawalRequestsCanOnlyClaimedOnce](./specs/RedemptionNFT.spec#L92-L101)
    * Pass: ✅
7. On claim withdrawal the specified amount of shares must be withdrawn from the `StTBY` contract to the NFT owner's address
* State Transitions
* Rule [claimWithdrawalTransferStTBYToOwner](./specs/RedemptionNFT.spec#L104-L118)
    * Pass: ✅
8. Only the `StTBY` contract or `LzApp` can initiate the minting of a `RedemptionNFT`
* State Transitions
* Rule [onlyStTBYorLzAppCanMint](./specs/RedemptionNFT.spec#L121-L140)
    * Pass: ✅
9. NFTs associated with unclaimed withdrawal requests could be transferred
* State Transitions
* Rule [unclaimedWithdrawalRequestsTransferNFTPossibility](./specs/RedemptionNFT.spec#L143-L160)
    * Pass: ✅
10. Only the request owner can transfer the corresponding NFT
* State Transitions
* Rule [ownlyRequestOwerCanTransferNFT](./specs/RedemptionNFT.spec#L163-L185)
    * Pass: ✅

## Annex

### Installation

Installation instructions can be found [here](https://docs.certora.com/en/latest/docs/user-guide/getting-started/install.html?highlight=install). In short, you must install

- Java Development Kit version >= 11.
- Solidity version 0.8.22 (exactly this version).
- One can install Certora with the Python package manager Pip3, version 6.3.1 is the one used for this project.
  ```
  pip3 install certora-cli==6.3.1
  ```

To run the Certora prover you must have a valid key. If you don't have one, you can request one for free [here](https://www.certora.com/signup?plan=prover).

Once you have the key, you have to export it:
```
export CERTORAKEY=<YOUR_KEY>
```

### Execution

To run the Certora Prover against the different `spec` files of the project, you have to execute the corresponding shell script located in the `/certora/scripts/` folder.

For reference:
* /certora/scripts/redemptionNFT_run.sh
* /certora/scripts/rewardManager_run.sh
* /certora/scripts/stakeupStaking_run.sh
* /certora/scripts/stakeupToken_run.sh
* /certora/scripts/stTBY_run.sh
* /certora/scripts/wstTBY_run.sh

If you want to run a single rule, you can pass "--rule XXX" to the script. For instance:

```sh
./certora/scripts/stakeupStaking_run.sh "--rule claimableRewardsIntegrity"
```

All of them, under the hood, call `certoraRun` which is the main program to run the specs.

> Note that `stTBY_run.sh` has some modifications done to the source code because private immutables are not handled well currently by the tool, so we needed to copy the `StTBY` contract into a new _munged_ file where we changed the immutable to public. Please, have this in mind, because changes to the `StTBY.sol` file could make the execution of this file to fail, and may need to be modified accordingly.
 

### Mutations

To test the specs against mutations in the code, you can execute `certoraMutate` from the shell:

```sh
certoraMutate --prover_conf certora/confs/WstTBY.conf --mutation_conf certora/confs/mutation/WstTBY.mconf 
```

In the example above, we are using the configuration from `WstTBY.conf` for the prover and the configuration from `WstTBY.mconf` for mutations. For the rest of specs you can pass the corresponding config files.

Once all the mutations are executed, you will receive an email with a link to see the results of the mutation testing. 

Also, in `/certora/mutations/` folder there are two helper scripts regarding mutation testing:

**Create mutation**

Script `addMutation.sh`. Creates a new mutated file to be included in the mutation testing. Example:

> Modify `StTBYMunged.sol` and run the a script. A file `/mutations/StTBY/1.sol` will be created and the original will be restored.

```sh
./certora/mutations/addMutation.sh StTBY ./certora/munged/StTBYMunged.sol
```

**Check mutation**


Script `checkMutation.sh`. It runs the spec with the mutation passed as a parameter (it is convenient to use it in a separate console window). Example:

> This command will  use `StTBY.conf` with mutated file `/mutations/StTBY/1.sol` instead of `./certora/munged/StTBYMunged.sol`.

```sh
./certora/mutations/checkMutation.sh StTBY ./certora/munged/StTBYMunged.sol 1 --rule stTBYTotalSupplyEqualsValueOfUnderlyingAssets 
```



### Documentation on Certora

- The Certora documentation is located at https://docs.certora.com/en/latest/index.html
- There is a tutorial on Certora here https://github.com/Certora/Tutorials/blob/master/README.md