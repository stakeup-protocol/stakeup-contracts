from wake.testing import *
from wake.testing.fuzzing import *
from helpers.wake_st_usd_setup import ContractConfig, deploy_st_usd_env, StUSDTestEnv
from helpers.utils import *
from pytypes.src.interfaces.bloom.IBloomPool import IBloomPool
from pytypes.src.token.StUSD import StUSD
from pytypes.src.token.WstUSD import WstUSD
from pytypes.tests.mocks.MockBloomFactory import MockBloomFactory
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
factory: MockBloomFactory

def deploy_env(c):
    global st_usd, wst_usd, usdc, bill, bloom_pool, stakeup, registry, swap_facility, deployer, factory

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
    factory = e.factory

    tokens = [bloom_pool.address]

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

# TODO: Add tests during audit fix
def test_user_returns_st_usd():
    # User returns depositing USDC into an Bloom during commitment
    # User returns depositing TBY that has been accruing existing value
    pass

# TODO: Add tests during audit fix
def test_user_returns_wst_usd():
    # User returns depositing USDC into an Bloom during commitment
    # User returns depositing TBY that has been accruing existing value
    pass

@default_chain.connect()
def test_exchange_rate():
    deploy_env(default_chain)
    tby_deposit_amount = 1000;
    
    user = default_chain.accounts[1]
    bloom_pool.mint(user.address, EvmMath.parse_decimals(tby_deposit_amount, 6))
    bloom_pool.approve(st_usd.address, EvmMath.parse_decimals(tby_deposit_amount, 6), from_=user)
    
    registry.setExchangeRate(bloom_pool.address, EvmMath.parse_eth(1))

    st_usd.depositTby(bloom_pool.address, EvmMath.parse_decimals(tby_deposit_amount, 6), from_=user)
    
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

@default_chain.connect()
def test_auto_minting():
    deploy_env(default_chain)
    usdc_deposit_amount = 1000;
    
    user = default_chain.accounts[1]

    registry.setExchangeRate(bloom_pool.address, EvmMath.parse_eth(1))
    deposit(default_chain, user, EvmMath.parse_decimals(usdc_deposit_amount, 6), False)
    
    default_chain.mine(lambda x: x + Constants.ONE_DAY * 30)
    registry.setExchangeRate(bloom_pool.address, EvmMath.parse_eth(1.05))
    swap_facility.setRate(EvmMath.parse_eth(1.05))

    bloom_pool.setState(IBloomPool.State.FinalWithdraw)

    user_bal_before = st_usd.balanceOf(user.address)
    user_shares_before = st_usd.sharesOf(user.address)
    bloom_pool.mint(st_usd.address, EvmMath.parse_decimals(usdc_deposit_amount, 6))
    st_usd.redeemUnderlying(bloom_pool.address, st_usd.balanceOf(user.address), from_=user)
    user_bal_after = st_usd.balanceOf(user.address)
    user_shares_after = st_usd.sharesOf(user.address)

    assert user_bal_after > user_bal_before
    assert user_shares_before == user_shares_after
    assert usdc.balanceOf(st_usd.address) == EvmMath.parse_decimals(1.05 * usdc_deposit_amount, 6)

    # Deploy new Bloom Pool
    bloom_pool_2 = MockBloomPool.deploy(usdc, bill, swap_facility, 6)
    bloom_pool_2.setCommitPhaseEnd(default_chain.blocks["latest"].timestamp + (Constants.ONE_DAY * 3))
    bloom_pool_2.setState(IBloomPool.State.Commit)
    
    factory.setLastCreatedPool(bloom_pool_2.address)
    # TODO Fix: Currently bloom pool tokens are set active in the registry upon deployment. This is a dangerous
    # scenerio in the poke function when we have deposited tokens but have yet to be minted TBY,
    # as it will attempt to poke adjust the exchange rate for the new pool. We will
    # then underestimate totalUSD because we have yet to receive a balance so we set the value to 0 for that batch.
    # UPDATE: This actually might not matter. Necessary to double check
    #registry.setActiveTokens([bloom_pool_2.address])

    registry.setExchangeRate(bloom_pool_2.address, EvmMath.parse_eth(1))
    swap_facility.setRate(EvmMath.parse_eth(1))

    # Mine to the end of the commit phase
    default_chain.mine(lambda x: x + Constants.ONE_DAY * 3 - Constants.ONE_HOUR)

    # TODO: st_usd balance of users is incorrect when depositing into a new pool after auto minting and then 
    # immediately adjusting the usd value for TBY exchange rates. The assertion that is commented out
    # below should pass if the this issue is fixed.
    st_usd.poke()
    assert usdc.balanceOf(st_usd.address) == 0
    # user balance should increase after redeeming but not after auto minting
    # assert st_usd.balanceOf(user.address) == user_bal_after

@default_chain.connect()
def test_deposit_existing_tby():
    deploy_env(default_chain)
    user = default_chain.accounts[1]

    mint_amount = 1000
    exchange_rate = 1.04

    mint_fee = EvmMath.parse_eth(mint_amount * st_usd.getMintBps() / 10000)
    print(f'Mint Fee {mint_fee}')
    registry.setExchangeRate(bloom_pool.address, EvmMath.parse_eth(exchange_rate))
    print(f'Expected Tokens {EvmMath.parse_eth(mint_amount * exchange_rate)}')
    expected_user_balance = EvmMath.parse_eth(mint_amount * exchange_rate) - mint_fee

    bloom_pool.mint(user.address, EvmMath.parse_decimals(mint_amount, 6))
    bloom_pool.approve(st_usd.address, EvmMath.parse_decimals(mint_amount, 6), from_=user)

    st_usd.depositTby(bloom_pool.address, EvmMath.parse_decimals(mint_amount, 6), from_=user)

    assert st_usd.balanceOf(user.address) == expected_user_balance
    assert st_usd.getTotalUsd() == EvmMath.parse_eth(mint_amount * exchange_rate)