import os

from eth_typing import Address
from dotenv import load_dotenv
from dataclasses import dataclass
from pytypes.src.interfaces.curve.ICurvePoolFactory import ICurvePoolFactory
from pytypes.src.interfaces.ICurveGaugeDistributor import ICurveGaugeDistributor
from pytypes.src.interfaces.curve.ICurvePoolGauge import ICurvePoolGauge
from pytypes.tests.mocks.MockRewardManager import MockRewardManager
from pytypes.tests.mocks.MockSUPVesting import MockSUPVesting
from tests.wake_testing.helpers.utils import Constants, EvmMath
from wake.testing import *
from wake.testing.fuzzing import *
from pytypes.tests.mocks.MockDripRewarder import MockDripRewarder
from pytypes.tests.mocks.MockERC20 import MockERC20
from pytypes.tests.mocks.MockStakeupStaking import MockStakeupStaking
from pytypes.src.rewards.RewardManager import RewardManager
from pytypes.src.token.StUSDBase import StUSDBase
from pytypes.src.token.StakeupToken import StakeupToken
load_dotenv()

MAINNET_FORK_URL = os.getenv("MAINNET_FORK_URL")

def deploy_dripRewarder():
    dripRewarder = MockDripRewarder.deploy(
        MockERC20.deploy(6).address,
        MockERC20.deploy(18).address,
        random_address()
    )
    return dripRewarder

@default_chain.connect()
def test_yearly_allocations():
    dripRewarder = deploy_dripRewarder()
    y1_percent = .5
    y2_percent = .25
    y3_percent = .125
    y4_percent = .0625
    y5_percent = .03125
    y6_percent = .03125

    start_time = default_chain.blocks["latest"].timestamp
    years = [y1_percent, y2_percent, y3_percent, y4_percent, y5_percent, y6_percent]

    supply = 10000
    amount_claimed = 0
    for year in years:
        default_chain.mine(lambda x: x + Constants.ONE_YEAR)

        expected_drip_amount = year * supply
        expected_amount_scaled = EvmMath.parse_eth(expected_drip_amount)

        amount_dripped = dripRewarder.calculateDripAmount(
            EvmMath.parse_eth(supply),
            start_time,
            EvmMath.parse_eth(supply) - amount_claimed,
            False
        )
        amount_claimed += amount_dripped

        assert amount_dripped == expected_amount_scaled


mainnet_fork = Chain()

def revert_handler(e: TransactionRevertedError):
    if e.tx is not None:
        print(e.tx.call_trace)

@default_chain.connect(
    accounts=20,
    chain_id=1,
    fork='https://eth-mainnet.g.alchemy.com/v2/waUcKF6YeMpPaJIlXm-auQhLUVZQxkno@18830568'
)
@on_revert(revert_handler)
def test_consistent_gauge_rewards():
    total_rewards = 200000000
    assert default_chain.connected is True
    default_chain.tx_callback = lambda tx: print(tx.console_logs)
    
    curve_factory = ICurvePoolFactory(Constants.CURVE_STABLE_POOL_FACTORY)
    
    curve_pool = curve_factory.deploy_plain_pool(
        "curve pool one",
        "cp1",
        [Constants.MAINNET_FRAX, Constants.MAINNET_USDC],
        1500,
        1000000,
        50000000000,
        800,
        0,
        [0, 0],
        [bytes(0), bytes(0)],
        [Address(0), Address(0)]
    ).return_value

    account = default_chain.accounts[0]

    vesting = MockSUPVesting.deploy(from_=account, request_type="tx", chain=default_chain)
    
    stable = MockERC20.deploy(6, from_=account, request_type="tx", chain=default_chain)

    stakeup = MockStakeupStaking.deploy(request_type="tx", chain=default_chain)
    
    curvePoolData: ICurveGaugeDistributor.CurvePoolData = ICurveGaugeDistributor.CurvePoolData(
        curve_pool,
        Address(0),
        curve_factory.address,
        EvmMath.parse_eth(total_rewards),
        EvmMath.parse_eth(total_rewards)
    )

    # Deploy Reward Manager
    rewardManager = RewardManager.deploy(
        stable.address,
        get_create_address(account, account.nonce + 1),
        stakeup.address,
        [curvePoolData],
        from_=account,
        request_type="tx",
        chain=default_chain
    )

    sup_token = StakeupToken.deploy(
        random_address(),
        vesting.address,
        rewardManager.address,
        account.address,
        from_=account,
        request_type="tx",
        chain=default_chain
    )

    gauge = rewardManager.getCurvePoolData()[0].curveGauge

    # The tx.orgin is the account that executed the original call that triggered gauge deployment
    # Due to protections on adding tokens to the gauge, the reward manager cannot add rewards to the gauge
    # unless the original gauge manager transfers the manager role to the reward manager
    ICurvePoolGauge(gauge).set_gauge_manager(rewardManager.address, from_=account, request_type="tx")

    assert rewardManager.getCurvePoolData()[0].curveGauge == gauge

    #rewardManager.seedGauges(from_=account, request_type="tx")

    expected_reward_per_epoch = total_rewards / 2 / 52 # 50% of total rewards over 52 weeks
    print("Expected Reward Per Epoch: ", EvmMath.parse_eth(expected_reward_per_epoch))
    print("Max Rewards: ", EvmMath.parse_eth(total_rewards))
    prev_reward = sup_token.balanceOf(ICurvePoolGauge(gauge))
    for (i, epoch) in enumerate(range(0, 52)):
        print(f"Epoch: {i + 1}")
        rewardManager.seedGauges(from_=account, request_type="tx")
        new_balance = sup_token.balanceOf(ICurvePoolGauge(gauge))
        default_chain.mine(lambda x: x + Constants.ONE_WEEK)
        reward = new_balance - prev_reward
        print(f'Gauge Rewards: {reward}')
        prev_reward = new_balance
        print("Total Rewards: ", sup_token.balanceOf(ICurvePoolGauge(gauge)))
        print('Reward remaining: ', rewardManager.getCurvePoolData()[0].rewardsRemaining)

    assert ICurvePoolGauge(gauge).reward_tokens(0) == sup_token.address
    print("Total Rewards: ", sup_token.balanceOf(ICurvePoolGauge(gauge)))
