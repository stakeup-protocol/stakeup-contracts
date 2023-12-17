
class Constants():
    ONE_YEAR = 60 * 60 * 24 * 365
    ONE_WEEK = 60 * 60 * 24 * 7
    ONE_DAY = 60 * 60 * 24
    ONE_HOUR = 60 * 60
    ONE_MINUTE = 60

    FIXED_POINT_ONE = 10 ** 18

class EvmMath():
    
    def parse_eth(value) -> int:
        return int(value * Constants.FIXED_POINT_ONE)
    
    def parse_decimals(value: any, decimals: int) -> int:
        return int(value * 10 ** decimals)