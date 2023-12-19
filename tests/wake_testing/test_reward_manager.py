from tests.wake_testing.helpers.utils import Constants, EvmMath
from wake.testing import *
from wake.testing.fuzzing import *
from pytypes.tests.mocks.MockDripRewarder import MockDripRewarder
from pytypes.tests.mocks.MockERC20 import MockERC20

# class DripRewards(FuzzTest):
#     dripRewarder: MockDripRewarder
#     stUsdMock: MockERC20
#     stakeupMock: MockERC20
#     rewards_dripped = 0

#     def pre_sequence(self) -> None:
#         random_address = random_address()
#         self.stUsdMock = MockERC20.deploy(6)
#         self.stakeupMock = MockERC20.deploy(18)
#         self.dripRewarder = MockDripRewarder.deploy(
#             self.stUsdMock.address,
#             self.stakeupMock.address,
#             random_address
#         )

#     def flow_drip(self, time_between_drips) -> None:
#         self.dripRewarder.calculateDripRewards()
#     pass

# @default_chain.connect()
# def test_drip_fuzz():
#     DripRewards().run(sequences_count=10, flows_count=100)


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
