# Staked USD (stUSD)

## Overview

stUSD is an omnichain stablecoin backed by the receipt tokens called TBYs. TBYs, a product of Bloom Protocol, are a corporate debt token denominated in USDC and are over-collateralized with Backed Finances ib01 tracker certificate.

TBYs are limited due to users being subject to the 6-month fixed term lockup of the asset and that new TBYs are minted every two weeks as a different ERC-20, thus making it difficult to integrate into DeFi protocols.

## How stUSD Solves This Problem

stUSD solves TBYs composability issues by allowing users to deposit their TBYs or USDC into the contract and receive stUSD in return. stUSD can be thought of as an index of active TBYs in the market. As new Bloom Pool mint occur every two weeks, the stUSD contract will automatically redeposit all underlying funds into the new TBYs, allowing users to hold stUSD without the need of actively managing their various TBY batches. This token follows a rebasing mechanism that automates TBY's to stUSD holders.

## Design

![stUSD Design](./stUsd-architecture.png)

### Tokens

- **stUSD**: The stUSD token is the main token of the protocol. It is a rebasing token that tracks the underlying TBY. It is minted when users deposit TBYs or USDC into the contract and burned when users withdraw their USDC. This token rebases using a hybrid system. Maintenance rebases occur every transaction, while yield rebases are triggered every 24-hours, via cross-referencing Bloom's `ExchangeRateRegistry` contract.

- **wstUsD**: Wrapped stUSD is the wrapped asset of `stUSD`. It is non-rebasing, allowing users to access the underlying value of their stUSD and be more useable in DeFi.

- **StakupToken**: Stakeup Token (SUP), is the reward token of the Stakeup Protocol.

- **SUPVesting**: SUPVesting is a vesting contract that locks up SUP tokens during predefined vesting schedules. Its purpose is to manage the distribution of SUP tokens to contributors and investors of the Stakeup Protocol and stUSD. These tokens are considered staked on the Stakeup Protocol and allow users to generate rewards even while locked under vesting schedules.

- **RedemptionNFT**: RedemptionNFT is a semi-fungible token minted to users when they redeem their stUSD in preparation for withdrawing their USDC from the contract. This system is similar to Lido's stETH withdrawal system but without a queue, or off-chain oracles.

### Staking

- **StakeupStaking**: Stakeup Staking is the heart of the reward system for stUSD. It allows users to stake their SUP to access the reward system of the protocol. `stUSD` from fees are sent to the contract and is used to generate yield for the users of the protocol. Below is the outline of the fee mechanism of stUSD.

  - Mint Fees: .05%
  - Redeem Fees: .05%
  - Performance Fees: 10% of TBY yield

### Rewards

- **RewardManager**: The `RewardManager` acts as the reward distribution system for the Stakeup Protocol. It is responsible for distributing SUP to users who execute the `poke` function on `stUSD` to manage state. The `CurveGaugeDistributor`, a feature of the `RewardManger` deploys CurveGauges and sends weekly emissions to the rewards gauges that are distributed to liquidity provider in the form of swap fees. Below is an outline of the liquidity pools eligible for rewards.

  - stUSD/3CRV
  - wstUSD/wstETH
  - wstUSD/CHAI
  - stUSD/SUP
