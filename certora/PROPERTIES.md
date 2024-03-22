# Introduction
In this document we present a list of properties identified on the set of contracts in scope, during the first phase of the project.

This is a non exhaustive list that should allow us to build the rules and invariants in Certora's CVL that will ensure the `stTBY` project runs as expected. During the process of implementing these rules / invariants, this list is subject to change.

We are looking forward to receiving feedback from Blueberry's team, either confirming / denying the properties below are correct, or providing additional properties we failed to identify.

# Properties

List of properties following the categorization by [Certora](https://github.com/Certora/Tutorials/blob/master/06.Lesson_ThinkingProperties/Categorizing_Properties.pdf):

- High Level
- Valid States
- State Transitions
- Variable Transitions
- Unit Tests

## StTBY

| Property | Description | Category | Tested |
| --- | --- | --- | --- |
| ST-01 | Total `StTBY` supply equals the value of underlying assets (TBYs, USDC) adjusted for scaling | High Level | ✅ |
| ST-02 | Only calls deposits, pokes and redemptions of underlying can make amountStaked increase | High Level | ✅ |
| ST-03 | SUP rewards to `StTBY` depositors don't exceed the mint rewards cutoff | High Level | ✅ |
| ST-04 | `StTBY` holder's amountStaked increase with mint reward distribution, proportional to their deposits | High Level | ✅ |
| ST-05 | Only calls to deposits, poke, withdraw and redemptions of underlying can make _totalUsd vary | Valid State | ✅ |
| ST-06 | Deposits of TBY/USDC increase `StTBY` supply, adjusted for fees and scaling | State Transitions | ✅ |
| ST-07 | `StTBY` withrawals decrease total supply and total shares, and can only be made by redemption NFT contract | State Transitions | ✅ |
| ST-08 | When calling poke, lastRateUpdate does not change if less than 12 hours between two calls | State Transitions | ✅ |
| ST-09 | When redeeming underlying if there is yield, totalUsd increases | State Transitions | ✅ |
| ST-10 | Fees are transferred to StakeupStaking | State Transitions | ✅ |
| ST-11 | Remaining balance of underlying assets is accurate post poke | State Transitions | ✅ |
| ST-12 | Only RedemptionNFT can withdraw | State Transitions | ✅ |
| ST-13 | Only assets with underlying equal to _underlyingToken can be deposited to the contract | State Transitions | ✅ |
| ST-14 | Deposit and redeemUnderlying only support assets that are active in the Bloom registry | State Transitions | ✅ |
| ST-15 | Unit tests to check consistency of functions | Unit test | ✅ |

## WstTBY

| Property | Description | Category | Tested |
| --- | --- | --- | --- |
| WST-01 | After wrapping in `WstTBY`, balance of sender must increase | State Transitions | ✅ |
| WST-02 | After unwrapping in `WstTBY`, shares of `stTBY` of sender must increase | State Transitions | ✅ |
| WST-03 | The total supply of `WstTBY` is always equal to the total `StTBY` shares held by the contract | Valid States | ✅ |
| WST-04 - WST-10 | Unit tests to check consistency of functions | Unit test | ✅ |

## Rewards

| Property | Description | Category | Tested |
| --- | --- | --- | --- |
| RW-01 | Rewards are minted and staked directly to the receiver's account | High Level | ✅ |
| RW-02 | Mint rewards are proportional to `stTBY` amount | High Level | ✅ |
| RW-03 | After calling `distributePokeRewards` or `distributeMintRewards`, the only account that can see its stakeup balance increase is the stakeup staking contract | State Transitions | ✅ |
| RW-04 | After calling `seedGauges`, the only accounts that can see their stakeup balance increase are the curve gauges | State Transitions | ✅ |
| RW-05 | Rewards are only distributed after initialization | State Transitions | ✅ |
| RW-06 | Only the `StTBY` contract can distribute rewards | State Transitions | ✅ |
| RW-07 | Gauge seeding does not exceed max rewards and rewards remaining | State Transitions | ✅ |
| RW-08 | Poke rewards decrease monotonically until depletion | Variable Transitions | ✅ |
| RW-09 | Gauge seeding occurs at correct intervals | High Level | ✅ |
| RW-10 | The only way `_pokeRewardsRemaining` can increase is by calling initialize in the `RewardManager` | Variable Transitions | ✅ |
| RW-11 | After calling `seedGauges`, `distributePokeRewards` or `distributeMintRewards` no account can see their stakeup balance decrease | Valid State | ✅ |
| RW-12 | `_calculateDripAmount` must return a value <= rewards remaining | Valid State | ✅ |
| RW-13 | `_lastSeedTimestamp` and `_poolDeploymentTimestamp` are always <= `block.timestamp` | Valid State | ✅ |
| RW-14 | Total distributed rewards do not exceed `SUP_MAX_SUPPLY` | Valid State | ✅ |
| RW-15 | `_pokeRewardsRemaining` always less or equal `POKE_REWARDS` | Valid State | ✅ |
| RW-16 | `_startTimestamp` set in constructor once | Valid State | ✅ |

## Staking

| Property | Description | Category | Tested |
| --- | --- | --- | --- |
| SK-01 | Any stake or unstake action changes token balances | State Transitions | ✅ |
| SK-02 | Total staked `SUP` cannot exceed the total `SUP` supply | Valid State | ✅ |
| SK-03 | Claimable rewards are calculated based on staked amounts and global reward index | Unit test | ✅ |
| SK-04 | For all users, `userStakingData.index` is always less than or equal to `_rewardData.index` | Valid State | ✅ |
| SK-05 | `_lastRewardBlock` alway greater or equal to block number | Valid State | ✅ |
| SK-06 | For all users, `totalStakeUpStaked` changes the same way as `_stakingData[msg.sender].amountStaked` | State Transitions | ✅ |
| SK-07 | Staking balance cannot decrease unless by explicit unstake or reward claim actions | State Transitions | ✅ |
| SK-08 | For all users, `userStakingData.index` is monotonically increasing | State Transitions | ✅ |
| SK-09 | `_rewardData.index` is updated with every state modify function | State Transitions | ✅ |
| SK-10 | The last reward distribution block is updated on every reward distribution action | Variable Transitions | ✅ |
| SK-11 | `_rewardData.index` is monotonically increasing | Variable Transitions | ✅ |
| SK-12 | No uses's amount staked could be greater than total staked | Valid State | ✅ |

## Vesting

| Property | Description | Category | Tested |
| --- | --- | --- | --- |
| VT-01 | Total vested `SUP` cannot exceed the total `SUP` supply | Valid State | ✅ |
| VT-02 | Sum of `_totalStakeUpStaked` and `_totalStakeUpVesting` is always less than or equal to `IERC20(address(_stakeupToken)).balanceOf(address(VESTING_CONTRACT))` | Valid State | ✅ |
| VT-03 | Vested tokens are locked until the cliff period has passed | Valid State | ✅ |
| VT-04 | For all allocations, `startingBalance` is always greater than or equal to currentBalance | Valid State | ✅ |
| VT-05 | Vested tokens are released linearly after the cliff period until the end of the vesting duration | High-Level | ✅ |
| VT-06 | A user's vested balance decreases as they claim vested tokens | Variable Transitions | ✅ |
| VT-07 | The vesting start time is set upon the first vesting action for a user | State Transitions | ✅ |
| VT-08 | For two timestamps after `VESTING_DURATION`, the value returned by `getAvailableTokens` should not change | Variable Transitions | ✅ |
| VT-09 | Only `StakeupToken` can execute `vestTokens()` | State Transitions | ✅ |
| VT-10 | Vesting timestamp always equal or greater `block.timestamp` | Valid State | ✅ |
| VT-11 | A user's token allocations empty when `block.timestamp` not set | Valid State | ✅ |

## StakeupToken

| Property | Description | Category | Tested |
| --- | --- | --- | --- |
| SUP-01 | Supply can never surpass `MAX_SUPPLY` | Valid State | ✅ |
| SUP-02 | Ownership transfer follows the two-step process | State Transitions | ✅ |
| SUP-03 | Only reward manager or owner can mint | State Transitions | ✅ |
| SUP-04 | When minting, the increase in supply is equal to the amount allocated | State Transitions | ✅ |
| SUP-05 | Airdrops, LP and initial supply minting are owner-restricted operations | State Transitions | ✅ |
| SUP-06 | The contract initialization triggers the reward manager's initialization | State Transitions | ✅ |
| SUP-07 | Airdrop minting respects allocation boundaries | High Level | ✅ |
| SUP-08 | Vesting contracts are correctly called during `mintAndVest` operations | State Transitions | ✅ |

## RedemptionNFT

| Property | Description | Category | Tested |
| --- | --- | --- | --- |
| NFT-01 | `_mintCount` is monotonically increasing | Valid State | ✅ |
| NFT-02 | The owner of the NFT must match the owner in the withdrawal request | Valid State | ✅ |
| NFT-03 | Each newly minted NFT must have a unique token ID | Valid State | ✅ |
| NFT-04 | After burn NFT, withdrawal request gets empty | State Transitions | ✅ |
| NFT-05 | After a `LayerZero` receive NFT supply is incremented by length of tokenIds array | State Transitions | ✅ |
| NFT-06 | Withdrawal requests can only be claimed once | High Level | ✅ |
| NFT-07 | On claim withdrawal shares must be withdrawn from the stTBY contract to the NFT owner's address | State Transitions | ✅ |
| NFT-08 | Only the `StTBY` contract or `LzApp` can initiate the minting of a `RedemptionNFT` | State Transitions | ✅ |
| NFT-09 | NFTs associated with unclaimed withdrawal requests could be transferred | State Transitions | ✅ |
| NFT-10 | Only the request owner can transfer the corresponding NFT | State Transitions | ✅ |