# Staked USD (stUSD)

## Overview
stUSD is an omnichain stablecoin that is backed by low risk, high yield tokenized assets called TBYs. TBYs, a product of Bloom Protocol, are a corporate debts token denominated in USDC and are over-collateralized with Backed Finances ib01 tokenized bond. These TBYs are sturctured as a non-security Corporate Debt offering that give users a similar exposure to low risk treasuries while still living up to the permissionless, censorship resistant, and decentralized ethos of DeFi by not requiring KYC. 

TBYs are limited by the fact that users are subject to the 6-month fixed term lockup of the asset as well as the fact that new TBYs are minted every two weeks as a different ERC-20, thus making it difficult to efficiently integrate into DeFi protocols. 

## How stUSD Solves This Problem
stUSD solves TBYs composability and liquidity issues by allowing users to stake their TBYs or USDC into the contract and receive stUSD in return. stUSD can be thought of as an index of all the active TBYs in the market. As new Bloom Pool mint occur every two weeks, the stUSD contract will automatically redeposit all underlying funds into the new TBYs, allowing users to continue to earn yield on their stUSD without having to manually manage their funds. This token follows a rebasing mechanism that distributes yield to stUSD holders while maintaining a peg to the US Dollar.

## Design
![stUSD Design](./stUsd-architecture.png)
### Tokens
- **stUSD**: The stUSD token is the main token of the protocol. It is a rebasing token that is pegged to the US Dollar. It is minted when users deposit TBYs or USDC into the contract and is burned when users withdraw their USDC from the contract. This token rebases using a hybrid system. Basic maintance rebases occur every transaction, while yield rebases occur every 24 hours, via cross-referencing Bloom's `ExchangeRateRegistry` contract.

- **wstUsD**: Wrapped stUSD is the wrapped asset of `stUSD`. It is non-rebasing which allows users to access the underlying value of their stUSD without having to worry about tax implications of rebasing tokens.

- **StakupToken**: Stakeup Token or SUP, is the reward token of the Stakeup Protocol. It is minted to various users of stUSD, including contributors, investors, minters of stUSD, and DeFi users who provide liquidity to stUSD pools on Curve. 

- **SUPVesting**: SUPVesting is a vesting contract that locks up SUP tokens for a period of time. Its main purpose is to manage the distribution of SUP tokens to contributors and investors of the Stakeup Protocol and stUSD. These tokens are considered staked on the Stakeup Protocol and allow users to generate rewards even while locked under vesting schedules.

- **RedemptionNFT**: RedemptionNFT is a semi-fungible token that is minted to users when they redeem their stUSD in preperation to withdraw their USDC from the contract. This system is similar to Lido's stETH withdraw system but without the need for a queue, or off-chain oracles.

### Staking
- **StakeupStaking**: Stakeup Staking is the heart of the reward system for stUSD. It allows users to stake their SUP to access the reward system of the protocol. `stUSD` from fees are sent to the contract and is used to generate yield for the users of the protocol. Below is the outline of the fee mechonism of stUSD.

    - Mint Fees: .05%
    - Redeem Fees: .05%
    - Performance Fees: 10% of TBY yield

### Rewards
- **RewardManager**: The `RewardManager` acts as the reward distrobution system for the Stakeup Protocol. It is responsible for distributing SUP to users who execute the `poke` function on `stUSD` to manage state, as well as sending weekly emissions to Curve gauges for liquidity provider rewards. Below is an outline of the liquidity pools eligable for rewards.

   - stUSD/3CRV
   - wstUSD/wstETH
   - wstUSD/CHAI
   - stUSD/SUP