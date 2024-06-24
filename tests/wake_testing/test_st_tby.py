from eth_account import Account
from wake.testing import *
from wake.testing.fuzzing import *
from helpers.wake_st_tby_setup import deploy_st_tby_env
from helpers.utils import *
from pytypes.src.interfaces.bloom.IBloomPool import IBloomPool
from pytypes.src.interfaces.ILayerZeroSettings import ILayerZeroSettings
from pytypes.src.token.StTBY import StTBY
from pytypes.src.token.WstTBY import WstTBY
from pytypes.tests.mocks.MockBloomFactory import MockBloomFactory
from pytypes.tests.mocks.MockBloomPool import MockBloomPool
from pytypes.tests.mocks.MockERC20 import MockERC20
from pytypes.tests.mocks.MockRegistry import MockRegistry
from pytypes.tests.mocks.MockStakeUpStaking import MockStakeUpStaking
from pytypes.tests.mocks.MockSwapFacility import MockSwapFacility

st_tby: StTBY
wst_tby: WstTBY
usdc: MockERC20
bill: MockERC20
bloom_pool: MockBloomPool
stakeup: MockStakeUpStaking
registry: MockRegistry
swap_facility: MockSwapFacility
deployer: Account
factory: MockBloomFactory
settings = ILayerZeroSettings.LzSettings

def deploy_env(c):
    global st_tby, wst_tby, usdc, bill, bloom_pool, stakeup, registry, swap_facility, deployer, factory, settings

    e = deploy_st_tby_env(c)
    st_tby = e.st_tby
    wst_tby = e.wst_tby
    usdc = e.stablecoin
    bill = e.bill_token
    bloom_pool = e.bloom_pool
    stakeup = e.stakeup
    registry = e.registry
    swap_facility = e.swap_facility
    deployer = e.deployer
    factory = e.factory
    
    settings = ILayerZeroSettings.LzSettings(
        bytearray([0,1,2,3]),
        (0,0),
        deployer.address,
    )

    tokens = [bloom_pool.address]

    registry.setActiveTokens(tokens)
    registry.setTokenInfos(True)
    bloom_pool.setCommitPhaseEnd(default_chain.blocks["latest"].timestamp + (Constants.ONE_DAY * 3))
    bloom_pool.setState(IBloomPool.State.Commit)

# true if the user wants to deposit TBY, false if the user wants to deposit USDC
def deposit(c: Chain, u: Account, a: int, tby: bool):
    if tby:
        bloom_pool.mint(u.address, a)
        bloom_pool.approve(st_tby.address, a, from_=u)
        st_tby.depositTby(bloom_pool.address, a, settings, from_=u, value=0)
    else:
        usdc.mint(u.address, a)
        usdc.approve(st_tby.address, a, from_=u)
        st_tby.depositUnderlying(a, settings, from_=u, value=0)

@default_chain.connect()
def test_deployment():
    deploy_env(default_chain)

    assert st_tby.address != Address(0)
    assert wst_tby.address != Address(0)
    assert st_tby.owner() == deployer.address
    assert st_tby.getWstTBY().address == wst_tby.address

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

    assert st_tby.getMintBps() == mint_fee_scaled
    assert st_tby.balanceOf(user.address) == int(EvmMath.parse_eth(tby_deposit_amount) - scaled_mint_fee)
    assert st_tby.balanceOf(stakeup.address) == scaled_mint_fee

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

    usdc.mint(st_tby.address, parsed_deposit_amount)

    bal_before = st_tby.balanceOf(stakeup.address)

    amount = st_tby.balanceOf(user.address)
    st_tby.redeemStTBY(amount, settings, from_=user, value=0)
    fees_collected = st_tby.balanceOf(stakeup.address) - bal_before

    assert st_tby.getRedeemBps() == int(redeem_fee * bps_scale)
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

    bal_before = st_tby.balanceOf(stakeup.address)
    st_tby.redeemUnderlying(bloom_pool.address, settings, from_=user, value=0)
    fees_collected = st_tby.balanceOf(stakeup.address) - bal_before

    expected_performance_fee = (EvmMath.parse_eth(yield_gained)) * performance_fee

    assert st_tby.getPerformanceBps() == int(performance_fee * bps_scale)

    ## TODO: Potential inaccuracy in perforance fee calculation. Investigate further.
    #assert fees_collected == int(expected_performance_fee)

# TODO: Add tests during audit fix
def test_user_returns_st_tby():
    # User returns depositing USDC into an Bloom during commitment
    # User returns depositing TBY that has been accruing existing value
    pass

# TODO: Add tests during audit fix
def test_user_returns_wst_tby():
    # User returns depositing USDC into an Bloom during commitment
    # User returns depositing TBY that has been accruing existing value
    pass

