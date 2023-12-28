from decimal import Decimal

class Constants():
    ONE_MINUTE = 60
    ONE_HOUR = ONE_MINUTE * 60
    ONE_DAY = ONE_HOUR * 24
    ONE_WEEK = ONE_DAY * 7
    ONE_YEAR = ONE_WEEK * 52

    FIXED_POINT_ONE = 10 ** 18

class EvmMath():
    
    def parse_eth(value) -> int:
        d = Decimal(str(value))
        return int(d * Constants.FIXED_POINT_ONE)
    
    def parse_decimals(value: any, decimals: int) -> int:
        d = Decimal(str(value))
        return int(d * 10 ** decimals)
