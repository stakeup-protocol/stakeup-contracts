# from eth_typing import Address
# from wake.testing import *
# from pytypes.src.token.StTBY import StTBY
# from pytypes.src.messaging.StakeUpMessenger import StakeUpMessenger
# from pytypes.tests.mocks.MockERC20 import MockERC20
# from pytypes.tests.mocks.MockSwapFacility import MockSwapFacility
# from pytypes.tests.mocks.MockBloomPool import MockBloomPool
# from pytypes.tests.mocks.MockEmergencyHandler import MockEmergencyHandler
# from pytypes.tests.mocks.MockBloomFactory import MockBloomFactory
# from pytypes.tests.mocks.MockRegistry import MockRegistry
# from pytypes.tests.mocks.MockEndpoint import MockEndpoint
# from pytypes.src.token.WstTBY import WstTBY

# from pytypes.lib.openzeppelincontracts.contracts.token.ERC20 import ERC20
# from pytypes.src.staking.StakeUpStaking import StakeUpStaking

# class ContractConfig:
#     def __init__(self, is_mock=False, address=None):
#         self.is_mock = is_mock
#         self.address = address

# class StTBYTestEnv:
#     def __init__(
#         self,
#         c: Chain, 
#         stable_token: ContractConfig,
#         bill_token: ContractConfig,
#         sup_token: ContractConfig
#     ):
#         self.stablecoin = self.__setup_token(stable_token, 6)
#         self.bill_token = self.__setup_token(bill_token, 18)
#         self.sup_token = self.__setup_token(sup_token, 18)

#         self.deployer = c.accounts[0]

#         self.swap_facility = MockSwapFacility.deploy(self.stablecoin, self.bill_token)
#         self.bloom_pool = MockBloomPool.deploy(self.stablecoin, self.bill_token, self.swap_facility, 6)
#         self.emergency_handler = MockEmergencyHandler.deploy()
#         self.factory = self.__setup_bloom_factory(self.bloom_pool)
#         self.registry = MockRegistry.deploy(self.bloom_pool.address)
#         self.endpoint = MockEndpoint.deploy()

#         self.stakeup = self.__setup_stakeup()
#         self.st_tby = self.__setup_st_tby()
#         self.wst_tby = WstTBY.deploy(self.st_tby.address)
#         self.messenger = StakeUpMessenger.deploy(self.st_tby.address, self.endpoint, self.deployer)

#     def __setup_token(self, config: ContractConfig, d=18):
#         if config.is_mock:
#             return MockERC20.deploy(d)
#         elif config.address is None:
#             Error("Address must be provided for non-mock token")
#         else:
#             return ERC20(config.address)
        
#     def __setup_bloom_factory(self, bloom_pool):
#         factory = MockBloomFactory.deploy()
#         factory.setLastCreatedPool(bloom_pool.address)
#         return factory

#     def __setup_stakeup(self):
#         st_tby_address = get_create_address(self.deployer, self.deployer.nonce + 1)
#         stakeupStaking = StakeUpStaking.deploy(
#             self.sup_token.address,
#             st_tby_address
#         )
#         return stakeupStaking
    
#     def __setup_st_tby(self):
#         wrapper_address = get_create_address(self.deployer, self.deployer.nonce + 1)
#         messenger_address = get_create_address(self.deployer, self.deployer.nonce + 2)
#         return StTBY.deploy(
#             self.stablecoin.address,
#             self.stakeup.address,
#             self.factory.address,
#             self.registry.address,
#             wrapper_address,
#             messenger_address,
#             self.endpoint,
#             self.deployer
#         )

# def deploy_st_tby_env(c) -> StTBYTestEnv:
#     env = StTBYTestEnv(
#         c,
#         ContractConfig(True),
#         ContractConfig(True),
#         ContractConfig(True)
#     )
#     return env