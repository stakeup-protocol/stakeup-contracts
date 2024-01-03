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
def test_rewards_persist_properly_between_harvests():
    alice = default_chain.accounts[0]
    bob = default_chain.accounts[1]

    deploy_env(default_chain)
    mint_fee = 0.0001 # 0.01%
    bps_scale = 10000
    mint_fee_scaled = int(mint_fee * bps_scale)

    rewardSupply = EvmMath.parse_eth(20)
    aliceStake = EvmMath.parse_eth(1000)
    bobStake = EvmMath.parse_eth(1000)

    ## TODO - convert rest of forge test to wake
