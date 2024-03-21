import os
import math
from pytest import approx
from eth_typing import Address
from dotenv import load_dotenv

from wake.testing import *
from wake.testing.fuzzing import *
from tests.wake_testing.helpers.utils import Constants, EvmMath

from pytypes.src.interfaces.curve.ICurvePoolFactory import ICurvePoolFactory
from pytypes.src.interfaces.ICurveGaugeDistributor import ICurveGaugeDistributor
from pytypes.src.interfaces.curve.ICurvePoolGauge import ICurvePoolGauge
from pytypes.src.rewards.RewardManager import RewardManager
from pytypes.src.token.StakeupToken import StakeupToken

from pytypes.tests.mocks.MockDripRewarder import MockDripRewarder
from pytypes.tests.mocks.MockERC20 import MockERC20
from pytypes.tests.mocks.MockStakeupStaking import MockStakeupStaking

load_dotenv()

ALCHEMY_API_KEY = os.getenv("ALCHEMY_API_KEY")

def deploy_dripRewarder():
    dripRewarder = MockDripRewarder.deploy(
        MockERC20.deploy(6).address,
        MockERC20.deploy(18).address,
        random_address()
    )
    return dripRewarder

def revert_handler(e: TransactionRevertedError):
    if e.tx is not None:
        print(e.tx.call_trace)

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

@default_chain.connect(
    accounts=20,
    chain_id=1,
    fork=f'https://eth-mainnet.g.alchemy.com/v2/{ALCHEMY_API_KEY}@18830568'
)
@on_revert(revert_handler)
def test_consistent_gauge_rewards():
    total_rewards = 200000000
    assert default_chain.connected is True
    
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
        stakeup.address,
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

    expected_reward_per_epoch = EvmMath.parse_eth(total_rewards / 2 / 52) # 50% of total rewards over 52 weeks
    default_chain.change_automine(False)

    prev_balance = sup_token.balanceOf(ICurvePoolGauge(gauge))
    weeks_in_6_years = 52 * 6

    year_num = 1
    for (i, epoch) in enumerate(range(0, weeks_in_6_years)):
        rewardManager.seedGauges(from_=account, request_type="tx")
        default_chain.mine(lambda x: x + Constants.ONE_WEEK - 1)
        
        if (((i + 1) / 52) > year_num):
            year_num += 1
            if year_num != 6:
                expected_reward_per_epoch = expected_reward_per_epoch / 2

        sup_balance = sup_token.balanceOf(ICurvePoolGauge(gauge))
        reward = sup_balance - prev_balance
        assert reward == approx(expected_reward_per_epoch, rel=1e-16)
        prev_balance = sup_balance

    assert ICurvePoolGauge(gauge).reward_tokens(0) == sup_token.address
    assert sup_token.balanceOf(ICurvePoolGauge(gauge)) == EvmMath.parse_eth(total_rewards)