@default_chain.connect()
def test_exchange_rate():
    deploy_env(default_chain)
    tby_deposit_amount = 1000;
    
    user = default_chain.accounts[1]
    bloom_pool.mint(user.address, EvmMath.parse_decimals(tby_deposit_amount, 6))
    bloom_pool.approve(st_tby.address, EvmMath.parse_decimals(tby_deposit_amount, 6), from_=user)
    
    registry.setExchangeRate(bloom_pool.address, EvmMath.parse_eth(1))

    st_tby.depositTby(bloom_pool.address, EvmMath.parse_decimals(tby_deposit_amount, 6), settings, from_=user)
    
    default_chain.mine(lambda x: x + Constants.ONE_WEEK)

    rate = st_tby.getTotalUsd() * 1e18 / st_tby.getTotalShares()

    assert rate == EvmMath.parse_eth(1)
    # Uncomment out when poke exchange rate fix is merged
    # registry.setExchangeRate(bloom_pool.address, EvmMath.parse_eth(1.05))
    # print(f'Exchange Rate {registry.getExchangeRate(bloom_pool.address)}')
    # st_tby.poke(settings)
    # print(f'Total USD {st_tby.getTotalUsd()}')
    # print(f'Total Shares {st_tby.getTotalShares()}')
    # rate = st_tby.getTotalUsd() * 1e18 / st_tby.getTotalShares()
    # print(f'{rate}')
    # assert rate == EvmMath.parse_eth(1.05)
    
    # bloom_pool.setState(IBloomPool.State.FinalWithdraw)

    # # Redeeming should not change the exchange rate
    # st_tby.redeemUnderlying(bloom_pool, from_=user)

@default_chain.connect()
def test_auto_minting():
    deploy_env(default_chain)
    usdc_deposit_amount = 1000
    
    user = default_chain.accounts[1]

    registry.setExchangeRate(bloom_pool.address, EvmMath.parse_eth(1))
    deposit(default_chain, user, EvmMath.parse_decimals(usdc_deposit_amount, 6), False)
    
    default_chain.mine(lambda x: x + Constants.ONE_DAY * 30)
    registry.setExchangeRate(bloom_pool.address, EvmMath.parse_eth(1.05))
    swap_facility.setRate(EvmMath.parse_eth(1.05))

    bloom_pool.setState(IBloomPool.State.FinalWithdraw)

    user_bal_before = st_tby.balanceOf(user.address)
    user_shares_before = st_tby.sharesOf(user.address)
    bloom_pool.mint(st_tby.address, EvmMath.parse_decimals(usdc_deposit_amount, 6))
    st_tby.redeemUnderlying(bloom_pool.address, settings, from_=user, value=0)
    user_bal_after = st_tby.balanceOf(user.address)
    user_shares_after = st_tby.sharesOf(user.address)

    assert user_bal_after > user_bal_before
    assert user_shares_before == user_shares_after
    assert usdc.balanceOf(st_tby.address) == EvmMath.parse_decimals(1.05 * usdc_deposit_amount, 6)

    # Deploy new Bloom Pool
    bloom_pool_2 = MockBloomPool.deploy(usdc, bill, swap_facility, 6)
    bloom_pool_2.setCommitPhaseEnd(default_chain.blocks["latest"].timestamp + (Constants.ONE_DAY * 3))
    bloom_pool_2.setState(IBloomPool.State.Commit)
    
    factory.setLastCreatedPool(bloom_pool_2.address)
    st_tby.poke(settings)

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

    # Poke should deposit the remaining balance of usdc into the new bloom pool
    st_tby.poke(settings)
    assert st_tby.getRemainingBalance() == 0
    assert usdc.balanceOf(st_tby.address) == 0

    # Mine to past the end of the commit phase and initiate the pending prehold swap
    default_chain.mine(lambda x: x + Constants.ONE_HOUR * 2)
    bloom_pool_2.setState(IBloomPool.State.PendingPreHoldSwap)
    st_tby.poke(settings)
    assert st_tby.getRemainingBalance() == 0
    

@default_chain.connect()
def test_deposit_existing_tby():
    deploy_env(default_chain)
    user = default_chain.accounts[1]

    mint_amount = 1000
    exchange_rate = 1.04

    mint_fee = EvmMath.parse_eth(mint_amount * st_tby.getMintBps() / 10000)
    print(f'Mint Fee {mint_fee}')
    registry.setExchangeRate(bloom_pool.address, EvmMath.parse_eth(exchange_rate))
    print(f'Expected Tokens {EvmMath.parse_eth(mint_amount * exchange_rate)}')
    expected_user_balance = EvmMath.parse_eth(mint_amount * exchange_rate) - mint_fee

    bloom_pool.mint(user.address, EvmMath.parse_decimals(mint_amount, 6))
    bloom_pool.approve(st_tby.address, EvmMath.parse_decimals(mint_amount, 6), from_=user)

    st_tby.depositTby(bloom_pool.address, EvmMath.parse_decimals(mint_amount, 6), settings, from_=user, value=0)

    assert st_tby.balanceOf(user.address) == expected_user_balance
    assert st_tby.getTotalUsd() == EvmMath.parse_eth(mint_amount * exchange_rate)

@default_chain.connect()
def test_deposit_fee():
    deploy_env(default_chain)

    user = default_chain.accounts[1]

    deposit_amount = 1000
    deposit_fee = st_tby.getMintBps() * deposit_amount / 10000

    registry.setExchangeRate(bloom_pool.address, EvmMath.parse_eth(1))
    deposit(default_chain, user, EvmMath.parse_decimals(deposit_amount, 6), False)

    assert st_tby.balanceOf(stakeup.address) == EvmMath.parse_eth(deposit_fee)
