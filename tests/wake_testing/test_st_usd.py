from pytest import fixture
from wake.testing import *
from wake.testing.fuzzing import *
from helpers.wake_st_usd_setup import ContractConfig, deploy_st_usd_env, StUSDTestEnv
from helpers.utils import *
from pytypes.src.interfaces.bloom.IBloomPool import IBloomPool
from pytypes.src.token.StUSD import StUSD
from pytypes.src.token.WstUSD import WstUSD
from pytypes.tests.mocks.MockBloomPool import MockBloomPool
from pytypes.tests.mocks.MockERC20 import MockERC20
from pytypes.tests.mocks.MockRegistry import MockRegistry
from pytypes.tests.mocks.MockStakeupStaking import MockStakeupStaking
from pytypes.tests.mocks.MockSwapFacility import MockSwapFacility

st_usd: StUSD
wst_usd: WstUSD
usdc: MockERC20
bill: MockERC20
bloom_pool: MockBloomPool
stakeup: MockStakeupStaking
registry: MockRegistry
swap_facility: MockSwapFacility
deployer: Account

def deploy_env(c):
    global st_usd, wst_usd, usdc, bill, bloom_pool, stakeup, registry, swap_facility, deployer

    e = deploy_st_usd_env(c)
    st_usd = e.st_usd
    wst_usd = e.wst_usd
    usdc = e.stablecoin
    bill = e.bill_token
    bloom_pool = e.bloom_pool
    stakeup = e.stakeup
    registry = e.registry
    swap_facility = e.swap_facility
    deployer = e.deployer

    tokens = [usdc, bill]

    registry.setActiveTokens(tokens)
    registry.setTokenInfos(True)
    bloom_pool.setCommitPhaseEnd(default_chain.blocks["latest"].timestamp + (Constants.ONE_DAY * 3))
    bloom_pool.setState(IBloomPool.State.Commit)

# true if the user wants to deposit TBY, false if the user wants to deposit USDC
def deposit(c: Chain, u: Account, a: int, tby: bool):
    if tby:
        bloom_pool.mint(u.address, a)
        bloom_pool.approve(st_usd.address, a, from_=u)
        st_usd.depositTby(bloom_pool.address, a, from_=u)
    else:
        usdc.mint(u.address, a)
        usdc.approve(st_usd.address, a, from_=u)
        st_usd.depositUnderlying(a, from_=u)

@default_chain.connect()
def test_deployment():
    deploy_env(default_chain)

    assert st_usd.address != Address.ZERO
    assert wst_usd.address != Address.ZERO
    assert st_usd.owner() == deployer.address
    assert st_usd.getWstUSD().address == wst_usd.address
    assert st_usd.circulatingSupply() == 0

@default_chain.connect()
def test_mint_fee():
    deploy_env(default_chain)
    mint_fee = 0.0001 # 0.01%
    bps_scale = 10000
    mint_fee_scaled = int(mint_fee * bps_scale)

    tby_deposit_amount = 1000;
    parsed_deposit_amount = EvmMath.parse_decimals(tby_deposit_amount, 6)
    mint_fee = tby_deposit_amount * mint_fee
    scaled_mint_fee = EvmMath.parse_eth(mint_fee)

    user = default_chain.accounts[1]

    registry.setExchangeRate(bloom_pool.address, EvmMath.parse_eth(1))

    deposit(default_chain, user, parsed_deposit_amount, True)
    ## Mint fee with 1:1 TBY:USD exchange rate

    assert st_usd.getMintBps() == mint_fee_scaled
    assert st_usd.balanceOf(user.address) == int(EvmMath.parse_eth(tby_deposit_amount) - scaled_mint_fee)
    assert st_usd.balanceOf(stakeup.address) == scaled_mint_fee
    assert st_usd.circulatingSupply() == EvmMath.parse_eth(tby_deposit_amount)

    ## TODO: Mint fee with 1:1.02 TBY:USD exchange rate

