from eth_typing import Address
from wake.testing import *
from pytypes.src.token.StUSD import StUSD
from pytypes.tests.mocks.MockERC20 import MockERC20
from pytypes.tests.mocks.MockStakeupStaking import MockStakeupStaking
from pytypes.tests.mocks.MockSwapFacility import MockSwapFacility
from pytypes.tests.mocks.MockRewardManager import MockRewardManager
from pytypes.tests.mocks.MockBloomPool import MockBloomPool
from pytypes.tests.mocks.MockEmergencyHandler import MockEmergencyHandler
from pytypes.tests.mocks.MockBloomFactory import MockBloomFactory
from pytypes.tests.mocks.MockRegistry import MockRegistry
from pytypes.src.token.WstUSD import WstUSD

from pytypes.lib.openzeppelincontracts.contracts.token.ERC20 import ERC20
from pytypes.src.staking.StakeupStaking import StakeupStaking

class ContractConfig:
    def __init__(self, is_mock=False, address=None):
        self.is_mock = is_mock
        self.address = address

class StUSDTestEnv:
    def __init__(
        self,
        c: Chain, 
        t1: ContractConfig,
        t2: ContractConfig,
        t3: ContractConfig,
        stakeup: ContractConfig
    ):
        self.stablecoin = self.__setup_token(t1, 6)
        self.bill_token = self.__setup_token(t2, 18)
        self.sup_token = self.__setup_token(t3, 18)

        self.deployer = c.accounts[0]

        self.swap_facility = MockSwapFacility.deploy(self.stablecoin, self.bill_token)
        self.rewards_manager = MockRewardManager.deploy()
        self.bloom_pool = MockBloomPool.deploy(self.stablecoin, self.bill_token, self.swap_facility, 6)
        self.emergency_handler = MockEmergencyHandler.deploy()
        self.factory = self.__setup_bloom_factory(self.bloom_pool)
        self.registry = MockRegistry.deploy(self.bloom_pool.address)

        self.stakeup = self.__setup_stakeup(stakeup)
        self.st_usd = self.__setup_st_usd()
        self.wst_usd = WstUSD.deploy(self.st_usd.address)

        self.__init_rewards_manager(self.stakeup, self.sup_token)

    def __setup_token(self, config: ContractConfig, d=18):
        if config.is_mock:
            return MockERC20.deploy(d)
        elif config.address is None:
            Error("Address must be provided for non-mock token")
        else:
            return ERC20(config.address)
        
    def __setup_bloom_factory(self, bloom_pool):
        factory = MockBloomFactory.deploy()
        factory.setLastCreatedPool(bloom_pool.address)
        return factory

    def __setup_stakeup(self, config: ContractConfig):
        if config.is_mock:
            stakeup = MockStakeupStaking.deploy()
            stakeup.setRewardManager(self.rewards_manager.address)
            return stakeup
        elif config.address == None:
            return StakeupStaking.deploy() 
        else:
            stakeup = StakeupStaking(config.address)
    
    def __setup_st_usd(self):
        wrapper_address = get_create_address(self.deployer, self.deployer.nonce + 1)
        return StUSD.deploy(
            self.stablecoin.address,
            self.stakeup.address,
            self.factory.address,
            self.registry.address,
            1, # .01%
            50, # .5%
            1000, # 10%
            Address.ZERO,
            wrapper_address
        )
    
    def __init_rewards_manager(self, stakeup, sup_token):
        self.rewards_manager.setStakeupStaking(stakeup.address)
        self.rewards_manager.setStakeupToken(sup_token.address)

def deploy_st_usd_env(c) -> StUSDTestEnv:
    env = StUSDTestEnv(
        c,
        ContractConfig(True),
        ContractConfig(True),
        ContractConfig(True),
        ContractConfig(True)
    )
    return env