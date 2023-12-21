from decimal import Decimal

from wake.testing import Address
from pytypes.src.interfaces.ICurveGaugeDistributor import ICurveGaugeDistributor

class Constants():
    ONE_MINUTE = 60
    ONE_HOUR = ONE_MINUTE * 60
    ONE_DAY = ONE_HOUR * 24
    ONE_WEEK = ONE_DAY * 7
    ONE_YEAR = ONE_WEEK * 52

    FIXED_POINT_ONE = 10 ** 18

    # Example Mainnet Curve Pools
    CURVE_STABLE_POOL_FACTORY = Address("0x6A8cbed756804B16E05E741eDaBd5cB544AE21bf")

    MAINNET_FRAX = Address("0x853d955aCEf822Db058eb8505911ED77F175b99e")
    MAINNET_USDC = Address("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48")

class EvmMath():
    
    def parse_eth(value) -> int:
        d = Decimal(value)
        return int(d * Constants.FIXED_POINT_ONE)
    
    def parse_decimals(value: any, decimals: int) -> int:
        d = Decimal(value)
        return int(d * 10 ** decimals)