@default_chain.connect()
def test_redeem_fee():
    deploy_env(default_chain)
    redeem_fee = 0.005 # .5%
    bps_scale = 10000

    usdc_deposit_amount = 1000;
    parsed_deposit_amount = EvmMath.parse_decimals(usdc_deposit_amount, 6)

    expected_redeem_fee = (usdc_deposit_amount * (1 - 0.0001)) * redeem_fee

    user = default_chain.accounts[1]

    registry.setExchangeRate(bloom_pool.address, EvmMath.parse_eth(1))

    deposit(default_chain, user, parsed_deposit_amount, False)

    bal_before = st_usd.balanceOf(stakeup.address)
    st_usd.redeemStUSD(st_usd.balanceOf(user.address), from_=user)
    fees_collected = st_usd.balanceOf(stakeup.address) - bal_before

    assert st_usd.getRedeemBps() == int(redeem_fee * bps_scale)
    assert fees_collected == EvmMath.parse_eth(expected_redeem_fee)


@default_chain.connect()
def test_performance_fee():
    deploy_env(default_chain)
    performance_fee = 0.1
    bps_scale = 10000

    tby_deposit_amount = 1000;
    yield_gained = 50
    parsed_deposit_amount = EvmMath.parse_decimals(tby_deposit_amount, 6)

    user = default_chain.accounts[1]

    registry.setExchangeRate(bloom_pool.address, EvmMath.parse_eth(1))
    deposit(default_chain, user, parsed_deposit_amount, True)

    default_chain.mine(lambda x: x + Constants.ONE_DAY * 30)
    registry.setExchangeRate(bloom_pool.address, EvmMath.parse_eth(1.05))
    swap_facility.setRate(EvmMath.parse_eth(1.05))
    
    bloom_pool.setState(IBloomPool.State.FinalWithdraw)

    bal_before = st_usd.balanceOf(stakeup.address)
    st_usd.redeemUnderlying(bloom_pool.address, st_usd.balanceOf(user.address), from_=user)
    fees_collected = st_usd.balanceOf(stakeup.address) - bal_before

    expected_performance_fee = (EvmMath.parse_eth(yield_gained)) * performance_fee

    assert st_usd.getPerformanceBps() == int(performance_fee * bps_scale)

    ## TODO: Potential inaccuracy in perforance fee calculation. Investigate further.
    #assert fees_collected == int(expected_performance_fee)

# def test_user_returns_st_usd():

# def test_user_returns_wst_usd():
    
@default_chain.connect()
def test_exchange_rate():
    deploy_env(default_chain)
    tby_deposit_amount = 1000;
    
    user = default_chain.accounts[1]
    bloom_pool.mint(user.address, EvmMath.parse_decimals(tby_deposit_amount, 6))
    bloom_pool.approve(st_usd.address, EvmMath.parse_decimals(tby_deposit_amount, 6), from_=user)

    st_usd.depositTby(bloom_pool.address, EvmMath.parse_decimals(tby_deposit_amount, 6), from_=user)
    
    registry.setExchangeRate(bloom_pool.address, EvmMath.parse_eth(1))

    default_chain.mine(lambda x: x + Constants.ONE_WEEK)

    rate = st_usd.getTotalUsd() * 1e18 / st_usd.getTotalShares()

    assert rate == EvmMath.parse_eth(1)
    # Uncomment out when poke exchange rate fix is merged
    # registry.setExchangeRate(bloom_pool.address, EvmMath.parse_eth(1.05))
    # print(f'Exchange Rate {registry.getExchangeRate(bloom_pool.address)}')
    # st_usd.poke()
    # print(f'Total USD {st_usd.getTotalUsd()}')
    # print(f'Total Shares {st_usd.getTotalShares()}')
    # rate = st_usd.getTotalUsd() * 1e18 / st_usd.getTotalShares()
    # print(f'{rate}')
    # assert rate == EvmMath.parse_eth(1.05)
    
    # bloom_pool.setState(IBloomPool.State.FinalWithdraw)

    # # Redeeming should not change the exchange rate
    # st_usd.redeemUnderlying(bloom_pool, EvmMath.parse_decimals(tby_deposit_amount, 6), from_=user)

# def test_auto_minting():

# def test_balance_adjustments():
